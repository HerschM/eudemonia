package com.eudemonia.eudemonia

import android.Manifest
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log

/**
 * Puts the Record notification back when the foreground service is not running and cannot be
 * started from the background: after the phone restarts, after an app update, or after the
 * system restarted the service while the app was not on screen.
 *
 * The notification is posted as a plain one. Tapping Record starts
 * [EudemoniaForegroundService] (allowed from a notification tap), which takes the same
 * notification over as its foreground notification.
 */
class CaptureNotificationRestorer : BroadcastReceiver() {

    companion object {
        private const val TAG = "CaptureNotifRestorer"

        /** Posts the idle Record notification if the app may record and may notify. */
        fun postIdleNotification(context: Context) {
            try {
                if (!isGranted(context, Manifest.permission.RECORD_AUDIO)) return
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    !isGranted(context, Manifest.permission.POST_NOTIFICATIONS)
                ) {
                    return
                }
                val factory = CaptureNotificationFactory(context)
                factory.createChannel()
                context.getSystemService(NotificationManager::class.java)
                    ?.notify(EudemoniaForegroundService.NOTIFICATION_ID, factory.build(CaptureState.IDLE))
            } catch (e: Exception) {
                Log.w(TAG, "Unable to restore the capture notification: ${e.message}")
            }
        }

        private fun isGranted(context: Context, permission: String): Boolean =
            context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }

    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
                postIdleNotification(context)
                CaptureWidgetUpdater.renderAll(context, CaptureState.IDLE)
            }
        }
    }
}
