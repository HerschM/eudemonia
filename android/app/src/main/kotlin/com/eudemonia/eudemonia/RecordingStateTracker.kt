package com.eudemonia.eudemonia

/**
 * Tracks whether a thought recording is in progress, as seen from the isolated
 * interceptor process.
 *
 * The start/stop haptic must fire before the app process has reacted, so each
 * trigger optimistically predicts the toggle. The app then reports the real
 * outcome, which corrects the prediction whenever a trigger was dropped
 * (debounce, missing microphone permission) or recording was toggled elsewhere
 * (lock screen notification action).
 */
class RecordingStateTracker {
    companion object {
        const val ACTION_RECORDING_STATE_CHANGED = "com.eudemonia.eudemonia.RECORDING_STATE_CHANGED"
        const val EXTRA_IS_RECORDING = "isRecording"
    }

    @Volatile
    var isRecording: Boolean = false
        private set

    /** Predicts the toggle for a fired trigger. Returns true when the trigger starts a recording. */
    @Synchronized
    fun onTriggerFired(): Boolean {
        isRecording = !isRecording
        return isRecording
    }

    /** Applies the recording state reported by the app process. */
    @Synchronized
    fun onAuthoritativeState(recording: Boolean) {
        isRecording = recording
    }
}
