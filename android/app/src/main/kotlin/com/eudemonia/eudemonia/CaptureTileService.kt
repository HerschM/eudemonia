package com.eudemonia.eudemonia

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log

/**
 * Quick Settings tile "Record": one swipe and one tap from anywhere, including the
 * lock screen. A tap starts or stops a capture through [EudemoniaForegroundService], exactly
 * like the notification button and the home-screen widget; the tile never opens the app.
 */
class CaptureTileService : TileService() {

    companion object {
        private const val TAG = "CaptureTile"

        /** Asks the system to redraw the tile after a capture state change. */
        fun requestRefresh(context: Context) {
            try {
                requestListeningState(context, ComponentName(context, CaptureTileService::class.java))
            } catch (e: Exception) {
                Log.w(TAG, "Unable to refresh the tile: ${e.message}")
            }
        }
    }

    private val listener = object : CaptureListener {
        override fun onStateChanged(state: CaptureState) = render(state)
    }

    override fun onStartListening() {
        super.onStartListening()
        val core = CaptureCore.get(applicationContext)
        core.addListener(listener)
        render(core.state)
    }

    override fun onStopListening() {
        CaptureCore.get(applicationContext).removeListener(listener)
        super.onStopListening()
    }

    override fun onClick() {
        super.onClick()
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            // Only the app can ask for the microphone; nothing can be recorded before that.
            Log.w(TAG, "Microphone permission missing; open the app once to allow it.")
            return
        }
        val tileState = CaptureTileState.from(CaptureCore.get(applicationContext).state)
        val intent = Intent(this, EudemoniaForegroundService::class.java).apply { action = tileState.action }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Unable to reach the capture service from the tile: ${e.message}")
        }
    }

    private fun render(state: CaptureState) {
        val tile = qsTile ?: return
        val tileState = CaptureTileState.from(state)
        tile.state = if (tileState.active) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = tileState.label
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) tile.subtitle = tileState.subtitle
        tile.contentDescription = tileState.label
        tile.updateTile()
    }
}
