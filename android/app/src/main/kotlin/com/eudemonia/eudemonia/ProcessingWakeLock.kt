package com.eudemonia.eudemonia

import android.content.Context
import android.os.PowerManager

/** One CPU wake lock as [ProcessingWakeLock] sees it; the real one wraps a [PowerManager.WakeLock]. */
interface WakeLockHandle {
    val isHeld: Boolean

    /** Keeps the CPU awake for at most [timeoutMs]; a repeated call restarts the countdown. */
    fun acquire(timeoutMs: Long)

    fun release()
}

/**
 * Keeps the CPU awake while on-device processing (transcription, synthesis) runs with the screen off.
 *
 * Without a wake lock Android suspends the CPU of an unplugged phone and a model turn freezes
 * mid-way. Every lock is bounded by a timeout, so a stuck or killed caller can never drain the
 * battery; each named owner has its own lock and releasing one never affects another.
 */
class ProcessingWakeLock(private val newHandle: (tag: String) -> WakeLockHandle) {

    companion object {
        const val CHANNEL = "com.eudemonia.eudemonia/processing_wake_lock"
        const val METHOD_HOLD = "hold"
        const val METHOD_RELEASE = "release"

        private const val TAG_PREFIX = "Eudemonia:"

        fun create(context: Context): ProcessingWakeLock {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            return ProcessingWakeLock { tag ->
                val lock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, tag)
                // One acquire per hold: a repeated hold extends the lock instead of stacking.
                lock.setReferenceCounted(false)
                PowerManagerHandle(lock)
            }
        }
    }

    private class PowerManagerHandle(private val lock: PowerManager.WakeLock) : WakeLockHandle {
        override val isHeld: Boolean get() = lock.isHeld

        override fun acquire(timeoutMs: Long) = lock.acquire(timeoutMs)

        override fun release() = lock.release()
    }

    private val handles = mutableMapOf<String, WakeLockHandle>()

    /**
     * Holds the CPU awake for [timeoutMs] on behalf of [owner], or extends that owner's lock.
     *
     * @throws IllegalArgumentException when [owner] is blank or [timeoutMs] is not positive.
     */
    @Synchronized
    fun hold(owner: String, timeoutMs: Long) {
        require(owner.isNotBlank()) { "owner must not be blank" }
        require(timeoutMs > 0) { "timeoutMs must be positive" }
        handles.getOrPut(owner) { newHandle(TAG_PREFIX + owner) }.acquire(timeoutMs)
    }

    /** Lets the CPU sleep again for [owner]; does nothing when that owner holds nothing. */
    @Synchronized
    fun release(owner: String) {
        handles.remove(owner)?.let(::releaseIfHeld)
    }

    @Synchronized
    fun releaseAll() {
        handles.values.forEach(::releaseIfHeld)
        handles.clear()
    }

    // A lock whose timeout already ran out is no longer held; releasing it again would throw.
    private fun releaseIfHeld(handle: WakeLockHandle) {
        if (handle.isHeld) handle.release()
    }
}
