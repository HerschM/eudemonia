package com.eudemonia.eudemonia

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.util.Log

class ButtonInterceptorService : AccessibilityService(), VolumeActionHandler {

    private val TAG = "ButtonInterceptor"

    private lateinit var audioManager: AudioManager
    private lateinit var coordinator: VolumeButtonCoordinator
    private val handler = Handler(Looper.getMainLooper())
    private val runnableMap = mutableMapOf<Any, Runnable>()

    private val scheduler = object : Scheduler {
        override fun postDelayed(token: Any, delayMs: Long, action: () -> Unit) {
            cancel(token)
            val runnable = Runnable {
                runnableMap.remove(token)
                action()
            }
            runnableMap[token] = runnable
            handler.postDelayed(runnable, delayMs)
        }

        override fun cancel(token: Any) {
            runnableMap.remove(token)?.let {
                handler.removeCallbacks(it)
            }
        }

        override fun cancelAll() {
            for ((_, runnable) in runnableMap) {
                handler.removeCallbacks(runnable)
            }
            runnableMap.clear()
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        coordinator = VolumeButtonCoordinator(
            actionHandler = this,
            scheduler = scheduler,
            dualPressWindowMs = 50L,
            initialRepeatDelayMs = 300L,
            repeatIntervalMs = 110L,
            maxRepeatSteps = 25
        )
        registerRecordingStateReceiver()
        Log.i(TAG, "ButtonInterceptorService connected successfully in dedicated process.")
    }

    private fun registerRecordingStateReceiver() {
        if (recordingStateReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == RecordingStateTracker.ACTION_RECORDING_STATE_CHANGED) {
                    recordingState.onAuthoritativeState(
                        intent.getBooleanExtra(RecordingStateTracker.EXTRA_IS_RECORDING, false)
                    )
                }
            }
        }
        try {
            val filter = IntentFilter(RecordingStateTracker.ACTION_RECORDING_STATE_CHANGED)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(receiver, filter)
            }
            recordingStateReceiver = receiver
        } catch (e: Exception) {
            Log.e(TAG, "Error registering recording state receiver: ${e.message}")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {
        Log.w(TAG, "ButtonInterceptorService interrupted, resetting coordinator.")
        if (::coordinator.isInitialized) {
            coordinator.reset()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.i(TAG, "ButtonInterceptorService destroying.")
        recordingStateReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {}
            recordingStateReceiver = null
        }
        if (::coordinator.isInitialized) {
            coordinator.reset()
        }
        scheduler.cancelAll()
        handler.removeCallbacksAndMessages(null)
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        val keyCode = event.keyCode

        if (keyCode != KeyEvent.KEYCODE_VOLUME_UP && keyCode != KeyEvent.KEYCODE_VOLUME_DOWN) {
            return super.onKeyEvent(event)
        }

        if (!::coordinator.isInitialized) {
            return true
        }

        val coordKey = if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            VolumeButtonCoordinator.KEY_VOLUME_UP
        } else {
            VolumeButtonCoordinator.KEY_VOLUME_DOWN
        }

        return when (event.action) {
            KeyEvent.ACTION_DOWN -> coordinator.onKeyDown(coordKey, event.repeatCount)
            KeyEvent.ACTION_UP -> coordinator.onKeyUp(coordKey)
            else -> true
        }
    }

    override fun adjustVolume(direction: Int) {
        val audioDir = if (direction == VolumeButtonCoordinator.DIRECTION_UP) {
            AudioManager.ADJUST_RAISE
        } else {
            AudioManager.ADJUST_LOWER
        }
        try {
            audioManager.adjustSuggestedStreamVolume(
                audioDir,
                AudioManager.USE_DEFAULT_STREAM_TYPE,
                AudioManager.FLAG_SHOW_UI
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error adjusting volume: ${e.message}")
        }
    }

    private val recordingState = RecordingStateTracker()
    private var recordingStateReceiver: BroadcastReceiver? = null

    override fun triggerVoicePipeline() {
        val isStart = recordingState.onTriggerFired()
        Log.d(TAG, "Both volume buttons pressed simultaneously! Performing instant haptic (isStart=$isStart) & sending trigger broadcast.")
        playInstantHaptic(isStart = isStart)
        sendTriggerToApp()
    }

    private fun playInstantHaptic(isStart: Boolean) {
        try {
            val vibrator = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? android.os.VibratorManager
                vibratorManager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? android.os.Vibrator
            }

            if (vibrator?.hasVibrator() == true) {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    val effect = if (isStart) {
                        android.os.VibrationEffect.createOneShot(45, android.os.VibrationEffect.DEFAULT_AMPLITUDE)
                    } else {
                        android.os.VibrationEffect.createWaveform(longArrayOf(0, 30, 50, 30), -1)
                    }
                    vibrator.vibrate(effect)
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(if (isStart) 45L else 80L)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error playing instant haptic: ${e.message}")
        }
    }

    private fun sendTriggerToApp() {
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? android.app.KeyguardManager
        val isLocked = keyguardManager?.isKeyguardLocked ?: false

        val intent = Intent("com.eudemonia.eudemonia.HARDWARE_TRIGGER").apply {
            putExtra("isLocked", isLocked)
            setPackage(packageName)
        }
        sendBroadcast(intent)
    }
}
