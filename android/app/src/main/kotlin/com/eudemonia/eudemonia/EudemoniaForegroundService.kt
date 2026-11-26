package com.eudemonia.eudemonia

import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Microphone foreground service that keeps the process alive and hosts the capture
 * notification. Its start/stop capture actions come from the notification and the
 * home-screen widget and go straight to [CaptureCore]; it never starts an activity.
 */
class EudemoniaForegroundService : Service() {

    companion object {
        /** Default importance: a silent-class notification is hidden on many lock screens. */
        const val CHANNEL_ID = "eudemonia_capture"

        /** The low-importance channel of earlier builds; an existing channel cannot be raised, so it is replaced. */
        const val LEGACY_CHANNEL_ID = "eudemonia_background_channel"
        const val NOTIFICATION_ID = 1001

        @Volatile
        var isRunning: Boolean = false
            internal set
    }

    internal lateinit var coordinator: ForegroundServiceCoordinator
    internal var capture: CaptureControl? = null
    internal var captureProvider: (Context) -> CaptureControl = { CaptureCore.get(it) }

    /** Enters the foreground showing [CaptureState]; false if the system refused. */
    internal var foregroundStarter: (CaptureState) -> Boolean = { state -> enterForeground(state) }

    private val notificationFactory by lazy { CaptureNotificationFactory(this) }

    private val captureListener = object : CaptureListener {
        override fun onStateChanged(state: CaptureState) {
            updateNotification(state)
        }
    }

    override fun onCreate() {
        super.onCreate()
        coordinator = ForegroundServiceCoordinator(
            onStartForeground = { isRunning = true },
            onStopForeground = { isRunning = false }
        )
        capture = captureProvider(applicationContext ?: this).also { it.addListener(captureListener) }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ForegroundServiceCoordinator.ACTION_START

        if (action == ForegroundServiceCoordinator.ACTION_STOP) {
            // A recording must not outlive the foreground service that keeps it legitimate.
            capture?.stop()
            coordinator.handleCommand(action)
            try {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } catch (_: Exception) {}
            try {
                stopSelf()
            } catch (_: Exception) {}
            return START_NOT_STICKY
        }

        // A widget or notification tap may have started this service in a fresh process with
        // startForegroundService(), which must reach the foreground within 5 s or the app
        // crashes. So every path enters the foreground first, and records only if it did.
        val currentState = capture?.state ?: CaptureState.IDLE
        if (!foregroundStarter(currentState)) {
            // Typically a restart by the system while the app is in the background, where a
            // microphone service may not enter the foreground. Leave the Record button as a
            // plain notification: tapping it starts this service again, which is then allowed.
            CaptureNotificationRestorer.postIdleNotification(applicationContext ?: this)
            coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_STOP)
            try {
                stopSelf()
            } catch (_: Exception) {}
            return START_NOT_STICKY
        }
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_START)

        // A tap that changes nothing (for example Stop on a widget left showing a recording by
        // a killed process) emits no state change, so the surfaces are redrawn from the result.
        when (action) {
            ForegroundServiceCoordinator.ACTION_START_CAPTURE -> capture?.start { refreshSurfaces(it) }
            ForegroundServiceCoordinator.ACTION_STOP_CAPTURE -> capture?.stop { refreshSurfaces(it) }
            else -> refreshSurfaces(currentState)
        }
        return START_STICKY
    }

    private fun refreshSurfaces(state: CaptureState) {
        updateNotification(state)
        CaptureWidgetUpdater.renderAll(applicationContext ?: this, state)
    }

    private fun enterForeground(state: CaptureState): Boolean =
        try {
            notificationFactory.createChannel()
            val notification = notificationFactory.build(state)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            true
        } catch (e: Exception) {
            // For example a missing microphone permission on Android 14+.
            android.util.Log.e("EudemoniaFgService", "Unable to enter foreground: ${e.message}")
            false
        }

    private fun updateNotification(state: CaptureState) {
        if (!isRunning) return
        try {
            getSystemService(NotificationManager::class.java)
                ?.notify(NOTIFICATION_ID, notificationFactory.build(state))
        } catch (e: Exception) {
            android.util.Log.w("EudemoniaFgService", "Unable to update capture notification: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        capture?.removeListener(captureListener)
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_STOP)
        isRunning = false
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
