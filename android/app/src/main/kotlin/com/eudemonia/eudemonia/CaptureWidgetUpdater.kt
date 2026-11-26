package com.eudemonia.eudemonia

import android.Manifest
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.widget.RemoteViews

/** Re-renders every capture widget instance whenever the capture state changes. */
class CaptureWidgetUpdater(private val context: Context) : CaptureListener {

    companion object {
        // Distinct from the notification's request codes (0-2).
        private const val REQUEST_START_CAPTURE = 101
        private const val REQUEST_STOP_CAPTURE = 102
        private const val REQUEST_OPEN_APP = 103

        fun renderAll(context: Context, state: CaptureState) {
            try {
                val manager = AppWidgetManager.getInstance(context) ?: return
                val ids = manager.getAppWidgetIds(ComponentName(context, CaptureWidgetProvider::class.java))
                if (ids == null || ids.isEmpty()) return
                render(context, manager, ids, state)
            } catch (e: Exception) {
                Log.w("CaptureWidget", "Unable to update capture widgets: ${e.message}")
            }
        }

        fun render(context: Context, manager: AppWidgetManager, ids: IntArray, state: CaptureState) {
            val hasMic = context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
            val render = CaptureWidgetRenderState.from(
                state,
                hasMicPermission = hasMic,
                nowWallMs = System.currentTimeMillis(),
                nowElapsedMs = SystemClock.elapsedRealtime(),
            )
            manager.updateAppWidget(ids, buildViews(context, render))
        }

        private fun buildViews(context: Context, render: CaptureWidgetRenderState): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.capture_widget)
            views.setInt(
                android.R.id.background,
                "setBackgroundResource",
                if (render.isRecording) R.drawable.capture_widget_bg_recording else R.drawable.capture_widget_bg_idle
            )
            views.setImageViewResource(
                R.id.capture_widget_icon,
                when (render.icon) {
                    CaptureWidgetRenderState.Icon.MIC -> R.drawable.ic_widget_mic
                    CaptureWidgetRenderState.Icon.STOP -> R.drawable.ic_widget_stop
                }
            )
            views.setTextViewText(R.id.capture_widget_label, render.label)

            val base = render.chronometerBase
            if (base != null) {
                views.setChronometer(R.id.capture_widget_chronometer, base, null, true)
                views.setViewVisibility(R.id.capture_widget_chronometer, View.VISIBLE)
            } else {
                views.setChronometer(R.id.capture_widget_chronometer, SystemClock.elapsedRealtime(), null, false)
                views.setViewVisibility(R.id.capture_widget_chronometer, View.GONE)
            }

            views.setOnClickPendingIntent(android.R.id.background, clickIntent(context, render.clickTarget))
            return views
        }

        private fun clickIntent(context: Context, target: CaptureWidgetRenderState.ClickTarget): PendingIntent =
            when (target) {
                CaptureWidgetRenderState.ClickTarget.START_CAPTURE -> captureServicePendingIntent(
                    context, ForegroundServiceCoordinator.ACTION_START_CAPTURE, REQUEST_START_CAPTURE
                )
                CaptureWidgetRenderState.ClickTarget.STOP_CAPTURE -> captureServicePendingIntent(
                    context, ForegroundServiceCoordinator.ACTION_STOP_CAPTURE, REQUEST_STOP_CAPTURE
                )
                CaptureWidgetRenderState.ClickTarget.OPEN_APP -> PendingIntent.getActivity(
                    context,
                    REQUEST_OPEN_APP,
                    Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    },
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
            }
    }

    override fun onStateChanged(state: CaptureState) = renderAll(context, state)
}
