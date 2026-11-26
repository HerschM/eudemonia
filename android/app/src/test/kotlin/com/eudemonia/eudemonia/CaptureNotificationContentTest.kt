package com.eudemonia.eudemonia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CaptureNotificationContentTest {

    @Test
    fun idleOffersRecordAction() {
        val content = CaptureNotificationContent.from(CaptureState(isRecording = false, startedAtMs = null))

        assertEquals("Eudemonia", content.title)
        assertEquals("Tap Record to capture a thought", content.text)
        assertEquals("Record Thought", content.actionLabel)
        assertEquals("Record", content.buttonLabel)
        assertEquals(ForegroundServiceCoordinator.ACTION_START_CAPTURE, content.action)
        assertFalse(content.usesChronometer)
        assertNull(content.whenMs)
    }

    @Test
    fun recordingOffersStopActionWithChronometerFromStartTime() {
        val content = CaptureNotificationContent.from(CaptureState(isRecording = true, startedAtMs = 1234L))

        assertEquals("Recording thought", content.title)
        assertEquals("Stop & Save", content.actionLabel)
        assertEquals("Stop & Save", content.buttonLabel)
        assertEquals(ForegroundServiceCoordinator.ACTION_STOP_CAPTURE, content.action)
        assertTrue(content.usesChronometer)
        assertEquals(1234L, content.whenMs)
    }

    @Test
    fun noTextMentionsVolumeButtonsOrBackgroundListener() {
        val all = listOf(
            CaptureNotificationContent.from(CaptureState(false, null)),
            CaptureNotificationContent.from(CaptureState(true, 1L)),
        ).flatMap { listOf(it.title, it.text, it.actionLabel, it.buttonLabel) } +
            listOf(CaptureNotificationFactory.CHANNEL_NAME, CaptureNotificationFactory.CHANNEL_DESCRIPTION)

        for (text in all.filterNotNull()) {
            assertFalse(text, text.contains("volume", ignoreCase = true))
            assertFalse(text, text.contains("listener", ignoreCase = true))
        }
    }
}
