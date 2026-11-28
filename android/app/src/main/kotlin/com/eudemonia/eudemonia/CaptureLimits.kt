package com.eudemonia.eudemonia

/** How long one recording may run; the single source of truth for native surfaces and Dart. */
object CaptureLimits {
    /** A recording stops and is saved, exactly like a user stop, when it reaches this length. */
    const val MAX_RECORDING_MS = 5 * 60 * 1000L

    /** Chronometer format of a running recording, e.g. `Recording 1:30 / 5:00` (`%s` is the elapsed time). */
    val RECORDING_CHRONOMETER_FORMAT = "Recording %s / ${formatMinutesSeconds(MAX_RECORDING_MS)}"

    /** `m:ss`, the way a Chronometer shows a time under an hour. */
    fun formatMinutesSeconds(ms: Long): String {
        val totalSeconds = ms.coerceAtLeast(0) / 1000
        return "${totalSeconds / 60}:${(totalSeconds % 60).toString().padStart(2, '0')}"
    }
}

/** Runs a task once after a delay, independently of Flutter; the returned handle cancels it. */
fun interface CaptureLimitTimer {
    fun schedule(delayMs: Long, task: () -> Unit): Handle

    fun interface Handle {
        fun cancel()
    }
}
