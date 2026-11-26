package com.eudemonia.eudemonia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingStateTrackerTest {

    @Test
    fun testInitialStateIsNotRecording() {
        assertFalse(RecordingStateTracker().isRecording)
    }

    @Test
    fun testTriggersAlternateBetweenStartAndStop() {
        val tracker = RecordingStateTracker()

        assertTrue("first trigger starts a recording", tracker.onTriggerFired())
        assertFalse("second trigger stops it", tracker.onTriggerFired())
        assertTrue("third trigger starts again", tracker.onTriggerFired())
    }

    @Test
    fun testDroppedTriggerIsCorrectedByAuthoritativeState() {
        val tracker = RecordingStateTracker()

        // Trigger fired (start haptic played) but the app never began recording.
        assertTrue(tracker.onTriggerFired())
        tracker.onAuthoritativeState(false)

        // The next press must be signalled as a start again, not as a stop.
        assertTrue(tracker.onTriggerFired())
    }

    @Test
    fun testRecordingStartedElsewhereMakesNextTriggerAStop() {
        val tracker = RecordingStateTracker()

        // Recording was started from the lock screen notification action.
        tracker.onAuthoritativeState(true)

        assertFalse("volume trigger now stops the recording", tracker.onTriggerFired())
        assertFalse(tracker.isRecording)
    }

    @Test
    fun testBroadcastContractConstants() {
        assertEquals(
            "com.eudemonia.eudemonia.RECORDING_STATE_CHANGED",
            RecordingStateTracker.ACTION_RECORDING_STATE_CHANGED
        )
        assertEquals("isRecording", RecordingStateTracker.EXTRA_IS_RECORDING)
    }
}
