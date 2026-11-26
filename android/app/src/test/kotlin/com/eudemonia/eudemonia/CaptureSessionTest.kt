package com.eudemonia.eudemonia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.util.concurrent.Executor

class CaptureSessionTest {

    @get:Rule
    val tmp = TemporaryFolder()

    /** Records like the real recorder (header + PCM); refuses to stop when it never started. */
    private class FakeAudioCapture(var startSucceeds: Boolean = true) : AudioCapture {
        var startCount = 0
        var stopCount = 0
        var target: File? = null
        val durationMs = 1234L

        override fun start(target: File): Boolean {
            startCount++
            target.writeBytes(ByteArray(WavFileWriter.HEADER_BYTES))
            if (!startSucceeds) return false
            this.target = target
            return true
        }

        override fun stop(): Long {
            val file = checkNotNull(target) { "stop() called on a recorder that is not recording" }
            stopCount++
            file.appendBytes(ByteArray(32000))
            target = null
            return durationMs
        }
    }

    private class FakeHaptics : CaptureHaptics {
        var starts = 0
        var stops = 0
        override fun onCaptureStarted() { starts++ }
        override fun onCaptureStopped() { stops++ }
    }

    private class RecordingListener : CaptureListener {
        val events = mutableListOf<Any>()
        override fun onStateChanged(state: CaptureState) { events.add(state) }
        override fun onCaptureSaved(capture: SavedCapture) { events.add(capture) }
    }

    private val now = 1_700_000_000_000L
    private lateinit var dir: File
    private lateinit var audio: FakeAudioCapture
    private lateinit var haptics: FakeHaptics
    private lateinit var listener: RecordingListener
    private lateinit var session: CaptureSession

    @Before
    fun setUp() {
        dir = File(tmp.root, "capture_inbox")
        audio = FakeAudioCapture()
        haptics = FakeHaptics()
        listener = RecordingListener()
        session = CaptureSession(
            audio = audio,
            haptics = haptics,
            inbox = CaptureInbox(dir),
            clock = { now },
            mainPoster = Executor { it.run() },
        )
        session.addListener(listener)
    }

    @Test
    fun startsIdle() {
        assertEquals(CaptureState(isRecording = false, startedAtMs = null), session.state)
    }

    @Test
    fun startRecordsIntoPartFileFiresStartHapticAndNotifies() {
        val state = session.start()

        val recording = CaptureState(isRecording = true, startedAtMs = now)
        assertEquals(recording, state)
        assertEquals(recording, session.state)
        assertEquals(File(dir, "$now.wav.part"), audio.target)
        assertEquals(1, haptics.starts)
        assertEquals(listOf<Any>(recording), listener.events)
    }

    @Test
    fun secondStartIsNoOpWithoutHaptic() {
        session.start()

        val state = session.start()

        assertEquals(CaptureState(isRecording = true, startedAtMs = now), state)
        assertEquals(1, audio.startCount)
        assertEquals(1, haptics.starts)
        assertEquals(1, listener.events.size)
    }

    @Test
    fun failedRecorderStartStaysIdleWithoutHapticAndDiscardsPartFile() {
        audio.startSucceeds = false

        val state = session.start()

        assertFalse(state.isRecording)
        assertFalse(session.state.isRecording)
        assertEquals(0, haptics.starts)
        assertFalse(File(dir, "$now.wav.part").exists())
        assertTrue(listener.events.isEmpty())
    }

    @Test
    fun stopCommitsFiresStopHapticAndEmitsSavedThenIdle() {
        session.start()

        val saved = session.stop()

        val committed = File(dir, "$now.wav")
        assertEquals(SavedCapture(committed, now, audio.durationMs), saved)
        assertTrue(committed.exists())
        assertFalse(File(dir, "$now.wav.part").exists())
        assertEquals(1, haptics.stops)
        val idle = CaptureState(isRecording = false, startedAtMs = null)
        assertEquals(idle, session.state)
        assertEquals(
            listOf(CaptureState(isRecording = true, startedAtMs = now), saved!!, idle),
            listener.events,
        )
    }

    @Test
    fun stopWhenIdleIsNoOp() {
        assertNull(session.stop())

        assertEquals(0, audio.stopCount)
        assertEquals(0, haptics.stops)
        assertTrue(listener.events.isEmpty())
    }

    @Test
    fun removedListenerIsNoLongerNotified() {
        session.removeListener(listener)

        session.start()

        assertTrue(listener.events.isEmpty())
    }
}
