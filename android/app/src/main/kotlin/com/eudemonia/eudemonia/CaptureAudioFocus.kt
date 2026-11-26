package com.eudemonia.eudemonia

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.util.Log

/**
 * Asks other apps to stop playing sound while a thought is recorded, so music from the phone's
 * own speaker is not recorded together with the voice. Players that honour audio focus pause
 * and resume by themselves when the focus is given back.
 */
interface CaptureAudioFocus {
    fun acquire()
    fun release()

    companion object {
        val NONE = object : CaptureAudioFocus {
            override fun acquire() {}
            override fun release() {}
        }
    }
}

/** Transient exclusive focus: others must pause (not just lower their volume) until released. */
class SystemCaptureAudioFocus(context: Context) : CaptureAudioFocus {

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
    private var request: AudioFocusRequest? = null

    // Nothing to react to: the recording never gives way to another app's sound.
    private val listener = AudioManager.OnAudioFocusChangeListener { }

    override fun acquire() {
        val manager = audioManager ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )
                    .setOnAudioFocusChangeListener(listener)
                    .build()
                request = focusRequest
                manager.requestAudioFocus(focusRequest)
            } else {
                @Suppress("DEPRECATION")
                manager.requestAudioFocus(
                    listener,
                    AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE
                )
            }
        } catch (e: Exception) {
            Log.w("CaptureAudioFocus", "Unable to request audio focus: ${e.message}")
        }
    }

    override fun release() {
        val manager = audioManager ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                request?.let { manager.abandonAudioFocusRequest(it) }
                request = null
            } else {
                @Suppress("DEPRECATION")
                manager.abandonAudioFocus(listener)
            }
        } catch (e: Exception) {
            Log.w("CaptureAudioFocus", "Unable to abandon audio focus: ${e.message}")
        }
    }
}
