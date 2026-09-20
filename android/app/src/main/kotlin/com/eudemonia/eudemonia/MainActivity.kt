package com.eudemonia.eudemonia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.eudemonia/hardware_buttons"
    private var methodChannel: MethodChannel? = null

    private val hardwareTriggerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.eudemonia.eudemonia.HARDWARE_TRIGGER") {
                // Forward the trigger to Flutter
                methodChannel?.invokeMethod("onHardwareTrigger", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "openAccessibilitySettings") {
                val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                result.success(null)
            } else if (call.method == "playHaptic") {
                val isStart = call.argument<Boolean>("isStart") ?: true
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
                if (vibrator.hasVibrator()) {
                    if (isStart) {
                        // Double pulse: wait 0, play 50, wait 50, play 50
                        val effect = android.os.VibrationEffect.createWaveform(longArrayOf(0, 50, 100, 50), -1)
                        vibrator.vibrate(effect)
                    } else {
                        // Single long pulse
                        val effect = android.os.VibrationEffect.createOneShot(150, android.os.VibrationEffect.DEFAULT_AMPLITUDE)
                        vibrator.vibrate(effect)
                    }
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // Register the receiver
        val filter = IntentFilter("com.eudemonia.eudemonia.HARDWARE_TRIGGER")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(hardwareTriggerReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(hardwareTriggerReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(hardwareTriggerReceiver)
    }
}
