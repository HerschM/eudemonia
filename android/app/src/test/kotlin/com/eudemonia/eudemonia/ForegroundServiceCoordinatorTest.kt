package com.eudemonia.eudemonia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ForegroundServiceCoordinatorTest {

    private lateinit var coordinator: ForegroundServiceCoordinator
    private var triggerCount = 0
    private var lastLockedState = false
    private var startNotificationCalled = false
    private var stopNotificationCalled = false
    private var startCaptureCalled = false
    private var stopCaptureCalled = false
    private var lastRecordedStateUpdate: Boolean? = null

    @Before
    fun setUp() {
        triggerCount = 0
        lastLockedState = false
        startNotificationCalled = false
        stopNotificationCalled = false
        startCaptureCalled = false
        stopCaptureCalled = false
        lastRecordedStateUpdate = null

        coordinator = ForegroundServiceCoordinator(
            onStartForeground = { startNotificationCalled = true },
            onStopForeground = { stopNotificationCalled = true },
            onTriggerDelivered = { isLocked ->
                triggerCount++
                lastLockedState = isLocked
            },
            onStartCaptureTriggered = { startCaptureCalled = true },
            onStopCaptureTriggered = { stopCaptureCalled = true },
            onRecordingStateUpdated = { isRecording -> lastRecordedStateUpdate = isRecording }
        )
    }

    @Test
    fun testInitialStateIsNotRunning() {
        assertFalse(coordinator.isRunning)
        assertEquals(0, triggerCount)
    }

    @Test
    fun testStartServiceTransitionsStateToRunning() {
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_START)
        assertTrue(coordinator.isRunning)
        assertTrue(startNotificationCalled)
        assertFalse(stopNotificationCalled)
    }

    @Test
    fun testStopServiceTransitionsStateToStopped() {
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_START)
        assertTrue(coordinator.isRunning)

        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_STOP)
        assertFalse(coordinator.isRunning)
        assertTrue(stopNotificationCalled)
    }

    @Test
    fun testHardwareTriggerDeliveredSuccessfully() {
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_START)
        coordinator.onHardwareTriggerReceived(isLocked = true)

        assertEquals(1, triggerCount)
        assertTrue(lastLockedState)

        coordinator.onHardwareTriggerReceived(isLocked = false)
        assertEquals(2, triggerCount)
        assertFalse(lastLockedState)
    }

    @Test
    fun testRedundantStartCallsAreIdempotent() {
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_START)
        assertTrue(coordinator.isRunning)

        // Second start call
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_START)
        assertTrue(coordinator.isRunning)
    }

    @Test
    fun testStartCaptureCommandTransitionsRecordingStateAndTriggersCallback() {
        assertFalse(coordinator.isRecording)
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_START_CAPTURE)
        assertTrue(coordinator.isRecording)
        assertTrue(startCaptureCalled)
        assertFalse(stopCaptureCalled)
    }

    @Test
    fun testStopCaptureCommandTransitionsRecordingStateAndTriggersCallback() {
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_START_CAPTURE)
        assertTrue(coordinator.isRecording)

        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_STOP_CAPTURE)
        assertFalse(coordinator.isRecording)
        assertTrue(stopCaptureCalled)
    }

    @Test
    fun testUpdateRecordingStateCommandSyncsRecordingState() {
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_UPDATE_RECORDING_STATE, true)
        assertTrue(coordinator.isRecording)
        assertEquals(true, lastRecordedStateUpdate)

        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_UPDATE_RECORDING_STATE, false)
        assertFalse(coordinator.isRecording)
        assertEquals(false, lastRecordedStateUpdate)
    }
}
