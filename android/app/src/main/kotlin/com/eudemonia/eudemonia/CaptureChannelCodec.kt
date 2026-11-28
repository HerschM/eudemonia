package com.eudemonia.eudemonia

/** Message shapes of the `com.eudemonia/capture` method channel. */
object CaptureChannelCodec {
    const val METHOD_ON_STATE_CHANGED = "onStateChanged"
    const val METHOD_ON_CAPTURE_SAVED = "onCaptureSaved"

    /** Every state carries the recording length limit, so Dart can show it next to its timer. */
    fun encodeState(state: CaptureState): Map<String, Any?> =
        mapOf(
            "isRecording" to state.isRecording,
            "startedAtMs" to state.startedAtMs,
            "maxDurationMs" to CaptureLimits.MAX_RECORDING_MS,
        )

    fun encodeSaved(capture: SavedCapture): Map<String, Any> =
        mapOf("path" to capture.file.absolutePath, "startedAtMs" to capture.startedAtMs)

    fun encodeCommitted(capture: CommittedCapture): Map<String, Any> =
        mapOf("path" to capture.file.absolutePath, "startedAtMs" to capture.startedAtMs)
}
