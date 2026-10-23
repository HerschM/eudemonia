package com.eudemonia.eudemonia

/**
 * Pure Kotlin coordinator for background foreground service state and hardware trigger routing.
 * Decoupled from Android Framework classes for 100% testability.
 */
class ForegroundServiceCoordinator(
    private val onStartForeground: () -> Unit = {},
    private val onStopForeground: () -> Unit = {},
    private val onTriggerDelivered: (isLocked: Boolean) -> Unit = {}
) {
    companion object {
        const val ACTION_START = "com.eudemonia.eudemonia.START_FOREGROUND"
        const val ACTION_STOP = "com.eudemonia.eudemonia.STOP_FOREGROUND"
    }

    var isRunning: Boolean = false
        private set

    fun handleCommand(action: String?) {
        when (action) {
            ACTION_START -> {
                if (!isRunning) {
                    isRunning = true
                    onStartForeground()
                }
            }
            ACTION_STOP -> {
                if (isRunning) {
                    isRunning = false
                    onStopForeground()
                }
            }
        }
    }

    fun onHardwareTriggerReceived(isLocked: Boolean) {
        onTriggerDelivered(isLocked)
    }
}
