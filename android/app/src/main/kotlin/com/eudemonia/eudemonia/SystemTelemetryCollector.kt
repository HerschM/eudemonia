package com.eudemonia.eudemonia

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Debug
import android.os.PowerManager

/**
 * Reads live thermal and memory figures from the operating system.
 *
 * Every value comes straight from Android; a figure the OS cannot provide on
 * this device or API level is reported as null rather than estimated.
 */
class SystemTelemetryCollector(private val context: Context) {

    companion object {
        const val CHANNEL = "com.eudemonia/system_telemetry"
        const val METHOD_GET_SNAPSHOT = "getSnapshot"

        /** Look-ahead window for the thermal headroom forecast. */
        private const val HEADROOM_FORECAST_SECONDS = 10
    }

    fun snapshot(): Map<String, Any?> {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager

        // PowerManager.THERMAL_STATUS_* (0 = none ... 6 = shutdown), API 29+.
        val thermalStatus: Int? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) powerManager?.currentThermalStatus else null

        // Fraction of the way to severe throttling (1.0 = THERMAL_STATUS_SEVERE), API 30+.
        // NaN when the device has no thermal HAL support or the call is rate limited.
        val thermalHeadroom: Double? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                powerManager?.getThermalHeadroom(HEADROOM_FORECAST_SECONDS)
                    ?.takeUnless { it.isNaN() }
                    ?.toDouble()
            } else {
                null
            }

        // Proportional set size of this process: the RAM actually attributable to the app,
        // including native model weights.
        val processMemory = Debug.MemoryInfo()
        Debug.getMemoryInfo(processMemory)
        val appMemoryBytes = processMemory.totalPss.toLong() * 1024L

        val deviceMemory = ActivityManager.MemoryInfo()
        activityManager?.getMemoryInfo(deviceMemory)

        return mapOf(
            "thermalStatus" to thermalStatus,
            "thermalHeadroom" to thermalHeadroom,
            "appMemoryBytes" to appMemoryBytes.takeIf { it > 0 },
            "deviceAvailableBytes" to deviceMemory.availMem.takeIf { activityManager != null },
            "deviceTotalBytes" to deviceMemory.totalMem.takeIf { activityManager != null },
            "isLowMemory" to (activityManager != null && deviceMemory.lowMemory)
        )
    }
}
