package com.eudemonia.eudemonia

import org.junit.Assert.assertEquals
import org.junit.Test

class CaptureLimitsTest {

    @Test
    fun recordingIsLimitedToFiveMinutes() {
        assertEquals(5 * 60 * 1000L, CaptureLimits.MAX_RECORDING_MS)
    }

    @Test
    fun formatsMinutesAndSecondsLikeAChronometer() {
        assertEquals("0:00", CaptureLimits.formatMinutesSeconds(0))
        assertEquals("0:09", CaptureLimits.formatMinutesSeconds(9_999))
        assertEquals("1:30", CaptureLimits.formatMinutesSeconds(90_000))
        assertEquals("5:00", CaptureLimits.formatMinutesSeconds(CaptureLimits.MAX_RECORDING_MS))
        assertEquals("12:05", CaptureLimits.formatMinutesSeconds(725_000))
    }

    @Test
    fun runningTimerFormatCarriesTheLimit() {
        assertEquals("Recording %s / 5:00", CaptureLimits.RECORDING_CHRONOMETER_FORMAT)
        assertEquals("Recording 1:30 / 5:00", String.format(CaptureLimits.RECORDING_CHRONOMETER_FORMAT, "1:30"))
    }
}
