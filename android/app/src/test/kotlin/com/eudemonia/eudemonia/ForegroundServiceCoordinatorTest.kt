package com.eudemonia.eudemonia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ForegroundServiceCoordinatorTest {

    private lateinit var coordinator: ForegroundServiceCoordinator
    private var startCount = 0
    private var stopCount = 0

    @Before
    fun setUp() {
        startCount = 0
        stopCount = 0
        coordinator = ForegroundServiceCoordinator(
            onStartForeground = { startCount++ },
            onStopForeground = { stopCount++ }
        )
    }

    @Test
    fun testActionConstants() {
        assertEquals("com.eudemonia.eudemonia.START_FOREGROUND", ForegroundServiceCoordinator.ACTION_START)
        assertEquals("com.eudemonia.eudemonia.STOP_FOREGROUND", ForegroundServiceCoordinator.ACTION_STOP)
        assertEquals("com.eudemonia.eudemonia.ACTION_START_CAPTURE", ForegroundServiceCoordinator.ACTION_START_CAPTURE)
        assertEquals("com.eudemonia.eudemonia.ACTION_STOP_CAPTURE", ForegroundServiceCoordinator.ACTION_STOP_CAPTURE)
    }

    @Test
    fun testInitialStateIsNotRunning() {
        assertFalse(coordinator.isRunning)
    }

    @Test
    fun testStartServiceTransitionsStateToRunning() {
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_START)
        assertTrue(coordinator.isRunning)
        assertEquals(1, startCount)
        assertEquals(0, stopCount)
    }

    @Test
    fun testStopServiceTransitionsStateToStopped() {
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_START)
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_STOP)
        assertFalse(coordinator.isRunning)
        assertEquals(1, stopCount)
    }

    @Test
    fun testRedundantStartAndStopCallsAreIdempotent() {
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_START)
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_START)
        assertTrue(coordinator.isRunning)
        assertEquals(1, startCount)

        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_STOP)
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_STOP)
        assertEquals(1, stopCount)
    }

    @Test
    fun testCaptureActionsDoNotChangeRunningState() {
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_START_CAPTURE)
        coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_STOP_CAPTURE)
        assertFalse(coordinator.isRunning)
        assertEquals(0, startCount)
    }
}
