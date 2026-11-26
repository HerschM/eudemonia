package com.eudemonia.eudemonia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class MockScheduler : Scheduler {
    data class Task(val token: Any, val executionTimeMs: Long, val action: () -> Unit)

    var currentTimeMs: Long = 0L
    val pendingTasks = mutableListOf<Task>()

    override fun postDelayed(token: Any, delayMs: Long, action: () -> Unit) {
        cancel(token)
        pendingTasks.add(Task(token, currentTimeMs + delayMs, action))
        pendingTasks.sortBy { it.executionTimeMs }
    }

    override fun cancel(token: Any) {
        pendingTasks.removeAll { it.token == token }
    }

    override fun cancelAll() {
        pendingTasks.clear()
    }

    fun advanceTimeBy(ms: Long) {
        val targetTime = currentTimeMs + ms
        while (pendingTasks.isNotEmpty()) {
            val nextTask = pendingTasks.first()
            if (nextTask.executionTimeMs <= targetTime) {
                currentTimeMs = nextTask.executionTimeMs
                pendingTasks.removeAt(0)
                nextTask.action()
            } else {
                break
            }
        }
        currentTimeMs = targetTime
    }
}

class MockVolumeActionHandler : VolumeActionHandler {
    val volumeAdjustments = mutableListOf<Int>()
    var triggerCount = 0

    override fun adjustVolume(direction: Int) {
        volumeAdjustments.add(direction)
    }

    override fun triggerVoicePipeline() {
        triggerCount++
    }
}

class VolumeButtonCoordinatorTest {

    private lateinit var scheduler: MockScheduler
    private lateinit var handler: MockVolumeActionHandler
    private lateinit var coordinator: VolumeButtonCoordinator

    @Before
    fun setUp() {
        scheduler = MockScheduler()
        handler = MockVolumeActionHandler()
        coordinator = VolumeButtonCoordinator(
            actionHandler = handler,
            scheduler = scheduler,
            dualPressWindowMs = 50L,
            initialRepeatDelayMs = 300L,
            repeatIntervalMs = 100L,
            maxRepeatSteps = 25
        )
    }

    @Test
    fun testSingleClickVolumeUp_executesSingleStepAndStops() {
        // Press Volume Up at 0ms
        val downConsumed = coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_UP)
        assertTrue(downConsumed)
        assertTrue(coordinator.isVolumeUpPressed)
        assertEquals(0, handler.volumeAdjustments.size)

        // Release after 20ms (fast click)
        scheduler.advanceTimeBy(20)
        val upConsumed = coordinator.onKeyUp(VolumeButtonCoordinator.KEY_VOLUME_UP)
        assertTrue(upConsumed)
        assertFalse(coordinator.isVolumeUpPressed)

        // Advance past the 50ms dual-press window
        scheduler.advanceTimeBy(35) // Total 55ms
        assertEquals("Should have exactly 1 volume up adjustment", listOf(VolumeButtonCoordinator.DIRECTION_UP), handler.volumeAdjustments)
        assertEquals("Trigger must not be called", 0, handler.triggerCount)

        // Advance 10 seconds into the future -> verify NO RUNAWAY
        scheduler.advanceTimeBy(10000)
        assertEquals("Volume adjustments must remain 1 (no runaway)", 1, handler.volumeAdjustments.size)
        assertTrue("No pending tasks should remain", scheduler.pendingTasks.isEmpty())
    }

    @Test
    fun testSingleClickVolumeDown_executesSingleStepAndStops() {
        // Press Volume Down at 0ms
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_DOWN)

        // Release after 25ms
        scheduler.advanceTimeBy(25)
        coordinator.onKeyUp(VolumeButtonCoordinator.KEY_VOLUME_DOWN)

        // Dual press window expires at 50ms
        scheduler.advanceTimeBy(30)
        assertEquals(listOf(VolumeButtonCoordinator.DIRECTION_DOWN), handler.volumeAdjustments)

        // Verify zero runaway
        scheduler.advanceTimeBy(5000)
        assertEquals(1, handler.volumeAdjustments.size)
        assertTrue(scheduler.pendingTasks.isEmpty())
    }

    @Test
    fun testNormalTap_heldPastWindow_releasedBeforeRepeat() {
        // Press Volume Up at 0ms
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_UP)

        // At 50ms, dual press window expires, first step fires, repeat tick scheduled for 50+300 = 350ms
        scheduler.advanceTimeBy(50)
        assertEquals(1, handler.volumeAdjustments.size)

        // User releases button at 100ms
        scheduler.advanceTimeBy(50)
        coordinator.onKeyUp(VolumeButtonCoordinator.KEY_VOLUME_UP)

        // Advance time past 350ms
        scheduler.advanceTimeBy(500)
        assertEquals("Repeat must be cancelled on key release, total adjustments must be 1", 1, handler.volumeAdjustments.size)
        assertTrue(scheduler.pendingTasks.isEmpty())
    }

    @Test
    fun testContinuousHoldVolumeUp_rampsVolumeAndStopsImmediatelyOnRelease() {
        // Press Volume Up at 0ms
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_UP)

        // T=50ms: 1st step fires
        scheduler.advanceTimeBy(50)
        assertEquals(1, handler.volumeAdjustments.size)

        // T=350ms: Initial repeat delay (300ms) expires, 2nd step fires
        scheduler.advanceTimeBy(300)
        assertEquals(2, handler.volumeAdjustments.size)

        // T=450ms: Repeat interval (100ms) expires, 3rd step fires
        scheduler.advanceTimeBy(100)
        assertEquals(3, handler.volumeAdjustments.size)

        // T=550ms: 4th step fires
        scheduler.advanceTimeBy(100)
        assertEquals(4, handler.volumeAdjustments.size)

        // T=650ms: 5th step fires
        scheduler.advanceTimeBy(100)
        assertEquals(5, handler.volumeAdjustments.size)

        // T=680ms: User releases Volume Up!
        scheduler.advanceTimeBy(30)
        coordinator.onKeyUp(VolumeButtonCoordinator.KEY_VOLUME_UP)

        // Advance time by 30 seconds -> MUST NOT fire any more steps!
        scheduler.advanceTimeBy(30000)
        assertEquals("Must remain at exactly 5 steps after release (zero runaway)", 5, handler.volumeAdjustments.size)
        assertTrue("All repeat tasks must be cancelled", scheduler.pendingTasks.isEmpty())
    }

    @Test
    fun testContinuousHoldVolumeDown_rampsVolumeAndStopsImmediatelyOnRelease() {
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_DOWN)

        // Initial step at 50ms
        scheduler.advanceTimeBy(50)
        assertEquals(listOf(VolumeButtonCoordinator.DIRECTION_DOWN), handler.volumeAdjustments)

        // Next steps at 350ms, 450ms, 550ms
        scheduler.advanceTimeBy(500)
        assertEquals(4, handler.volumeAdjustments.size)
        assertTrue(handler.volumeAdjustments.all { it == VolumeButtonCoordinator.DIRECTION_DOWN })

        // Release button
        coordinator.onKeyUp(VolumeButtonCoordinator.KEY_VOLUME_DOWN)

        scheduler.advanceTimeBy(10000)
        assertEquals(4, handler.volumeAdjustments.size)
        assertTrue(scheduler.pendingTasks.isEmpty())
    }

    @Test
    fun testSafetyCap_stopsAtMaxRepeatStepsEvenIfReleaseEventIsLost() {
        // Button held down, but release event is dropped (e.g. OS bug simulation)
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_UP)

        // Advance 10 minutes into the future
        scheduler.advanceTimeBy(600_000)

        // Total steps = 1 initial + maxRepeatSteps (25) = 26 steps
        val expectedSteps = 1 + coordinator.maxRepeatSteps
        assertEquals(expectedSteps, handler.volumeAdjustments.size)
        assertTrue("Should have stopped scheduling after hitting maxRepeatSteps cap", scheduler.pendingTasks.isEmpty())
    }

    @Test
    fun testSimultaneousDualPress_triggersVoicePipeline_withoutChangingVolume() {
        // Press Vol Up at 0ms
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_UP)

        // Press Vol Down at 20ms (within 50ms dual-press window)
        scheduler.advanceTimeBy(20)
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_DOWN)

        assertEquals("Voice pipeline must be triggered", 1, handler.triggerCount)
        assertTrue("Volume must NOT change during dual-press combo", handler.volumeAdjustments.isEmpty())
        assertTrue("Dual trigger active must be true", coordinator.isDualTriggerActive)

        // Advance time during the hold
        scheduler.advanceTimeBy(2000)
        assertEquals(1, handler.triggerCount)
        assertTrue("Volume must still NOT change while holding dual buttons", handler.volumeAdjustments.isEmpty())

        // Release Vol Up at 2020ms
        coordinator.onKeyUp(VolumeButtonCoordinator.KEY_VOLUME_UP)
        assertTrue("Dual trigger remains active until both keys released", coordinator.isDualTriggerActive)

        // Release Vol Down at 2050ms
        scheduler.advanceTimeBy(30)
        coordinator.onKeyUp(VolumeButtonCoordinator.KEY_VOLUME_DOWN)
        assertFalse("Dual trigger resets when both keys released", coordinator.isDualTriggerActive)

        // Advance time further
        scheduler.advanceTimeBy(5000)
        assertEquals(1, handler.triggerCount)
        assertTrue("Volume must NEVER have changed throughout entire combo", handler.volumeAdjustments.isEmpty())
    }

    @Test
    fun testStaggeredDualPress_cancelsRepeatAndFiresTrigger() {
        // Press Vol Up at 0ms
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_UP)

        // Vol Up held for 100ms (1 step fires at 50ms)
        scheduler.advanceTimeBy(100)
        assertEquals(1, handler.volumeAdjustments.size)

        // User now presses Vol Down (e.g. decided to trigger combo)
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_DOWN)
        assertEquals("Dual trigger fired", 1, handler.triggerCount)

        // Advance time: repeats for Vol Up must have been cancelled
        scheduler.advanceTimeBy(2000)
        assertEquals("No further volume adjustments should have occurred", 1, handler.volumeAdjustments.size)

        // Release both
        coordinator.onKeyUp(VolumeButtonCoordinator.KEY_VOLUME_UP)
        coordinator.onKeyUp(VolumeButtonCoordinator.KEY_VOLUME_DOWN)
        assertFalse(coordinator.isDualTriggerActive)
    }

    @Test
    fun testNativeRepeatEventsIgnored() {
        // Initial press
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_UP, repeatCount = 0)

        // OS sends repeat events while held
        scheduler.advanceTimeBy(50)
        assertEquals(1, handler.volumeAdjustments.size)

        // InputDispatcher repeat events arriving
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_UP, repeatCount = 1)
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_UP, repeatCount = 2)

        // Should not duplicate steps
        assertEquals(1, handler.volumeAdjustments.size)

        scheduler.advanceTimeBy(300)
        assertEquals(2, handler.volumeAdjustments.size)
    }

    @Test
    fun testRapidDoubleTap_executesBothSteps() {
        // Tap 1: Down at 0, Up at 20ms
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_UP)
        scheduler.advanceTimeBy(20)
        coordinator.onKeyUp(VolumeButtonCoordinator.KEY_VOLUME_UP)

        // Tap 2: Down at 35ms (before Tap 1's 50ms window expires)
        scheduler.advanceTimeBy(15)
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_UP)

        // Tap 1 should have flushed immediately when Tap 2 started
        assertEquals("First tap should execute", 1, handler.volumeAdjustments.size)

        // Tap 2: Up at 50ms
        scheduler.advanceTimeBy(15)
        coordinator.onKeyUp(VolumeButtonCoordinator.KEY_VOLUME_UP)

        // Advance past Tap 2's window
        scheduler.advanceTimeBy(50)
        assertEquals("Both taps must be executed", listOf(VolumeButtonCoordinator.DIRECTION_UP, VolumeButtonCoordinator.DIRECTION_UP), handler.volumeAdjustments)
    }

    @Test
    fun testRapidAlternatingVolumeKeys() {
        // Up tap at 0, Up released at 20
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_UP)
        scheduler.advanceTimeBy(20)
        coordinator.onKeyUp(VolumeButtonCoordinator.KEY_VOLUME_UP)

        // Down tap at 30, Down released at 45
        scheduler.advanceTimeBy(10)
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_DOWN)
        assertEquals("First UP tap flushed", listOf(VolumeButtonCoordinator.DIRECTION_UP), handler.volumeAdjustments)

        scheduler.advanceTimeBy(15)
        coordinator.onKeyUp(VolumeButtonCoordinator.KEY_VOLUME_DOWN)

        // Advance past Down window
        scheduler.advanceTimeBy(50)
        assertEquals("Both UP and DOWN taps executed", listOf(VolumeButtonCoordinator.DIRECTION_UP, VolumeButtonCoordinator.DIRECTION_DOWN), handler.volumeAdjustments)
        assertEquals(0, handler.triggerCount)
    }

    @Test
    fun testResetDuringActiveHold() {
        // Hold Volume Up
        coordinator.onKeyDown(VolumeButtonCoordinator.KEY_VOLUME_UP)
        scheduler.advanceTimeBy(50)
        assertEquals(1, handler.volumeAdjustments.size)

        scheduler.advanceTimeBy(300)
        assertEquals(2, handler.volumeAdjustments.size)

        // System interrupts or service restarts
        coordinator.reset()
        assertFalse(coordinator.isVolumeUpPressed)
        assertFalse(coordinator.isVolumeDownPressed)
        assertFalse(coordinator.isDualTriggerActive)
        assertTrue(scheduler.pendingTasks.isEmpty())

        // Advancing time should produce NO further volume adjustments
        scheduler.advanceTimeBy(60000)
        assertEquals(2, handler.volumeAdjustments.size)
    }

    @Test
    fun testNonVolumeKeysIgnored() {
        assertFalse(coordinator.onKeyDown(66)) // Enter
        assertFalse(coordinator.onKeyUp(66))
        assertTrue(scheduler.pendingTasks.isEmpty())
        assertTrue(handler.volumeAdjustments.isEmpty())
    }
}
