package com.eudemonia.eudemonia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    companion object {
        const val CHANNEL = "com.eudemonia/hardware_buttons"
        const val AUDIO_CHANNEL = "com.eudemonia/audio_playback"
        var activeMethodChannel: MethodChannel? = null
        var activeAudioChannel: MethodChannel? = null
    }

    private var methodChannel: MethodChannel? = null
    private var audioChannel: MethodChannel? = null
    private var mediaPlayer: android.media.MediaPlayer? = null
    private var currentlyPlayingPath: String? = null

    private val hardwareTriggerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.eudemonia.eudemonia.HARDWARE_TRIGGER") {
                if (TriggerDebouncer.shared.tryTrigger()) {
                    val isLocked = intent.getBooleanExtra("isLocked", false)
                    methodChannel?.invokeMethod("onHardwareTrigger", mapOf("isLocked" to isLocked))
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        activeMethodChannel = methodChannel
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "openAccessibilitySettings" -> {
                    val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(null)
                }
                "isAccessibilityServiceEnabled" -> {
                    val enabledServices = android.provider.Settings.Secure.getString(
                        contentResolver,
                        android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
                    ) ?: ""
                    val isEnabled = enabledServices.contains(packageName) && enabledServices.contains("ButtonInterceptorService")
                    result.success(isEnabled)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                    val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        powerManager.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    result.success(isIgnoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = android.net.Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "openBatteryOptimizationSettings" -> {
                    val intent = Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(null)
                }
                "startForegroundService" -> {
                    val serviceIntent = Intent(this, EudemoniaForegroundService::class.java).apply {
                        action = ForegroundServiceCoordinator.ACTION_START
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(true)
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
                "requestSimultaneousPermissions" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                    val isBatteryIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        powerManager.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    if (!isBatteryIgnored && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = android.net.Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                    } else {
                        val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "playHaptic" -> {
                    val isStart = call.argument<Boolean>("isStart") ?: true
                    val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
                    if (vibrator.hasVibrator()) {
                        if (isStart) {
                            val effect = android.os.VibrationEffect.createWaveform(longArrayOf(0, 50, 100, 50), -1)
                            vibrator.vibrate(effect)
                        } else {
                            val effect = android.os.VibrationEffect.createOneShot(150, android.os.VibrationEffect.DEFAULT_AMPLITUDE)
                            vibrator.vibrate(effect)
                        }
                    }
                    result.success(null)
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

        // Register the receiver
        val filter = IntentFilter("com.eudemonia.eudemonia.HARDWARE_TRIGGER")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(hardwareTriggerReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(hardwareTriggerReceiver, filter)
        }

        // Check if activity was launched by service trigger
        if (intent?.getBooleanExtra("autoTrigger", false) == true) {
            if (TriggerDebouncer.shared.tryTrigger()) {
                val isLocked = intent.getBooleanExtra("isLocked", false)
                methodChannel?.invokeMethod("onHardwareTrigger", mapOf("isLocked" to isLocked))
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("autoTrigger", false)) {
            if (TriggerDebouncer.shared.tryTrigger()) {
                val isLocked = intent.getBooleanExtra("isLocked", false)
                methodChannel?.invokeMethod("onHardwareTrigger", mapOf("isLocked" to isLocked))
            }
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
                    java.io.FileInputStream(file).use { fis ->
                        player.setAudioAttributes(
                            android.media.AudioAttributes.Builder()
                                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                                .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                                .build()
                        )
                        player.setDataSource(fis.fd)
                        player.prepare()
                    }

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
        try {
            mediaPlayer?.release()
            mediaPlayer = null
            currentlyPlayingPath = null
        } catch (_: Exception) {}
        try {
            unregisterReceiver(hardwareTriggerReceiver)
        } catch (_: Exception) {}
    }
}
