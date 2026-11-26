package com.eudemonia.eudemonia

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

/**
 * Home-screen "Capture thought" pill. A tap starts or stops a capture through
 * [EudemoniaForegroundService]; later state changes re-render it via [CaptureWidgetUpdater].
 */
class CaptureWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        // Creating the core also registers the updater, so later state changes reach the widget.
        CaptureWidgetUpdater.render(context, appWidgetManager, appWidgetIds, CaptureCore.get(context).state)
    }
}
