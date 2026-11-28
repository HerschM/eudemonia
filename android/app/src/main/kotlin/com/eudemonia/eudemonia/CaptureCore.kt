package com.eudemonia.eudemonia

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.io.File
import java.util.concurrent.Executor
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** What the service, the widget and the Flutter bridge need from the capture core. */
interface CaptureControl {
    val state: CaptureState

    /** Starts a capture off the main thread; [onResult] gets the resulting state on the main thread. */
    fun start(onResult: (CaptureState) -> Unit = {})

    /** Stops a capture off the main thread; [onResult] gets the resulting state on the main thread. */
    fun stop(onResult: (CaptureState) -> Unit = {})

    /** Lists the committed captures off the main thread; [onResult] runs on the main thread. */
    fun listCommitted(onResult: (List<CommittedCapture>) -> Unit)

    fun addListener(listener: CaptureListener)
    fun removeListener(listener: CaptureListener)
}

/**
 * Process-wide owner of the native capture session: the single source of truth for whether
 * a thought is being recorded. Every trigger (notification, widget, in-app button) goes
 * through it, and every surface (notification, widget, Flutter) listens to it.
 *
 * All session work runs on one worker thread, in submission order. Stale part files from a
 * killed process are salvaged first, before any new capture can start. The recording length
 * limit is timed on the same worker, so it needs no Flutter engine and queues behind a stop.
 */
class CaptureCore private constructor(
    private val session: CaptureSession,
    private val inbox: CaptureInbox,
    private val worker: ExecutorService,
    private val mainPoster: Executor,
) : CaptureControl {

    companion object {
        private const val TAG = "CaptureCore"

        @Volatile
        private var instance: CaptureCore? = null

        fun get(context: Context): CaptureCore =
            instance ?: synchronized(this) {
                instance ?: create(context.applicationContext ?: context).also { instance = it }
            }

        /** The inbox lives in the Flutter documents directory (`getApplicationDocumentsDirectory`). */
        fun inboxDirectory(context: Context): File =
            File(context.getDir("flutter", Context.MODE_PRIVATE), "capture_inbox")

        private fun create(appContext: Context): CaptureCore {
            val mainHandler = Handler(Looper.getMainLooper())
            val mainPoster = Executor { mainHandler.post(it) }
            val inbox = CaptureInbox(inboxDirectory(appContext))
            val worker = Executors.newSingleThreadScheduledExecutor { runnable ->
                Thread(runnable, "EudemoniaCaptureCore")
            }
            val limitTimer = CaptureLimitTimer { delayMs, task ->
                val pending = worker.schedule({
                    try {
                        task()
                    } catch (e: Exception) {
                        Log.e(TAG, "Capture stop at the length limit failed: ${e.message}")
                    }
                }, delayMs, TimeUnit.MILLISECONDS)
                CaptureLimitTimer.Handle { pending.cancel(false) }
            }
            val session = CaptureSession(
                audio = CaptureRecorder(),
                haptics = VibratorCaptureHaptics(appContext),
                inbox = inbox,
                clock = System::currentTimeMillis,
                mainPoster = mainPoster,
                limitTimer = limitTimer,
                audioFocus = SystemCaptureAudioFocus(appContext),
            )
            val core = CaptureCore(session, inbox, worker, mainPoster)
            core.addListener(CaptureWidgetUpdater(appContext))
            worker.execute {
                try {
                    val salvaged = inbox.salvageStaleParts()
                    if (salvaged.isNotEmpty()) Log.i(TAG, "Salvaged ${salvaged.size} interrupted capture(s)")
                } catch (e: Exception) {
                    Log.e(TAG, "Unable to salvage interrupted captures: ${e.message}")
                }
            }
            return core
        }
    }

    override val state: CaptureState
        get() = session.state

    override fun start(onResult: (CaptureState) -> Unit) {
        worker.execute {
            val result = try {
                session.start()
            } catch (e: Exception) {
                Log.e(TAG, "Capture start failed: ${e.message}")
                session.state
            }
            mainPoster.execute { onResult(result) }
        }
    }

    override fun stop(onResult: (CaptureState) -> Unit) {
        worker.execute {
            try {
                session.stop()
            } catch (e: Exception) {
                Log.e(TAG, "Capture stop failed: ${e.message}")
            }
            val result = session.state
            mainPoster.execute { onResult(result) }
        }
    }

    override fun listCommitted(onResult: (List<CommittedCapture>) -> Unit) {
        worker.execute {
            val committed = try {
                inbox.listCommitted()
            } catch (e: Exception) {
                Log.e(TAG, "Unable to list captures: ${e.message}")
                emptyList()
            }
            mainPoster.execute { onResult(committed) }
        }
    }

    override fun addListener(listener: CaptureListener) = session.addListener(listener)

    override fun removeListener(listener: CaptureListener) = session.removeListener(listener)
}
