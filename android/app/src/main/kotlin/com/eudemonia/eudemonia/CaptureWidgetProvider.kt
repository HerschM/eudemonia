package com.eudemonia.eudemonia

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle

/**
 * Home-screen "Capture thought" card. A tap starts or stops a capture through
 * [EudemoniaForegroundService]; later state changes re-render it via [CaptureWidgetUpdater].
 */
class CaptureWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        // Creating the core also registers the updater, so later state changes reach the widget.
        CaptureWidgetUpdater.render(context, appWidgetManager, appWidgetIds, CaptureCore.get(context).state)
    }

    /** Below Android 12 the layout is chosen from the instance's size, so re-render when it is resized. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        CaptureWidgetUpdater.render(context, appWidgetManager, intArrayOf(appWidgetId), CaptureCore.get(context).state)
    }
}
