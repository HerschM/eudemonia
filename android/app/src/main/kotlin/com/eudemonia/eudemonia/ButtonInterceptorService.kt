package com.eudemonia.eudemonia

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.util.Log

class ButtonInterceptorService : AccessibilityService() {

    private val TAG = "ButtonInterceptor"
    private var isVolumeUpPressed = false
    private var isVolumeDownPressed = false
    private var isTriggered = false
    private val handler = Handler(Looper.getMainLooper())
    private var volumeRunnable: Runnable? = null
    private lateinit var audioManager: AudioManager

    override fun onServiceConnected() {
        super.onServiceConnected()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode != KeyEvent.KEYCODE_VOLUME_UP && event.keyCode != KeyEvent.KEYCODE_VOLUME_DOWN) {
            return super.onKeyEvent(event)
        }

        // Always consume volume keys to prevent the OS from sticking them
        if (event.action == KeyEvent.ACTION_UP) {
            if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) isVolumeUpPressed = false
            if (event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) isVolumeDownPressed = false
            
            if (!isVolumeUpPressed && !isVolumeDownPressed) {
                isTriggered = false
            }
            return true
        }

        if (event.action == KeyEvent.ACTION_DOWN) {
            val wasAlreadyPressed = if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) isVolumeUpPressed else isVolumeDownPressed
            
            if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) isVolumeUpPressed = true
            if (event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) isVolumeDownPressed = true

            if (isTriggered) return true // Already triggered, just consume

            // If both are pressed simultaneously
            if (isVolumeUpPressed && isVolumeDownPressed) {
                // Cancel pending volume changes
                volumeRunnable?.let { handler.removeCallbacks(it) }
                
                Log.d(TAG, "Both volume buttons pressed simultaneously!")
                sendTriggerToApp()
                isTriggered = true
                return true
            }

            // If only one is pressed
            if (!wasAlreadyPressed) {
                // Wait 60ms for the second button
                volumeRunnable = Runnable {
                    if (!isTriggered) {
                        val direction = if (isVolumeUpPressed) AudioManager.ADJUST_RAISE else AudioManager.ADJUST_LOWER
                        audioManager.adjustSuggestedStreamVolume(direction, AudioManager.USE_DEFAULT_STREAM_TYPE, AudioManager.FLAG_SHOW_UI)
                    }
                }
                handler.postDelayed(volumeRunnable!!, 60)
            } else if (!isTriggered) {
                // Key repeat (held down for volume change)
                val direction = if (isVolumeUpPressed) AudioManager.ADJUST_RAISE else AudioManager.ADJUST_LOWER
                audioManager.adjustSuggestedStreamVolume(direction, AudioManager.USE_DEFAULT_STREAM_TYPE, AudioManager.FLAG_SHOW_UI)
            }
        }
        
        return true
    }

    private fun sendTriggerToApp() {
        val intent = Intent("com.eudemonia.eudemonia.HARDWARE_TRIGGER")
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }
}
