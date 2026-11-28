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

        assertEquals("Capture a thought", render.title)
        assertEquals("Tap to record", render.subtitle)
        assertEquals("Record", render.compactLabel)
        assertEquals("Record a thought", render.contentDescription)
        assertEquals(CaptureWidgetRenderState.Icon.MIC, render.icon)
        assertEquals(CaptureWidgetRenderState.ClickTarget.START_CAPTURE, render.clickTarget)
        assertFalse(render.isRecording)
        assertNull(render.chronometerBase)
        assertNull(render.chronometerFormat)
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

        assertEquals("Recording", render.title)
        assertEquals("Tap to stop and save", render.subtitle)
        assertEquals("Recording", render.compactLabel)
        assertEquals("Stop and save the recording", render.contentDescription)
        assertEquals("Recording %s / 5:00", render.chronometerFormat)
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

        assertEquals("Capture a thought", render.title)
        assertEquals("Open the app to allow the microphone", render.subtitle)
        assertEquals("Record", render.compactLabel)
        assertEquals("Record a thought", render.contentDescription)
        assertEquals(CaptureWidgetRenderState.Icon.MIC, render.icon)
        assertEquals(CaptureWidgetRenderState.ClickTarget.OPEN_APP, render.clickTarget)
    }

    @Test
    fun layoutIsCompactBelowTheFullWidthThresholdAndFullFromIt() {
        val threshold = CaptureWidgetRenderState.FULL_MIN_WIDTH_DP

        assertEquals(180, threshold)
        assertEquals(CaptureWidgetRenderState.LayoutSize.COMPACT, CaptureWidgetRenderState.layoutSizeFor(threshold - 1))
        assertEquals(CaptureWidgetRenderState.LayoutSize.FULL, CaptureWidgetRenderState.layoutSizeFor(threshold))
        assertEquals(CaptureWidgetRenderState.LayoutSize.FULL, CaptureWidgetRenderState.layoutSizeFor(threshold + 70))
    }

    @Test
    fun twoCellWidgetIsCompactAndFourCellWidgetIsFull() {
        // Typical launcher widths: ~110dp for two cells, ~250dp for four.
        assertEquals(CaptureWidgetRenderState.LayoutSize.COMPACT, CaptureWidgetRenderState.layoutSizeFor(110))
        assertEquals(CaptureWidgetRenderState.LayoutSize.FULL, CaptureWidgetRenderState.layoutSizeFor(250))
    }

    @Test
    fun unknownWidthFallsBackToTheFullLayout() {
        assertEquals(CaptureWidgetRenderState.LayoutSize.FULL, CaptureWidgetRenderState.layoutSizeFor(null))
        assertEquals(CaptureWidgetRenderState.LayoutSize.FULL, CaptureWidgetRenderState.layoutSizeFor(0))
    }

    @Test
    fun compactThresholdIsTheSmallestResizableWidth() {
        assertEquals(110, CaptureWidgetRenderState.COMPACT_MIN_WIDTH_DP)
        assertTrue(CaptureWidgetRenderState.COMPACT_MIN_WIDTH_DP < CaptureWidgetRenderState.FULL_MIN_WIDTH_DP)
    }
}
