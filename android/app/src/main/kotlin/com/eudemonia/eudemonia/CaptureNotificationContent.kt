package com.eudemonia.eudemonia

/** What the capture notification shows for a given [CaptureState]; pure so it can be unit-tested. */
data class CaptureNotificationContent(
    val title: String,
    val text: String?,
    val actionLabel: String,
    /** Label of the one-tap button in the notification body. */
    val buttonLabel: String,
    /** Service action the notification button sends. */
    val action: String,
    val usesChronometer: Boolean,
    /** Wall-clock start of the chronometer, or null to hide the timestamp. */
    val whenMs: Long?,
) {
    companion object {
        fun from(state: CaptureState): CaptureNotificationContent =
            if (state.isRecording) {
                CaptureNotificationContent(
                    title = "Recording thought",
                    text = null,
                    actionLabel = "Stop & Save",
                    buttonLabel = "Stop & Save",
                    action = ForegroundServiceCoordinator.ACTION_STOP_CAPTURE,
                    usesChronometer = true,
                    whenMs = state.startedAtMs,
                )
            } else {
                CaptureNotificationContent(
                    title = "Eudemonia",
                    text = "Tap Record to capture a thought",
                    actionLabel = "Record Thought",
                    buttonLabel = "Record",
                    action = ForegroundServiceCoordinator.ACTION_START_CAPTURE,
                    usesChronometer = false,
                    whenMs = null,
                )
            }
    }
}
