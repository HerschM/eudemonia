package com.eudemonia.eudemonia

/** What the capture widget shows and does for a given [CaptureState]; pure so it can be unit-tested. */
data class CaptureWidgetRenderState(
    val isRecording: Boolean,
    /** First line of the full layout; while recording the running chronometer takes its place. */
    val title: String,
    /** Second line of the full layout. */
    val subtitle: String,
    /** The single line of the compact layout (hidden behind the chronometer while recording). */
    val compactLabel: String,
    val contentDescription: String,
    val icon: Icon,
    val clickTarget: ClickTarget,
    /** `SystemClock.elapsedRealtime()` base for the running chronometer, or null to hide it. */
    val chronometerBase: Long?,
    /** Chronometer format of the full layout (`%s` is the elapsed time); null when idle. */
    val chronometerFormat: String?,
) {
    enum class Icon { MIC, STOP }

    enum class LayoutSize { COMPACT, FULL }

    enum class ClickTarget { START_CAPTURE, STOP_CAPTURE, OPEN_APP }

    companion object {
        /** Narrowest width the widget can be resized to (two launcher cells). */
        const val COMPACT_MIN_WIDTH_DP = 110

        /** From this width the title and subtitle fit next to the button; below it only one short line does. */
        const val FULL_MIN_WIDTH_DP = 180

        /** Which layout fits a widget [widthDp] wide; an unknown width gets the full layout. */
        fun layoutSizeFor(widthDp: Int?): LayoutSize =
            if (widthDp != null && widthDp in 1 until FULL_MIN_WIDTH_DP) LayoutSize.COMPACT else LayoutSize.FULL

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
                    title = "Recording",
                    subtitle = "Tap to stop and save",
                    compactLabel = "Recording",
                    contentDescription = "Stop and save the recording",
                    icon = Icon.STOP,
                    clickTarget = ClickTarget.STOP_CAPTURE,
                    chronometerBase = nowElapsedMs - elapsedSinceStart,
                    chronometerFormat = CaptureLimits.RECORDING_CHRONOMETER_FORMAT,
                )
            }
            return CaptureWidgetRenderState(
                isRecording = false,
                title = "Capture a thought",
                subtitle = if (hasMicPermission) "Tap to record" else "Open the app to allow the microphone",
                compactLabel = "Record",
                contentDescription = "Record a thought",
                icon = Icon.MIC,
                clickTarget = if (hasMicPermission) ClickTarget.START_CAPTURE else ClickTarget.OPEN_APP,
                chronometerBase = null,
                chronometerFormat = null,
            )
        }
    }
}
