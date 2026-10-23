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

    @Before
    fun setUp() {
        triggerCount = 0
        lastLockedState = false
        startNotificationCalled = false
        stopNotificationCalled = false

        coordinator = ForegroundServiceCoordinator(
            onStartForeground = { startNotificationCalled = true },
            onStopForeground = { stopNotificationCalled = true },
            onTriggerDelivered = { isLocked ->
                triggerCount++
                lastLockedState = isLocked
            }
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
}
