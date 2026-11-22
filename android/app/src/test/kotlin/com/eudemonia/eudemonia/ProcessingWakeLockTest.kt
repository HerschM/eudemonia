package com.eudemonia.eudemonia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ProcessingWakeLockTest {

    private class FakeHandle(val tag: String) : WakeLockHandle {
        val acquireTimeouts = mutableListOf<Long>()
        var releaseCount = 0
        override var isHeld = false
            private set

        override fun acquire(timeoutMs: Long) {
            acquireTimeouts.add(timeoutMs)
            isHeld = true
        }

        override fun release() {
            releaseCount++
            isHeld = false
        }
    }

    private val handles = mutableListOf<FakeHandle>()
    private lateinit var wakeLock: ProcessingWakeLock

    @Before
    fun setUp() {
        handles.clear()
        wakeLock = ProcessingWakeLock { tag -> FakeHandle(tag).also { handles.add(it) } }
    }

    private fun handleFor(owner: String) = handles.single { it.tag == "Eudemonia:$owner" }

    @Test
    fun testHoldAcquiresTaggedLockWithTimeout() {
        wakeLock.hold("synthesis", 600_000L)

        assertEquals(1, handles.size)
        assertEquals("Eudemonia:synthesis", handles[0].tag)
        assertEquals(listOf(600_000L), handles[0].acquireTimeouts)
        assertTrue(handles[0].isHeld)
    }

    @Test
    fun testSecondHoldForSameOwnerExtendsTheSameHandle() {
        wakeLock.hold("synthesis", 600_000L)
        wakeLock.hold("synthesis", 300_000L)

        assertEquals("no second lock is created", 1, handles.size)
        assertEquals(listOf(600_000L, 300_000L), handles[0].acquireTimeouts)
        assertEquals(0, handles[0].releaseCount)
        assertTrue(handles[0].isHeld)
    }

    @Test
    fun testOwnersAreIndependent() {
        wakeLock.hold("synthesis", 600_000L)
        wakeLock.hold("transcription", 300_000L)
        assertEquals(2, handles.size)

        wakeLock.release("synthesis")

        assertFalse(handleFor("synthesis").isHeld)
        assertTrue("the other owner keeps the CPU awake", handleFor("transcription").isHeld)
        assertEquals(0, handleFor("transcription").releaseCount)
    }

    @Test
    fun testReleaseOfUnknownOwnerIsNoOp() {
        wakeLock.hold("synthesis", 600_000L)

        wakeLock.release("transcription")

        assertEquals(1, handles.size)
        assertTrue(handles[0].isHeld)
        assertEquals(0, handles[0].releaseCount)
    }

    @Test
    fun testReleaseTwiceReleasesOnce() {
        wakeLock.hold("synthesis", 600_000L)

        wakeLock.release("synthesis")
        wakeLock.release("synthesis")

        assertEquals(1, handles[0].releaseCount)
    }

    @Test
    fun testReleaseAfterTimeoutExpiredDoesNotReleaseAgain() {
        wakeLock.hold("synthesis", 600_000L)
        // The OS drops a timed-out lock by itself; releasing it again would throw.
        handles[0].release()

        wakeLock.release("synthesis")

        assertEquals(1, handles[0].releaseCount)
    }

    @Test
    fun testHoldAfterReleaseAcquiresAgain() {
        wakeLock.hold("synthesis", 600_000L)
        wakeLock.release("synthesis")

        wakeLock.hold("synthesis", 600_000L)

        assertTrue(handles.last().isHeld)
        assertEquals("Eudemonia:synthesis", handles.last().tag)
    }

    @Test
    fun testReleaseAllReleasesEveryHeldLock() {
        wakeLock.hold("synthesis", 600_000L)
        wakeLock.hold("transcription", 300_000L)

        wakeLock.releaseAll()

        assertTrue(handles.none { it.isHeld })
        assertTrue(handles.all { it.releaseCount == 1 })
    }

    @Test
    fun testReleaseAllWithNothingHeldIsNoOp() {
        wakeLock.releaseAll()

        assertTrue(handles.isEmpty())
    }

    @Test
    fun testNonPositiveTimeoutIsRejectedWithoutTouchingTheLock() {
        assertThrows(IllegalArgumentException::class.java) { wakeLock.hold("synthesis", 0L) }
        assertThrows(IllegalArgumentException::class.java) { wakeLock.hold("synthesis", -5L) }

        assertTrue(handles.isEmpty())
    }

    @Test
    fun testBlankOwnerIsRejectedWithoutTouchingTheLock() {
        assertThrows(IllegalArgumentException::class.java) { wakeLock.hold("", 600_000L) }
        assertThrows(IllegalArgumentException::class.java) { wakeLock.hold("   ", 600_000L) }

        assertTrue(handles.isEmpty())
    }

    @Test
    fun testChannelContractConstants() {
        assertEquals("com.eudemonia.eudemonia/processing_wake_lock", ProcessingWakeLock.CHANNEL)
        assertEquals("hold", ProcessingWakeLock.METHOD_HOLD)
        assertEquals("release", ProcessingWakeLock.METHOD_RELEASE)
    }
}
