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

    private class FakeAudioFocus : CaptureAudioFocus {
        val calls = mutableListOf<String>()
        override fun acquire() { calls.add("acquire") }
        override fun release() { calls.add("release") }
    }

    private class FakeHaptics : CaptureHaptics {
        var starts = 0
        var stops = 0
        override fun onCaptureStarted() { starts++ }
        override fun onCaptureStopped() { stops++ }
    }

    /** Holds scheduled tasks until the test lets the time pass. */
    private class FakeLimitTimer : CaptureLimitTimer {
        inner class Scheduled(val delayMs: Long, val task: () -> Unit) {
            var cancelled = false
        }

        val scheduled = mutableListOf<Scheduled>()

        override fun schedule(delayMs: Long, task: () -> Unit): CaptureLimitTimer.Handle {
            val entry = Scheduled(delayMs, task)
            scheduled.add(entry)
            return CaptureLimitTimer.Handle { entry.cancelled = true }
        }

        /** Runs every task that has not been cancelled, as if their delay had passed. */
        fun elapse() {
            for (entry in scheduled.toList()) if (!entry.cancelled) entry.task()
        }
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
    private lateinit var focus: FakeAudioFocus
    private lateinit var listener: RecordingListener
    private lateinit var limitTimer: FakeLimitTimer
    private lateinit var session: CaptureSession
    private var clockMs = now

    @Before
    fun setUp() {
        dir = File(tmp.root, "capture_inbox")
        audio = FakeAudioCapture()
        haptics = FakeHaptics()
        focus = FakeAudioFocus()
        listener = RecordingListener()
        limitTimer = FakeLimitTimer()
        session = CaptureSession(
            audio = audio,
            haptics = haptics,
            inbox = CaptureInbox(dir),
            clock = { clockMs },
            mainPoster = Executor { it.run() },
            limitTimer = limitTimer,
            audioFocus = focus,
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

    @Test
    fun audioFocusIsHeldExactlyWhileRecording() {
        session.start()
        assertEquals(listOf("acquire"), focus.calls)

        session.start() // already recording: nothing more is requested
        assertEquals(listOf("acquire"), focus.calls)

        session.stop()
        assertEquals(listOf("acquire", "release"), focus.calls)

        session.stop() // idle: nothing to give back
        assertEquals(listOf("acquire", "release"), focus.calls)
    }

    @Test
    fun audioFocusIsGivenBackWhenTheRecorderCannotStart() {
        audio.startSucceeds = false
        session.start()
        assertEquals(listOf("acquire", "release"), focus.calls)
    }

    @Test
    fun startArmsTheLimitTimerForTheMaximumLength() {
        session.start()

        assertEquals(listOf(CaptureLimits.MAX_RECORDING_MS), limitTimer.scheduled.map { it.delayMs })
    }

    @Test
    fun failedRecorderStartArmsNoLimitTimer() {
        audio.startSucceeds = false

        session.start()

        assertTrue(limitTimer.scheduled.isEmpty())
    }

    @Test
    fun reachingTheLimitStopsAndSavesOnceLikeAUserStop() {
        session.start()

        limitTimer.elapse()

        val committed = File(dir, "$now.wav")
        val saved = SavedCapture(committed, now, audio.durationMs)
        assertTrue(committed.exists())
        assertFalse(File(dir, "$now.wav.part").exists())
        assertEquals(1, audio.stopCount)
        assertEquals(1, haptics.stops)
        assertEquals(listOf("acquire", "release"), focus.calls)
        assertEquals(CaptureState.IDLE, session.state)
        assertEquals(
            listOf(CaptureState(isRecording = true, startedAtMs = now), saved, CaptureState.IDLE),
            listener.events,
        )

        limitTimer.elapse()
        assertEquals(1, audio.stopCount)
        assertEquals(1, CaptureInbox(dir).listCommitted().size)
    }

    @Test
    fun userStopBeforeTheLimitCancelsTheTimer() {
        session.start()

        session.stop()

        assertTrue(limitTimer.scheduled.single().cancelled)
        limitTimer.elapse()
        assertEquals(1, audio.stopCount)
        assertEquals(1, haptics.stops)
    }

    @Test
    fun limitFiringRightAfterAUserStopSavesOneFile() {
        session.start()

        // The limit task was already running when the user stopped, so cancelling came too late.
        session.stop()
        limitTimer.scheduled.single().task()

        assertEquals(1, audio.stopCount)
        assertEquals(1, haptics.stops)
        assertEquals(1, CaptureInbox(dir).listCommitted().size)
        assertEquals(CaptureState.IDLE, session.state)
    }

    @Test
    fun userStopRightAfterTheLimitIsANoOp() {
        session.start()
        limitTimer.elapse()

        assertNull(session.stop())

        assertEquals(1, audio.stopCount)
        assertEquals(1, haptics.stops)
        assertEquals(1, CaptureInbox(dir).listCommitted().size)
    }

    @Test
    fun startRightAfterTheLimitRecordsAsUsual() {
        session.start()
        limitTimer.elapse()
        clockMs = now + CaptureLimits.MAX_RECORDING_MS

        val state = session.start()

        assertEquals(CaptureState(isRecording = true, startedAtMs = clockMs), state)
        assertEquals(File(dir, "$clockMs.wav.part"), audio.target)
        assertEquals(2, haptics.starts)
        assertEquals(2, limitTimer.scheduled.size)
        assertFalse(limitTimer.scheduled.last().cancelled)
    }

    @Test
    fun aLateLimitOfAnEarlierRecordingNeverStopsTheNextOne() {
        session.start()
        val firstLimit = limitTimer.scheduled.single()
        session.stop()
        clockMs = now + 10_000
        session.start()

        firstLimit.task()

        assertTrue(session.state.isRecording)
        assertEquals(1, audio.stopCount)
    }
}
