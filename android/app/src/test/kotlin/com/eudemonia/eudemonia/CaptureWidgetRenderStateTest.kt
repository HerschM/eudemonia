package com.eudemonia.eudemonia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CaptureWidgetRenderStateTest {

    private val idle = CaptureState(isRecording = false, startedAtMs = null)

    @Test
    fun idleWithPermissionStartsCapture() {
        val render = CaptureWidgetRenderState.from(idle, hasMicPermission = true, nowWallMs = 0, nowElapsedMs = 0)

        assertEquals("Record", render.label)
        assertEquals(CaptureWidgetRenderState.Icon.MIC, render.icon)
        assertEquals(CaptureWidgetRenderState.ClickTarget.START_CAPTURE, render.clickTarget)
        assertFalse(render.isRecording)
        assertNull(render.chronometerBase)
    }

    @Test
    fun recordingStopsCaptureAndRunsChronometerFromStartTime() {
        val startedAt = 1_700_000_000_000L
        val recording = CaptureState(isRecording = true, startedAtMs = startedAt)

        val render = CaptureWidgetRenderState.from(
            recording,
            hasMicPermission = true,
            nowWallMs = startedAt + 5_000,
            nowElapsedMs = 90_000,
        )

        assertEquals("Stop", render.label)
        assertEquals(CaptureWidgetRenderState.Icon.STOP, render.icon)
        assertEquals(CaptureWidgetRenderState.ClickTarget.STOP_CAPTURE, render.clickTarget)
        assertTrue(render.isRecording)
        // Started 5 s ago in wall time, so the chronometer base is 5 s before "now" in elapsed time.
        assertEquals(85_000L, render.chronometerBase)
    }

    @Test
    fun startTimeInTheFutureNeverShowsNegativeElapsedTime() {
        val recording = CaptureState(isRecording = true, startedAtMs = 10_000)

        val render = CaptureWidgetRenderState.from(recording, true, nowWallMs = 9_000, nowElapsedMs = 50_000)

        assertEquals(50_000L, render.chronometerBase)
    }

    @Test
    fun idleWithoutPermissionOpensTheApp() {
        val render = CaptureWidgetRenderState.from(idle, hasMicPermission = false, nowWallMs = 0, nowElapsedMs = 0)

        assertEquals("Record", render.label)
        assertEquals(CaptureWidgetRenderState.Icon.MIC, render.icon)
        assertEquals(CaptureWidgetRenderState.ClickTarget.OPEN_APP, render.clickTarget)
    }
}
