package com.eudemonia.eudemonia

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    companion object {
        const val CHANNEL = "com.eudemonia/hardware_buttons"
        const val AUDIO_CHANNEL = "com.eudemonia/audio_playback"
        const val CAPTURE_CHANNEL = "com.eudemonia/capture"
        var activeMethodChannel: MethodChannel? = null
        var activeAudioChannel: MethodChannel? = null

        private const val CAPTURE_PERMISSIONS_REQUEST_CODE = 4201
    }

    private var notificationPermissionRequested = false
    private val telemetryCollector by lazy { SystemTelemetryCollector(applicationContext) }
    private val telemetryExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()
    private val processingWakeLock by lazy { ProcessingWakeLock.create(applicationContext) }

    private var methodChannel: MethodChannel? = null
    private var audioChannel: MethodChannel? = null
    private var mediaPlayer: android.media.MediaPlayer? = null
    private var currentlyPlayingPath: String? = null

    private val captureCore: CaptureControl by lazy { CaptureCore.get(applicationContext) }
    private var captureChannel: MethodChannel? = null
    private var captureListener: CaptureListener? = null
    private var modelFilesChannel: ModelFilesChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        activeMethodChannel = methodChannel
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    result.success(startCaptureServiceOrRequestPermissions())
                }
                "stopForegroundService" -> {
                    val serviceIntent = Intent(this, EudemoniaForegroundService::class.java).apply {
                        action = ForegroundServiceCoordinator.ACTION_STOP
                    }
                    startService(serviceIntent)
                    result.success(true)
                }
                "isForegroundServiceRunning" -> {
                    result.success(EudemoniaForegroundService.isRunning)
                }
                "playAudio", "pauseAudio", "stopAudio" -> {
                    handleAudioCall(call, result)
                }
                else -> result.notImplemented()
            }
        }

        audioChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
        activeAudioChannel = audioChannel
        audioChannel?.setMethodCallHandler { call, result ->
            handleAudioCall(call, result)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SystemTelemetryCollector.CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == SystemTelemetryCollector.METHOD_GET_SNAPSHOT) {
                    // Reading process memory walks /proc; keep it off the UI thread.
                    telemetryExecutor.execute {
                        val snapshot = try {
                            telemetryCollector.snapshot()
                        } catch (e: Exception) {
                            android.util.Log.w("MainActivity", "Telemetry snapshot failed: ${e.message}")
                            null
                        }
                        runOnUiThread { result.success(snapshot) }
                    }
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ProcessingWakeLock.CHANNEL)
            .setMethodCallHandler { call, result -> handleProcessingWakeLockCall(call, result) }

        configureCaptureChannel(flutterEngine)

        modelFilesChannel?.dispose()
        modelFilesChannel = ModelFilesChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    private fun isGranted(permission: String): Boolean =
        checkSelfPermission(permission) == android.content.pm.PackageManager.PERMISSION_GRANTED

    /**
     * Starts the keep-alive service, or asks for the runtime permissions it depends on.
     *
     * A `microphone` foreground service may only enter the foreground once RECORD_AUDIO is
     * granted (Android 14+ throws otherwise, and a service that never reaches the foreground
     * crashes the app). The prompt is shown here, while the activity is visible, because it
     * cannot be shown later from a pocket or lock screen trigger.
     */
    private fun startCaptureServiceOrRequestPermissions(): Boolean {
        val micGranted = isGranted(android.Manifest.permission.RECORD_AUDIO)
        val missing = mutableListOf<String>()
        if (!micGranted) {
            missing.add(android.Manifest.permission.RECORD_AUDIO)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            !isGranted(android.Manifest.permission.POST_NOTIFICATIONS) &&
            (!micGranted || !notificationPermissionRequested)
        ) {
            // Without it the lock screen capture notification is silently hidden.
            notificationPermissionRequested = true
            missing.add(android.Manifest.permission.POST_NOTIFICATIONS)
        }
        if (missing.isNotEmpty()) {
            requestPermissions(missing.toTypedArray(), CAPTURE_PERMISSIONS_REQUEST_CODE)
        }
        return micGranted && startCaptureService()
    }

    private fun startCaptureService(): Boolean {
        val serviceIntent = Intent(this, EudemoniaForegroundService::class.java).apply {
            action = ForegroundServiceCoordinator.ACTION_START
        }
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            true
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Unable to start keep-alive service", e)
            false
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CAPTURE_PERMISSIONS_REQUEST_CODE &&
            isGranted(android.Manifest.permission.RECORD_AUDIO)
        ) {
            startCaptureService()
            // Widgets drawn without the permission open the app; let them record directly now.
            CaptureWidgetUpdater.renderAll(applicationContext, captureCore.state)
        }
    }

    /**
     * `com.eudemonia/capture`: Dart starts and stops captures and lists the inbox; native
     * pushes every state change and saved file, whatever triggered it, while this engine is
     * attached. With no engine nothing is sent and finished files wait in the inbox.
     */
    private fun configureCaptureChannel(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAPTURE_CHANNEL)
        captureChannel = channel
        channel.setMethodCallHandler { call, result -> handleCaptureCall(call, result) }

        captureListener?.let { captureCore.removeListener(it) }
        val listener = object : CaptureListener {
            override fun onStateChanged(state: CaptureState) {
                captureChannel?.invokeMethod(
                    CaptureChannelCodec.METHOD_ON_STATE_CHANGED,
                    CaptureChannelCodec.encodeState(state)
                )
            }

            override fun onCaptureSaved(capture: SavedCapture) {
                captureChannel?.invokeMethod(
                    CaptureChannelCodec.METHOD_ON_CAPTURE_SAVED,
                    CaptureChannelCodec.encodeSaved(capture)
                )
            }
        }
        captureCore.addListener(listener)
        captureListener = listener
    }

    private fun handleCaptureCall(
        call: io.flutter.plugin.common.MethodCall,
        result: io.flutter.plugin.common.MethodChannel.Result
    ) {
        when (call.method) {
            "getState" -> result.success(CaptureChannelCodec.encodeState(captureCore.state))
            "start" -> {
                if (!isGranted(android.Manifest.permission.RECORD_AUDIO)) {
                    startCaptureServiceOrRequestPermissions()
                    result.success(CaptureChannelCodec.encodeState(CaptureState.IDLE))
                    return
                }
                startCaptureService()
                captureCore.start { state -> result.success(CaptureChannelCodec.encodeState(state)) }
            }
            // The saved file is not returned here; it always arrives through onCaptureSaved.
            "stop" -> captureCore.stop { state -> result.success(CaptureChannelCodec.encodeState(state)) }
            "listPendingCaptures" -> captureCore.listCommitted { committed ->
                result.success(committed.map(CaptureChannelCodec::encodeCommitted))
            }
            "requestPinWidget" -> result.success(requestPinCaptureWidget())
            else -> result.notImplemented()
        }
    }

    private fun requestPinCaptureWidget(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            val manager = getSystemService(AppWidgetManager::class.java) ?: return false
            manager.isRequestPinAppWidgetSupported &&
                manager.requestPinAppWidget(ComponentName(this, CaptureWidgetProvider::class.java), null, null)
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "Unable to request widget pin: ${e.message}")
            false
        }
    }

    private fun handleProcessingWakeLockCall(
        call: io.flutter.plugin.common.MethodCall,
        result: io.flutter.plugin.common.MethodChannel.Result
    ) {
        try {
            when (call.method) {
                ProcessingWakeLock.METHOD_HOLD -> {
                    // Dart ints arrive as Integer when they fit in 32 bits, Long otherwise.
                    val timeoutMs = call.argument<Number>("timeoutMs")?.toLong() ?: 0L
                    processingWakeLock.hold(call.argument<String>("owner") ?: "", timeoutMs)
                    result.success(null)
                }
                ProcessingWakeLock.METHOD_RELEASE -> {
                    processingWakeLock.release(call.argument<String>("owner") ?: "")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: IllegalArgumentException) {
            result.error("INVALID_ARGUMENT", e.message, null)
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "Processing wake lock call failed: ${e.message}")
            result.error("WAKE_LOCK_ERROR", e.message, null)
        }
    }

    private fun handleAudioCall(call: io.flutter.plugin.common.MethodCall, result: io.flutter.plugin.common.MethodChannel.Result) {
        when (call.method) {
            "playAudio" -> {
                val path = call.argument<String>("path")
                if (path.isNullOrEmpty()) {
                    result.error("INVALID_PATH", "Audio path is required", null)
                    return
                }
                val file = java.io.File(path)
                if (!file.exists()) {
                    android.util.Log.e("MainActivity", "Audio file not found at: $path")
                    result.error("FILE_NOT_FOUND", "Audio file does not exist at $path", null)
                    return
                }

                try {
                    if (mediaPlayer != null && currentlyPlayingPath == path) {
                        mediaPlayer?.start()
                        result.success(true)
                        return
                    }

                    mediaPlayer?.release()
                    mediaPlayer = null

                    val player = android.media.MediaPlayer()
                    player.setAudioAttributes(
                        android.media.AudioAttributes.Builder()
                            .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                            .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                            .build()
                    )
                    player.setDataSource(file.absolutePath)
                    player.prepare()

                    player.setOnCompletionListener {
                        currentlyPlayingPath = null
                        activeAudioChannel?.invokeMethod("onAudioPlaybackComplete", null)
                        activeMethodChannel?.invokeMethod("onAudioPlaybackComplete", null)
                    }
                    player.setOnErrorListener { _, what, extra ->
                        android.util.Log.e("MainActivity", "MediaPlayer error: what=$what, extra=$extra")
                        currentlyPlayingPath = null
                        activeAudioChannel?.invokeMethod("onAudioPlaybackComplete", null)
                        activeMethodChannel?.invokeMethod("onAudioPlaybackComplete", null)
                        true
                    }

                    player.start()
                    mediaPlayer = player
                    currentlyPlayingPath = path
                    result.success(true)
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Error playing audio file $path", e)
                    currentlyPlayingPath = null
                    result.error("PLAYBACK_ERROR", e.message, null)
                }
            }
            "pauseAudio" -> {
                try {
                    if (mediaPlayer?.isPlaying == true) {
                        mediaPlayer?.pause()
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("PAUSE_ERROR", e.message, null)
                }
            }
            "stopAudio" -> {
                try {
                    mediaPlayer?.stop()
                    mediaPlayer?.release()
                    mediaPlayer = null
                    currentlyPlayingPath = null
                    result.success(true)
                } catch (e: Exception) {
                    result.error("STOP_ERROR", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        activeMethodChannel = null
        activeAudioChannel = null
        telemetryExecutor.shutdown()
        // The engine dies with the activity, so no processing can still need the CPU.
        try {
            processingWakeLock.releaseAll()
        } catch (_: Exception) {}
        try {
            mediaPlayer?.release()
            mediaPlayer = null
            currentlyPlayingPath = null
        } catch (_: Exception) {}
        captureListener?.let { captureCore.removeListener(it) }
        captureListener = null
        captureChannel?.setMethodCallHandler(null)
        captureChannel = null
        modelFilesChannel?.dispose()
        modelFilesChannel = null
    }
}
