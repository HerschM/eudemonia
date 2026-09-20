package com.eudemonia.eudemonia

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.util.Log

class ButtonInterceptorService : AccessibilityService() {

    private val TAG = "ButtonInterceptor"
    private var isRecording = false
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not used for button interception
    }

    override fun onInterrupt() {
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                // For simplicity in this iteration, a long press is detected when repeatCount reaches a threshold.
                // Normally Android sends repeat events for long presses.
                if (event.repeatCount == 5) { 
                    Log.d(TAG, "Volume UP Long Press detected.")
                    sendTriggerToApp()
                    return true // Consume the event so volume doesn't actually change
                }
            }
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
