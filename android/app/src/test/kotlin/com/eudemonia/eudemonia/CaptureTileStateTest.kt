package com.eudemonia.eudemonia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CaptureTileStateTest {

    @Test
    fun idleTileStartsACapture() {
        val tile = CaptureTileState.from(CaptureState.IDLE)
        assertFalse(tile.active)
        assertEquals("Record", tile.label)
        assertEquals("Tap to record", tile.subtitle)
        assertEquals(ForegroundServiceCoordinator.ACTION_START_CAPTURE, tile.action)
    }

    @Test
    fun recordingTileStopsAndSaves() {
        val tile = CaptureTileState.from(CaptureState(isRecording = true, startedAtMs = 1_000L))
        assertTrue(tile.active)
        assertEquals("Recording", tile.label)
        assertEquals("Tap to stop", tile.subtitle)
        assertEquals(ForegroundServiceCoordinator.ACTION_STOP_CAPTURE, tile.action)
    }
}
