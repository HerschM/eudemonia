package com.eudemonia.eudemonia

/** What the Quick Settings tile shows and does for a [CaptureState]; pure so it can be unit-tested. */
data class CaptureTileState(
    val active: Boolean,
    val label: String,
    val subtitle: String,
    /** Service action a tap sends. */
    val action: String,
) {
    companion object {
        fun from(state: CaptureState): CaptureTileState =
            if (state.isRecording) {
                CaptureTileState(
                    active = true,
                    label = "Recording thought",
                    subtitle = "Tap to stop and save",
                    action = ForegroundServiceCoordinator.ACTION_STOP_CAPTURE,
                )
            } else {
                CaptureTileState(
                    active = false,
                    label = "Record thought",
                    subtitle = "Tap to record",
                    action = ForegroundServiceCoordinator.ACTION_START_CAPTURE,
                )
            }
    }
}
