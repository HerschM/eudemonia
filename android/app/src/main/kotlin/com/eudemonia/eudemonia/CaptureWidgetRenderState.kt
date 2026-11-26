package com.eudemonia.eudemonia

/** What the capture widget shows and does for a given [CaptureState]; pure so it can be unit-tested. */
data class CaptureWidgetRenderState(
    val isRecording: Boolean,
    val label: String,
    val icon: Icon,
    val clickTarget: ClickTarget,
    /** `SystemClock.elapsedRealtime()` base for the running chronometer, or null to hide it. */
    val chronometerBase: Long?,
) {
    enum class Icon { MIC, STOP }

    enum class ClickTarget { START_CAPTURE, STOP_CAPTURE, OPEN_APP }

    companion object {
        /**
         * [nowWallMs] and [nowElapsedMs] are the same instant on the wall clock and on the
         * elapsed-realtime clock, used to convert the wall-clock start into a chronometer base.
         * Without the microphone permission an idle tap opens the app so it can ask for it.
         */
        fun from(
            state: CaptureState,
            hasMicPermission: Boolean,
            nowWallMs: Long,
            nowElapsedMs: Long,
        ): CaptureWidgetRenderState {
            val startedAtMs = state.startedAtMs
            if (state.isRecording && startedAtMs != null) {
                val elapsedSinceStart = (nowWallMs - startedAtMs).coerceAtLeast(0)
                return CaptureWidgetRenderState(
                    isRecording = true,
                    label = "Stop",
                    icon = Icon.STOP,
                    clickTarget = ClickTarget.STOP_CAPTURE,
                    chronometerBase = nowElapsedMs - elapsedSinceStart,
                )
            }
            return CaptureWidgetRenderState(
                isRecording = false,
                label = "Record",
                icon = Icon.MIC,
                clickTarget = if (hasMicPermission) ClickTarget.START_CAPTURE else ClickTarget.OPEN_APP,
                chronometerBase = null,
            )
        }
    }
}
