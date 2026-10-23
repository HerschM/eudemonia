package com.eudemonia.eudemonia

class TriggerDebouncer(
    private val cooldownMs: Long = 500L,
    private val clock: () -> Long = { System.currentTimeMillis() }
) {
    companion object {
        val shared = TriggerDebouncer(cooldownMs = 500L)
    }

    private var lastTriggerTime: Long = 0L

    @Synchronized
    fun tryTrigger(): Boolean {
        val now = clock()
        if (now - lastTriggerTime >= cooldownMs) {
            lastTriggerTime = now
            return true
        }
        return false
    }

    @Synchronized
    fun reset() {
        lastTriggerTime = 0L
    }
}
