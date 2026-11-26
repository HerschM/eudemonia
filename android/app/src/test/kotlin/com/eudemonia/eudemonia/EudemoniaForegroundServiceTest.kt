package com.eudemonia.eudemonia

import android.app.Service
import android.content.Intent
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`

class EudemoniaForegroundServiceTest {

    /** Stands in for [CaptureCore]; records calls in order with the foreground entries. */
    private class FakeCaptureControl(private val calls: MutableList<String>) : CaptureControl {
        val listeners = mutableListOf<CaptureListener>()
        override var state = CaptureState(isRecording = false, startedAtMs = null)

        override fun start(onResult: (CaptureState) -> Unit) { calls.add("start") }
        override fun stop(onResult: (CaptureState) -> Unit) { calls.add("stop") }
        override fun listCommitted(onResult: (List<CommittedCapture>) -> Unit) {}
        override fun addListener(listener: CaptureListener) { listeners.add(listener) }
        override fun removeListener(listener: CaptureListener) { listeners.remove(listener) }
    }

    private val calls = mutableListOf<String>()
    private lateinit var capture: FakeCaptureControl
    private lateinit var service: EudemoniaForegroundService
    private var foregroundSucceeds = true

    @Before
    fun setUp() {
        EudemoniaForegroundService.isRunning = false
        calls.clear()
        foregroundSucceeds = true
        capture = FakeCaptureControl(calls)
        service = EudemoniaForegroundService()
        service.captureProvider = { capture }
        service.foregroundStarter = { _ ->
            calls.add("foreground")
            foregroundSucceeds
        }
        service.onCreate()
    }

    @After
    fun tearDown() {
        EudemoniaForegroundService.isRunning = false
    }

    private fun intentFor(action: String): Intent {
        val intent = mock(Intent::class.java)
        `when`(intent.action).thenReturn(action)
        return intent
    }

    @Test
    fun testServiceConstants() {
        assertEquals("eudemonia_capture", EudemoniaForegroundService.CHANNEL_ID)
        assertEquals("eudemonia_background_channel", EudemoniaForegroundService.LEGACY_CHANNEL_ID)
        assertEquals(1001, EudemoniaForegroundService.NOTIFICATION_ID)
    }

    @Test
    fun testOnCreateRegistersAsCaptureListenerAndOnDestroyRemovesIt() {
        assertEquals(1, capture.listeners.size)

        service.onDestroy()

        assertTrue(capture.listeners.isEmpty())
        assertFalse(EudemoniaForegroundService.isRunning)
    }

    @Test
    fun testPlainStartEntersForegroundWithoutRecording() {
        val result = service.onStartCommand(null, 0, 1)

        assertEquals(Service.START_STICKY, result)
        assertEquals(listOf("foreground"), calls)
        assertTrue(EudemoniaForegroundService.isRunning)
    }

    @Test
    fun testStartCaptureEntersForegroundBeforeRecording() {
        val result = service.onStartCommand(intentFor(ForegroundServiceCoordinator.ACTION_START_CAPTURE), 0, 1)

        assertEquals(Service.START_STICKY, result)
        assertEquals(listOf("foreground", "start"), calls)
        assertTrue(EudemoniaForegroundService.isRunning)
    }

    @Test
    fun testStopCaptureEntersForegroundBeforeStopping() {
        val result = service.onStartCommand(intentFor(ForegroundServiceCoordinator.ACTION_STOP_CAPTURE), 0, 1)

        assertEquals(Service.START_STICKY, result)
        assertEquals(listOf("foreground", "stop"), calls)
    }

    @Test
    fun testForegroundFailureNeverRecordsAndIsNotSticky() {
        foregroundSucceeds = false

        val result = service.onStartCommand(intentFor(ForegroundServiceCoordinator.ACTION_START_CAPTURE), 0, 1)

        assertEquals(Service.START_NOT_STICKY, result)
        assertEquals(listOf("foreground"), calls)
        assertFalse(EudemoniaForegroundService.isRunning)
    }

    @Test
    fun testStopActionEndsAnyRecordingWithoutEnteringForeground() {
        service.onStartCommand(null, 0, 1)
        calls.clear()

        val result = service.onStartCommand(intentFor(ForegroundServiceCoordinator.ACTION_STOP), 0, 2)

        assertEquals(Service.START_NOT_STICKY, result)
        // No foreground entry; any recording is ended so it cannot outlive the service.
        assertEquals(listOf("stop"), calls)
        assertFalse(EudemoniaForegroundService.isRunning)
    }

    @Test
    fun testForegroundEntryUsesCurrentCaptureState() {
        var notifiedState: CaptureState? = null
        service.foregroundStarter = { state ->
            notifiedState = state
            true
        }
        capture.state = CaptureState(isRecording = true, startedAtMs = 99L)

        service.onStartCommand(null, 0, 1)

        assertEquals(CaptureState(isRecording = true, startedAtMs = 99L), notifiedState)
    }

    @Test
    fun testServiceNeverHoldsCaptureBeforeOnCreate() {
        val fresh = EudemoniaForegroundService()
        assertNull(fresh.capture)
    }
}
