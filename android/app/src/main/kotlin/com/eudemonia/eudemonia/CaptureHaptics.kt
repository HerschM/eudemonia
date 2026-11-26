package com.eudemonia.eudemonia

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/** Haptic confirmation of a capture start or stop, fired natively for every trigger source. */
interface CaptureHaptics {
    fun onCaptureStarted()
    fun onCaptureStopped()
}

/** [CaptureHaptics] on the device vibrator: one short tick to start, a double tick to stop. */
class VibratorCaptureHaptics(private val context: Context) : CaptureHaptics {

    override fun onCaptureStarted() = vibrate(isStart = true)

    override fun onCaptureStopped() = vibrate(isStart = false)

    private fun vibrate(isStart: Boolean) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibratorManager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            if (vibrator?.hasVibrator() == true) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val effect = if (isStart) {
                        VibrationEffect.createOneShot(45, VibrationEffect.DEFAULT_AMPLITUDE)
                    } else {
                        VibrationEffect.createWaveform(longArrayOf(0, 30, 50, 30), -1)
                    }
                    vibrator.vibrate(effect)
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(if (isStart) 45L else 80L)
                }
            }
        } catch (e: Exception) {
            Log.e("CaptureHaptics", "Error playing capture haptic: ${e.message}")
        }
    }
}
