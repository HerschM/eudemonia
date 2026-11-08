package com.eudemonia.eudemonia

/**
 * Pure Kotlin coordinator for background foreground service state and hardware trigger routing.
 * Decoupled from Android Framework classes for 100% testability.
 */
class ForegroundServiceCoordinator(
    private val onStartForeground: () -> Unit = {},
    private val onStopForeground: () -> Unit = {},
    private val onTriggerDelivered: (isLocked: Boolean) -> Unit = {},
    private val onStartCaptureTriggered: () -> Unit = {},
    private val onStopCaptureTriggered: () -> Unit = {},
    private val onRecordingStateUpdated: (isRecording: Boolean) -> Unit = {}
) {
    companion object {
        const val ACTION_START = "com.eudemonia.eudemonia.START_FOREGROUND"
        const val ACTION_STOP = "com.eudemonia.eudemonia.STOP_FOREGROUND"
        const val ACTION_START_CAPTURE = "com.eudemonia.eudemonia.ACTION_START_CAPTURE"
        const val ACTION_STOP_CAPTURE = "com.eudemonia.eudemonia.ACTION_STOP_CAPTURE"
        const val ACTION_UPDATE_RECORDING_STATE = "com.eudemonia.eudemonia.ACTION_UPDATE_RECORDING_STATE"
    }

    var isRunning: Boolean = false
        private set

    var isRecording: Boolean = false
        private set

    fun handleCommand(action: String?, isRecordingArg: Boolean? = null) {
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
            ACTION_START_CAPTURE -> {
                isRecording = true
                onStartCaptureTriggered()
            }
            ACTION_STOP_CAPTURE -> {
                isRecording = false
                onStopCaptureTriggered()
            }
            ACTION_UPDATE_RECORDING_STATE -> {
                if (isRecordingArg != null) {
                    isRecording = isRecordingArg
                    onRecordingStateUpdated(isRecording)
                }
            }
        }
    }

    fun onHardwareTriggerReceived(isLocked: Boolean) {
        onTriggerDelivered(isLocked)
    }
}
