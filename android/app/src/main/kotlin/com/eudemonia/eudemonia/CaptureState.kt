package com.eudemonia.eudemonia

import java.io.File

/** Whether a capture is being recorded, and since when (wall-clock ms). */
data class CaptureState(val isRecording: Boolean, val startedAtMs: Long?) {
    companion object {
        val IDLE = CaptureState(isRecording = false, startedAtMs = null)
    }
}

/** A recording that has been committed to the capture inbox. */
data class SavedCapture(val file: File, val startedAtMs: Long, val durationMs: Long)

/** Observes the capture session. Callbacks arrive on the main thread. */
interface CaptureListener {
    fun onStateChanged(state: CaptureState)
    fun onCaptureSaved(capture: SavedCapture) {}
}
