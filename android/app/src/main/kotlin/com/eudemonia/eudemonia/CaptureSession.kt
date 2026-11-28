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
 *
 * Every recording arms [limitTimer] for [CaptureLimits.MAX_RECORDING_MS]; when it fires, the
 * recording is stopped and saved through the same path as a user stop. A stop cancels it.
 */
class CaptureSession(
    private val audio: AudioCapture,
    private val haptics: CaptureHaptics,
    private val inbox: CaptureInbox,
    private val clock: () -> Long,
    private val mainPoster: Executor,
    private val limitTimer: CaptureLimitTimer,
    private val audioFocus: CaptureAudioFocus = CaptureAudioFocus.NONE,
) {
    private val lock = Any()
    private val listeners = CopyOnWriteArrayList<CaptureListener>()
    private var part: File? = null
    private var limitHandle: CaptureLimitTimer.Handle? = null

    /** Counts recordings, so a limit that fires late never stops a later recording. */
    private var recordingNumber = 0L

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
        // Other apps' playback is asked to pause first, so it is not recorded with the voice.
        audioFocus.acquire()
        if (!audio.start(target)) {
            audioFocus.release()
            inbox.discard(target)
            return state
        }
        part = target
        val recording = CaptureState(isRecording = true, startedAtMs = startedAtMs)
        state = recording
        val thisRecording = ++recordingNumber
        limitHandle = limitTimer.schedule(CaptureLimits.MAX_RECORDING_MS) { stopAtLimit(thisRecording) }
        haptics.onCaptureStarted()
        publish { it.onStateChanged(recording) }
        recording
    }

    /**
     * Stops recording and commits the file. Returns null when idle, or when the commit failed
     * (the part file then stays for the next salvage).
     */
    fun stop(): SavedCapture? = synchronized(lock) { stopRecording() }

    /** The automatic stop at the length limit; a no-op once [recording] has already ended. */
    private fun stopAtLimit(recording: Long): SavedCapture? = synchronized(lock) {
        if (recording != recordingNumber) return null
        stopRecording()
    }

    /** Callers hold [lock]. */
    private fun stopRecording(): SavedCapture? {
        val current = state
        val target = part
        val startedAtMs = current.startedAtMs
        if (!current.isRecording || target == null || startedAtMs == null) return null
        limitHandle?.cancel()
        limitHandle = null
        val durationMs = audio.stop()
        audioFocus.release()
        val committed = inbox.commit(target)
        part = null
        state = CaptureState.IDLE
        haptics.onCaptureStopped()
        val saved = committed?.let { SavedCapture(it, startedAtMs, durationMs) }
        if (saved != null) publish { it.onCaptureSaved(saved) }
        publish { it.onStateChanged(CaptureState.IDLE) }
        return saved
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
