package com.eudemonia.eudemonia

import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File

class CaptureChannelCodecTest {

    @Test
    fun encodesIdleAndRecordingState() {
        assertEquals(
            mapOf("isRecording" to false, "startedAtMs" to null, "maxDurationMs" to 300_000L),
            CaptureChannelCodec.encodeState(CaptureState.IDLE)
        )
        assertEquals(
            mapOf("isRecording" to true, "startedAtMs" to 1_700_000_000_000L, "maxDurationMs" to 300_000L),
            CaptureChannelCodec.encodeState(CaptureState(true, 1_700_000_000_000L))
        )
    }

    @Test
    fun everyStateCarriesTheRecordingLimit() {
        for (state in listOf(CaptureState.IDLE, CaptureState(true, 42L))) {
            assertEquals(CaptureLimits.MAX_RECORDING_MS, CaptureChannelCodec.encodeState(state)["maxDurationMs"])
        }
    }

    @Test
    fun encodesSavedAndCommittedCapturesAsPathAndStartTime() {
        val file = File("/data/inbox/42.wav")
        val expected = mapOf("path" to file.absolutePath, "startedAtMs" to 42L)

        assertEquals(expected, CaptureChannelCodec.encodeSaved(SavedCapture(file, 42L, 900L)))
        assertEquals(expected, CaptureChannelCodec.encodeCommitted(CommittedCapture(file, 42L)))
    }

    @Test
    fun methodNamesMatchTheDartContract() {
        assertEquals("onStateChanged", CaptureChannelCodec.METHOD_ON_STATE_CHANGED)
        assertEquals("onCaptureSaved", CaptureChannelCodec.METHOD_ON_CAPTURE_SAVED)
    }
}
