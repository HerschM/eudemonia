package com.eudemonia.eudemonia

/**
 * Pure Kotlin tracker for whether the capture foreground service is running, plus the
 * service's intent actions. Decoupled from Android Framework classes for testability.
 */
class ForegroundServiceCoordinator(
    private val onStartForeground: () -> Unit = {},
    private val onStopForeground: () -> Unit = {}
) {
    companion object {
        const val ACTION_START = "com.eudemonia.eudemonia.START_FOREGROUND"
        const val ACTION_STOP = "com.eudemonia.eudemonia.STOP_FOREGROUND"
        const val ACTION_START_CAPTURE = "com.eudemonia.eudemonia.ACTION_START_CAPTURE"
        const val ACTION_STOP_CAPTURE = "com.eudemonia.eudemonia.ACTION_STOP_CAPTURE"
    }

    var isRunning: Boolean = false
        private set

    /** Only [ACTION_START] and [ACTION_STOP] change the running state; other actions are ignored. */
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
}
