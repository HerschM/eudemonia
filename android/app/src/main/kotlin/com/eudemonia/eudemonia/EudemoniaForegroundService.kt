package com.eudemonia.eudemonia

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class EudemoniaForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "eudemonia_background_channel"
        const val NOTIFICATION_ID = 1001
        const val TRIGGER_ACTION = "com.eudemonia.eudemonia.HARDWARE_TRIGGER"

        var isRunning: Boolean = false
            internal set
    }

    internal lateinit var coordinator: ForegroundServiceCoordinator
    internal var triggerReceiver: BroadcastReceiver? = null

    override fun onCreate() {
        super.onCreate()

        coordinator = ForegroundServiceCoordinator(
            onStartForeground = {
                isRunning = true
            },
            onStopForeground = {
                isRunning = false
            },
            onTriggerDelivered = { isLocked ->
                deliverTrigger(isLocked)
            }
        )
    }

    internal fun setCoordinatorForTesting(testCoordinator: ForegroundServiceCoordinator) {
        coordinator = testCoordinator
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ForegroundServiceCoordinator.ACTION_START

        if (action == ForegroundServiceCoordinator.ACTION_STOP) {
            coordinator.handleCommand(action)
            try {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } catch (_: Exception) {}
            try {
                stopSelf()
            } catch (_: Exception) {}
            return START_NOT_STICKY
        }

        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_START)
        try {
            createNotificationChannel()

            val notificationIntent = Intent(this, MainActivity::class.java).apply {
                this.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                notificationIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Eudemonia Background Listener")
                .setContentText("Ready to capture thoughts via volume buttons.")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()

            startForeground(NOTIFICATION_ID, notification)
        } catch (_: Exception) {}

        try {
            registerTriggerReceiver()
        } catch (_: Exception) {}

        return START_STICKY
    }

    internal fun registerTriggerReceiver() {
        if (triggerReceiver == null) {
            triggerReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == TRIGGER_ACTION) {
                        if (TriggerDebouncer.shared.tryTrigger()) {
                            val isLocked = intent.getBooleanExtra("isLocked", false)
                            coordinator.onHardwareTriggerReceived(isLocked)
                        }
                    }
                }
            }

            try {
                val filter = IntentFilter(TRIGGER_ACTION)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(triggerReceiver, filter, RECEIVER_NOT_EXPORTED)
                } else {
                    registerReceiver(triggerReceiver, filter)
                }
            } catch (_: Exception) {}
        }
    }

    internal fun deliverTrigger(
        isLocked: Boolean,
        channel: io.flutter.plugin.common.MethodChannel? = MainActivity.activeMethodChannel
    ): Boolean {
        if (channel != null) {
            // Forward directly to Flutter
            channel.invokeMethod("onHardwareTrigger", mapOf("isLocked" to isLocked))
            return true
        } else {
            // Wake MainActivity to process the trigger
            try {
                val launchIntent = packageManager?.getLaunchIntentForPackage(packageName)?.apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra("isLocked", isLocked)
                    putExtra("autoTrigger", true)
                }
                if (launchIntent != null) {
                    startActivity(launchIntent)
                    return false
                }
            } catch (_: Exception) {}
            return false
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Eudemonia Background Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps Eudemonia alive in background to detect volume button shortcuts."
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(serviceChannel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        triggerReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {}
            triggerReceiver = null
        }
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_STOP)
        isRunning = false
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
