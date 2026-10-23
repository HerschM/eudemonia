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
    companion object {
        const val CHANNEL = "com.eudemonia/hardware_buttons"
        var activeMethodChannel: MethodChannel? = null
    }

    private var methodChannel: MethodChannel? = null

    private val hardwareTriggerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.eudemonia.eudemonia.HARDWARE_TRIGGER") {
                if (TriggerDebouncer.shared.tryTrigger()) {
                    val isLocked = intent.getBooleanExtra("isLocked", false)
                    methodChannel?.invokeMethod("onHardwareTrigger", mapOf("isLocked" to isLocked))
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        activeMethodChannel = methodChannel
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "openAccessibilitySettings" -> {
                    val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(null)
                }
                "isAccessibilityServiceEnabled" -> {
                    val enabledServices = android.provider.Settings.Secure.getString(
                        contentResolver,
                        android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
                    ) ?: ""
                    val isEnabled = enabledServices.contains(packageName) && enabledServices.contains("ButtonInterceptorService")
                    result.success(isEnabled)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                    val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        powerManager.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    result.success(isIgnoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = android.net.Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "openBatteryOptimizationSettings" -> {
                    val intent = Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(null)
                }
                "startForegroundService" -> {
                    val serviceIntent = Intent(this, EudemoniaForegroundService::class.java).apply {
                        action = ForegroundServiceCoordinator.ACTION_START
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(true)
                }
                "stopForegroundService" -> {
                    val serviceIntent = Intent(this, EudemoniaForegroundService::class.java).apply {
                        action = ForegroundServiceCoordinator.ACTION_STOP
                    }
                    startService(serviceIntent)
                    result.success(true)
                }
                "isForegroundServiceRunning" -> {
                    result.success(EudemoniaForegroundService.isRunning)
                }
                "requestSimultaneousPermissions" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                    val isBatteryIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        powerManager.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    if (!isBatteryIgnored && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = android.net.Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                    } else {
                        val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "playHaptic" -> {
                    val isStart = call.argument<Boolean>("isStart") ?: true
                    val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
                    if (vibrator.hasVibrator()) {
                        if (isStart) {
                            val effect = android.os.VibrationEffect.createWaveform(longArrayOf(0, 50, 100, 50), -1)
                            vibrator.vibrate(effect)
                        } else {
                            val effect = android.os.VibrationEffect.createOneShot(150, android.os.VibrationEffect.DEFAULT_AMPLITUDE)
                            vibrator.vibrate(effect)
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Register the receiver
        val filter = IntentFilter("com.eudemonia.eudemonia.HARDWARE_TRIGGER")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(hardwareTriggerReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(hardwareTriggerReceiver, filter)
        }

        // Check if activity was launched by service trigger
        if (intent?.getBooleanExtra("autoTrigger", false) == true) {
            if (TriggerDebouncer.shared.tryTrigger()) {
                val isLocked = intent.getBooleanExtra("isLocked", false)
                methodChannel?.invokeMethod("onHardwareTrigger", mapOf("isLocked" to isLocked))
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("autoTrigger", false)) {
            if (TriggerDebouncer.shared.tryTrigger()) {
                val isLocked = intent.getBooleanExtra("isLocked", false)
                methodChannel?.invokeMethod("onHardwareTrigger", mapOf("isLocked" to isLocked))
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        activeMethodChannel = null
        try {
            unregisterReceiver(hardwareTriggerReceiver)
        } catch (_: Exception) {}
    }
}
