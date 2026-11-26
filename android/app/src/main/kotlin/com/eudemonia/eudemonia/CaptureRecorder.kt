package com.eudemonia.eudemonia

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Process
import android.util.Log
import java.io.File

/** Records microphone audio into a WAV file. Implementations never throw to the caller. */
interface AudioCapture {
    /** Starts recording into [target]; false if the microphone could not be started. */
    fun start(target: File): Boolean

    /** Stops recording, finishes the file and returns the recorded duration in ms. */
    fun stop(): Long
}

/** [AudioCapture] on [AudioRecord]: 16 kHz mono PCM16, read on an urgent-audio thread. */
class CaptureRecorder : AudioCapture {

    companion object {
        private const val TAG = "CaptureRecorder"
        private const val JOIN_TIMEOUT_MS = 2000L
    }

    private var record: AudioRecord? = null
    private var writer: WavFileWriter? = null
    private var thread: Thread? = null

    @Volatile
    private var running = false

    // RECORD_AUDIO is checked by every caller before a capture can start; a missing grant
    // surfaces here as an AudioRecord that fails to initialise.
    @SuppressLint("MissingPermission")
    override fun start(target: File): Boolean {
        if (running) return false
        var newRecord: AudioRecord? = null
        var newWriter: WavFileWriter? = null
        try {
            val minBuffer = AudioRecord.getMinBufferSize(
                WavFileWriter.SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            if (minBuffer <= 0) {
                Log.e(TAG, "Unsupported recording format (min buffer $minBuffer)")
                return false
            }
            // At least 100 ms per read so the thread wakes ten times a second.
            val readBytes = maxOf(minBuffer, WavFileWriter.BYTE_RATE / 10)
            newRecord = AudioRecord(
                MediaRecorder.AudioSource.DEFAULT,
                WavFileWriter.SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                readBytes * 2
            )
            if (newRecord.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord failed to initialise")
                newRecord.release()
                return false
            }
            newWriter = WavFileWriter(target)
            newRecord.startRecording()
            if (newRecord.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                Log.e(TAG, "AudioRecord did not enter the recording state")
                newRecord.release()
                newWriter.close()
                return false
            }
            record = newRecord
            writer = newWriter
            running = true
            thread = Thread({ readLoop(newRecord, newWriter, readBytes) }, "EudemoniaCapture").also { it.start() }
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Unable to start recording: ${e.message}")
            running = false
            try {
                newRecord?.release()
            } catch (_: Exception) {}
            newWriter?.close()
            record = null
            writer = null
            return false
        }
    }

    private fun readLoop(source: AudioRecord, sink: WavFileWriter, readBytes: Int) {
        try {
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
        } catch (_: Exception) {}
        val buffer = ByteArray(readBytes)
        try {
            while (running) {
                val read = source.read(buffer, 0, buffer.size)
                if (read > 0) {
                    sink.write(buffer, 0, read)
                } else if (read < 0) {
                    Log.e(TAG, "AudioRecord read failed: $read")
                    break
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Recording thread failed: ${e.message}")
        }
    }

    override fun stop(): Long {
        val activeRecord = record ?: return 0L
        val activeWriter = writer
        running = false
        try {
            activeRecord.stop()
        } catch (e: Exception) {
            Log.w(TAG, "AudioRecord stop failed: ${e.message}")
        }
        try {
            thread?.join(JOIN_TIMEOUT_MS)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        val dataBytes = try {
            activeWriter?.finish() ?: 0L
        } catch (e: Exception) {
            Log.e(TAG, "Unable to finish WAV file: ${e.message}")
            activeWriter?.dataBytes ?: 0L
        }
        try {
            activeRecord.release()
        } catch (_: Exception) {}
        record = null
        writer = null
        thread = null
        return WavFileWriter.durationMsForDataBytes(dataBytes)
    }
}
