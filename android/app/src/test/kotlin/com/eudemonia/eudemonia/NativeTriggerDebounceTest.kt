package com.eudemonia.eudemonia

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class NativeTriggerDebounceTest {

    private lateinit var debouncer: TriggerDebouncer
    private var currentTimeMs: Long = 1000L

    @Before
    fun setUp() {
        currentTimeMs = 1000L
        debouncer = TriggerDebouncer(cooldownMs = 500L, clock = { currentTimeMs })
    }

    @Test
    fun testFirstTriggerSucceeds() {
        assertTrue(debouncer.tryTrigger())
    }

    @Test
    fun testDuplicateTriggersWithinCooldownAreSuppressed() {
        assertTrue(debouncer.tryTrigger())

        // 50ms later (rapid duplicate broadcast or echo)
        currentTimeMs += 50L
        assertFalse(debouncer.tryTrigger())

        // 200ms later
        currentTimeMs += 150L
        assertFalse(debouncer.tryTrigger())
    }

    @Test
    fun testTriggerSucceedsAfterCooldownExpires() {
        assertTrue(debouncer.tryTrigger())

        // 501ms later
        currentTimeMs += 501L
        assertTrue(debouncer.tryTrigger())
    }
}
