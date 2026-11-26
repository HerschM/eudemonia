package com.eudemonia.eudemonia

import java.io.File
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.Executor

/**
 * The capture state machine: idle <-> recording.
 *
 * [start] and [stop] are serialised and block for as long as the recorder needs, so callers
 * run them off the main thread (see [CaptureCore]). Haptics fire on the calling thread the
 * moment a start or stop is confirmed; listener callbacks are delivered through [mainPoster].
 */
class CaptureSession(
    private val audio: AudioCapture,
    private val haptics: CaptureHaptics,
    private val inbox: CaptureInbox,
    private val clock: () -> Long,
    private val mainPoster: Executor,
) {
    private val lock = Any()
    private val listeners = CopyOnWriteArrayList<CaptureListener>()
    private var part: File? = null

    @Volatile
    var state: CaptureState = CaptureState.IDLE
        private set

    fun addListener(listener: CaptureListener) {
        listeners.addIfAbsent(listener)
    }

    fun removeListener(listener: CaptureListener) {
        listeners.remove(listener)
    }

    /** Starts recording; a no-op (no haptic) when already recording or when the recorder fails. */
    fun start(): CaptureState = synchronized(lock) {
        if (state.isRecording) return state
        val startedAtMs = clock()
        val target = inbox.newPartFile(startedAtMs)
        if (!audio.start(target)) {
            inbox.discard(target)
            return state
        }
        part = target
        val recording = CaptureState(isRecording = true, startedAtMs = startedAtMs)
        state = recording
        haptics.onCaptureStarted()
        publish { it.onStateChanged(recording) }
        recording
    }

    /**
     * Stops recording and commits the file. Returns null when idle, or when the commit failed
     * (the part file then stays for the next salvage).
     */
    fun stop(): SavedCapture? = synchronized(lock) {
        val current = state
        val target = part
        val startedAtMs = current.startedAtMs
        if (!current.isRecording || target == null || startedAtMs == null) return null
        val durationMs = audio.stop()
        val committed = inbox.commit(target)
        part = null
        state = CaptureState.IDLE
        haptics.onCaptureStopped()
        val saved = committed?.let { SavedCapture(it, startedAtMs, durationMs) }
        if (saved != null) publish { it.onCaptureSaved(saved) }
        publish { it.onStateChanged(CaptureState.IDLE) }
        saved
    }

    private fun publish(event: (CaptureListener) -> Unit) {
        mainPoster.execute {
            for (listener in listeners) {
                try {
                    event(listener)
                } catch (e: Exception) {
                    // One failing listener must not starve the others.
                    System.err.println("CaptureSession listener failed: ${e.message}")
                }
            }
        }
    }
}
