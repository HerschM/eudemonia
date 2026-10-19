package com.eudemonia.eudemonia

interface VolumeActionHandler {
    fun adjustVolume(direction: Int)
    fun triggerVoicePipeline()
}

interface Scheduler {
    fun postDelayed(token: Any, delayMs: Long, action: () -> Unit)
    fun cancel(token: Any)
    fun cancelAll()
}

/**
 * Pure Kotlin coordinator for hardware volume buttons.
 *
 * Requirements:
 * 1. Single click on Volume Up / Down adjusts volume by 1 step.
 * 2. Continuous hold on Volume Up / Down adjusts volume repeatedly at intervals until released.
 *    Stops IMMEDIATELY on release with zero runaway.
 * 3. Simultaneous press of both Volume Up and Volume Down triggers the voice pipeline
 *    without changing system volume.
 * 4. All volume key events (DOWN and UP) are consumed to prevent OS InputDispatcher desync.
 */
class VolumeButtonCoordinator(
    private val actionHandler: VolumeActionHandler,
    private val scheduler: Scheduler,
    val dualPressWindowMs: Long = 50L,
    val initialRepeatDelayMs: Long = 300L,
    val repeatIntervalMs: Long = 100L,
    val maxRepeatSteps: Int = 25
) {
    companion object {
        const val KEY_VOLUME_UP = 24
        const val KEY_VOLUME_DOWN = 25
        const val DIRECTION_UP = 1
        const val DIRECTION_DOWN = -1

        const val TOKEN_DUAL_WINDOW = "TOKEN_DUAL_WINDOW"
        const val TOKEN_REPEAT = "TOKEN_REPEAT"
    }

    var isVolumeUpPressed: Boolean = false
        private set
    var isVolumeDownPressed: Boolean = false
        private set
    var isDualTriggerActive: Boolean = false
        private set

    private var activeHoldingKey: Int = 0
    private var activeDirection: Int = 0
    private var isDualWindowPending: Boolean = false
    private var repeatStepsRemaining: Int = 0

    fun onKeyDown(keyCode: Int, repeatCount: Int = 0): Boolean {
        if (keyCode != KEY_VOLUME_UP && keyCode != KEY_VOLUME_DOWN) {
            return false
        }

        val wasAlreadyPressed = if (keyCode == KEY_VOLUME_UP) isVolumeUpPressed else isVolumeDownPressed

        if (keyCode == KEY_VOLUME_UP) isVolumeUpPressed = true
        if (keyCode == KEY_VOLUME_DOWN) isVolumeDownPressed = true

        // 1. Dual press detection: both volume buttons are down
        if (isVolumeUpPressed && isVolumeDownPressed) {
            cancelAllScheduled()
            if (!isDualTriggerActive) {
                isDualTriggerActive = true
                actionHandler.triggerVoicePipeline()
            }
            return true
        }

        // 2. If already in a triggered dual-button combo session, suppress volume changes
        if (isDualTriggerActive) {
            return true
        }

        // 3. If key was already pressed (native OS repeat or bounce), ignore to prevent resetting timers
        if (wasAlreadyPressed || repeatCount > 0) {
            return true
        }

        // 4. If a previous single click was still waiting in its dual-press window, execute it now
        if (isDualWindowPending) {
            scheduler.cancel(TOKEN_DUAL_WINDOW)
            isDualWindowPending = false
            if (activeHoldingKey != 0) {
                actionHandler.adjustVolume(activeDirection)
            }
        }

        // Stop any ongoing repeat loop from a prior key
        scheduler.cancel(TOKEN_REPEAT)
        repeatStepsRemaining = 0

        // 5. Begin new single key press cycle
        activeHoldingKey = keyCode
        activeDirection = if (keyCode == KEY_VOLUME_UP) DIRECTION_UP else DIRECTION_DOWN
        isDualWindowPending = true

        scheduler.postDelayed(TOKEN_DUAL_WINDOW, dualPressWindowMs) {
            onDualPressWindowExpired(keyCode)
        }

        return true
    }

    fun onKeyUp(keyCode: Int): Boolean {
        if (keyCode != KEY_VOLUME_UP && keyCode != KEY_VOLUME_DOWN) {
            return false
        }

        if (keyCode == KEY_VOLUME_UP) isVolumeUpPressed = false
        if (keyCode == KEY_VOLUME_DOWN) isVolumeDownPressed = false

        // Cancel repeat loop IMMEDIATELY upon release of any volume key
        scheduler.cancel(TOKEN_REPEAT)
        repeatStepsRemaining = 0

        // If the dual-press window is not pending, clear holding key
        if (keyCode == activeHoldingKey && !isDualWindowPending) {
            activeHoldingKey = 0
        }

        // Reset dual trigger session when both buttons are released
        if (!isVolumeUpPressed && !isVolumeDownPressed) {
            isDualTriggerActive = false
        }

        return true
    }

    private fun onDualPressWindowExpired(targetKey: Int) {
        if (!isDualWindowPending || activeHoldingKey != targetKey || isDualTriggerActive) {
            return
        }

        isDualWindowPending = false

        // Execute the first volume step
        actionHandler.adjustVolume(activeDirection)

        // If the button is still held down, initiate the recursive repeat ramp
        if (isKeyCurrentlyPressed(targetKey)) {
            repeatStepsRemaining = maxRepeatSteps
            scheduler.postDelayed(TOKEN_REPEAT, initialRepeatDelayMs) {
                onRepeatTick(targetKey)
            }
        } else {
            activeHoldingKey = 0
        }
    }

    private fun onRepeatTick(targetKey: Int) {
        // Strict guard: verify key is STILL physically pressed and trigger is not active
        if (isDualTriggerActive || activeHoldingKey != targetKey || !isKeyCurrentlyPressed(targetKey) || repeatStepsRemaining <= 0) {
            scheduler.cancel(TOKEN_REPEAT)
            repeatStepsRemaining = 0
            return
        }

        repeatStepsRemaining--
        actionHandler.adjustVolume(activeDirection)

        if (repeatStepsRemaining > 0 && isKeyCurrentlyPressed(targetKey)) {
            scheduler.postDelayed(TOKEN_REPEAT, repeatIntervalMs) {
                onRepeatTick(targetKey)
            }
        } else {
            scheduler.cancel(TOKEN_REPEAT)
            repeatStepsRemaining = 0
        }
    }

    private fun isKeyCurrentlyPressed(keyCode: Int): Boolean {
        return when (keyCode) {
            KEY_VOLUME_UP -> isVolumeUpPressed
            KEY_VOLUME_DOWN -> isVolumeDownPressed
            else -> false
        }
    }

    private fun cancelAllScheduled() {
        scheduler.cancel(TOKEN_DUAL_WINDOW)
        scheduler.cancel(TOKEN_REPEAT)
        isDualWindowPending = false
        repeatStepsRemaining = 0
    }

    fun reset() {
        cancelAllScheduled()
        isVolumeUpPressed = false
        isVolumeDownPressed = false
        isDualTriggerActive = false
        activeHoldingKey = 0
        activeDirection = 0
        repeatStepsRemaining = 0
    }
}
