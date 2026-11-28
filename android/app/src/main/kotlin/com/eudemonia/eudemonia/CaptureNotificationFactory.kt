package com.eudemonia.eudemonia

import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Builds the persistent capture notification. It is public on the lock screen so a thought
 * can be recorded without unlocking. The Record / Stop & Save button is part of the body, so
 * it works with one tap without expanding the notification; tapping elsewhere opens the app.
 */
class CaptureNotificationFactory(private val context: Context) {

    companion object {
        const val CHANNEL_NAME = "Capture"
        const val CHANNEL_DESCRIPTION =
            "Record button for capturing a thought from the lock screen or notification shade."

        private const val REQUEST_OPEN_APP = 0
        private const val REQUEST_START_CAPTURE = 1
        private const val REQUEST_STOP_CAPTURE = 2
    }

    fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(NotificationManager::class.java) ?: return
            // Default importance keeps the Record button on the lock screen when the user (or the
            // phone's default) hides silent notifications there. It never makes a sound or buzzes.
            val channel = NotificationChannel(
                EudemoniaForegroundService.CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = CHANNEL_DESCRIPTION
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
            manager.deleteNotificationChannel(EudemoniaForegroundService.LEGACY_CHANNEL_ID)
        }
    }

    /** One status line and one button: record or stop with a single tap, without expanding. */
    private fun bodyView(content: CaptureNotificationContent, action: PendingIntent): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.capture_notification)
        val startedAtMs = content.whenMs
        if (content.usesChronometer && startedAtMs != null) {
            val elapsed = (System.currentTimeMillis() - startedAtMs).coerceAtLeast(0)
            views.setChronometer(
                R.id.capture_notification_chronometer,
                SystemClock.elapsedRealtime() - elapsed,
                content.chronometerFormat,
                true
            )
            views.setViewVisibility(R.id.capture_notification_chronometer, View.VISIBLE)
            views.setViewVisibility(R.id.capture_notification_status, View.GONE)
        } else {
            views.setViewVisibility(R.id.capture_notification_chronometer, View.GONE)
            views.setViewVisibility(R.id.capture_notification_status, View.VISIBLE)
            views.setTextViewText(R.id.capture_notification_status, content.text ?: content.title)
        }
        views.setTextViewText(R.id.capture_notification_button, content.buttonLabel)
        views.setOnClickPendingIntent(R.id.capture_notification_button, action)
        return views
    }

    fun build(state: CaptureState): Notification {
        val content = CaptureNotificationContent.from(state)

        val openApp = PendingIntent.getActivity(
            context,
            REQUEST_OPEN_APP,
            Intent(context, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val actionIntent = captureServicePendingIntent(
            context,
            content.action,
            if (state.isRecording) REQUEST_STOP_CAPTURE else REQUEST_START_CAPTURE
        )

        val builder = NotificationCompat.Builder(context, EudemoniaForegroundService.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_capture)
            .setContentTitle(content.title)
            .setContentIntent(openApp)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(bodyView(content, actionIntent))
            .setCustomBigContentView(bodyView(content, actionIntent))

        content.text?.let { builder.setContentText(it) }
        val whenMs = content.whenMs
        // The running timer is in the body ("Recording 0:06 / 5:00"); the header stays free of a second one.
        if (whenMs != null) builder.setWhen(whenMs)
        builder.setUsesChronometer(false).setShowWhen(false)
        return builder.build()
    }
}

/**
 * A PendingIntent that starts [EudemoniaForegroundService] with [action]. Started as a
 * foreground service because the tap may come while the app process is not running.
 */
internal fun captureServicePendingIntent(context: Context, action: String, requestCode: Int): PendingIntent {
    val intent = Intent(context, EudemoniaForegroundService::class.java).apply { this.action = action }
    val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        PendingIntent.getForegroundService(context, requestCode, intent, flags)
    } else {
        PendingIntent.getService(context, requestCode, intent, flags)
    }
}
