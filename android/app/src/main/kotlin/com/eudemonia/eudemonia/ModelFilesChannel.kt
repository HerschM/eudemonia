package com.eudemonia.eudemonia

import android.app.ActivityManager
import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * `com.eudemonia/model_files`: Dart owns the model catalogue and the choice; native owns the
 * transfer (DownloadManager), verification and files. Calls run on one background thread and
 * answer on the main thread; Dart polls `status` for progress and is told `onChanged` when a
 * transfer completes or a verification finishes. One instance per attached engine.
 */
class ModelFilesChannel(context: Context, messenger: BinaryMessenger) {

    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, ModelFilesChannelCodec.CHANNEL)
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var disposed = false

    private val listener: () -> Unit = {
        mainHandler.post {
            if (!disposed) channel.invokeMethod(ModelFilesChannelCodec.METHOD_ON_CHANGED, null)
        }
    }

    // Only a nudge to re-check: the intent's content is never trusted, so it may be exported.
    private val completionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (disposed) return
            executor.execute {
                try {
                    SharedModelDownloads.coordinator(appContext).reconcile()
                } catch (e: Exception) {
                    android.util.Log.w(TAG, "Reconcile after download failed: ${e.message}")
                }
                listener()
            }
        }
    }

    init {
        SharedModelDownloads.listener = listener
        channel.setMethodCallHandler { call, result -> handle(call, result) }
        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        // The broadcast comes from the DownloadManager provider, another app, hence EXPORTED.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext.registerReceiver(completionReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            appContext.registerReceiver(completionReceiver, filter)
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val work: () -> Any? = when (call.method) {
            ModelFilesChannelCodec.METHOD_GET_DEVICE_INFO -> ::deviceInfo
            ModelFilesChannelCodec.METHOD_STATUS -> {
                { coordinator().status(ModelFilesChannelCodec.decodeQueries(call.arguments)).map { it.toMap() } }
            }
            ModelFilesChannelCodec.METHOD_DOWNLOAD -> {
                { coordinator().download(ModelFilesChannelCodec.decodeDownload(call.arguments)) }
            }
            ModelFilesChannelCodec.METHOD_CANCEL -> {
                { coordinator().cancel(ModelFilesChannelCodec.decodeRelativePath(call.arguments)); null }
            }
            ModelFilesChannelCodec.METHOD_DELETE -> {
                { coordinator().delete(ModelFilesChannelCodec.decodeRelativePath(call.arguments)); null }
            }
            else -> {
                result.notImplemented()
                return
            }
        }
        executor.execute {
            try {
                val value = work()
                mainHandler.post { result.success(value) }
            } catch (e: IllegalArgumentException) {
                mainHandler.post { result.error("INVALID_ARGUMENT", e.message, null) }
            } catch (e: Exception) {
                android.util.Log.w(TAG, "${call.method} failed: ${e.message}")
                mainHandler.post { result.error("MODEL_FILES_ERROR", e.message, null) }
            }
        }
    }

    private fun coordinator() = SharedModelDownloads.coordinator(appContext)

    private fun deviceInfo(): Map<String, Any> {
        val activityManager = appContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memory = ActivityManager.MemoryInfo().also(activityManager::getMemoryInfo)
        val dir = SharedModelDownloads.rootDir(appContext)
        return ModelFilesChannelCodec.encodeDeviceInfo(memory.totalMem, StatFs(dir.path).availableBytes)
    }

    fun dispose() {
        disposed = true
        if (SharedModelDownloads.listener === listener) SharedModelDownloads.listener = null
        try {
            appContext.unregisterReceiver(completionReceiver)
        } catch (_: IllegalArgumentException) {}
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    private companion object {
        const val TAG = "ModelFilesChannel"
    }
}

/**
 * One coordinator per process, so an activity recreated mid-verification never starts a second
 * hash of the same file. Verification has its own thread so `status` keeps answering meanwhile.
 */
private object SharedModelDownloads {
    @Volatile var listener: (() -> Unit)? = null

    private var instance: ModelDownloadCoordinator? = null

    private val verifyExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "ModelFileVerifier").apply { isDaemon = true }
    }

    fun rootDir(context: Context) =
        context.getExternalFilesDir(null) ?: throw IllegalStateException("External files dir unavailable")

    @Synchronized
    fun coordinator(context: Context): ModelDownloadCoordinator {
        instance?.let { return it }
        val root = rootDir(context)
        val verifier = Sha256Verifier()
        return ModelDownloadCoordinator(
            rootDir = root,
            store = SharedPreferencesModelDownloadRecordStore(context),
            transport = SystemModelDownloadTransport(context),
            freeSpaceBytes = { StatFs(root.path).availableBytes },
            hasher = verifier::hexDigest,
            runVerification = { task -> verifyExecutor.execute(task) },
            onChanged = { listener?.invoke() }
        ).also { instance = it }
    }
}
