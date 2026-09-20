package com.eudemonia.eudemonia

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.util.Log

class ButtonInterceptorService : AccessibilityService() {

    private val TAG = "ButtonInterceptor"
    private var isVolumeUpPressed = false
    private var isVolumeDownPressed = false
    private var isTriggered = false
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not used for button interception
    }

    override fun onInterrupt() {
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        Log.d(TAG, "KeyEvent received: ${event.keyCode}, action: ${event.action}")
        
        when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    isVolumeUpPressed = true
                } else if (event.action == KeyEvent.ACTION_UP) {
                    isVolumeUpPressed = false
                }
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    isVolumeDownPressed = true
                } else if (event.action == KeyEvent.ACTION_UP) {
                    isVolumeDownPressed = false
                }
            }
            else -> return super.onKeyEvent(event)
        }

        // If currently triggered, we must consume ALL volume events (including UP)
        // so the OS doesn't receive orphaned UP events, which causes stuck volume.
        if (isTriggered) {
            if (!isVolumeUpPressed && !isVolumeDownPressed) {
                // Both released, reset trigger
                isTriggered = false
                Log.d(TAG, "Both buttons released. Resetting trigger.")
            }
            return true
        }

        // Check if both are pressed to start the trigger
        if (isVolumeUpPressed && isVolumeDownPressed) {
            Log.d(TAG, "Both volume buttons pressed simultaneously!")
            sendTriggerToApp()
            isTriggered = true
            return true
        }

        return super.onKeyEvent(event)
    }

    private fun sendTriggerToApp() {
        // Send a broadcast that the MainActivity will pick up
        val intent = Intent("com.eudemonia.eudemonia.HARDWARE_TRIGGER")
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }
}
