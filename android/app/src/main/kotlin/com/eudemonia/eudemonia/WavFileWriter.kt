package com.eudemonia.eudemonia

import java.io.File
import java.io.RandomAccessFile

/**
 * Streams 16 kHz mono PCM16 audio into a WAV file.
 *
 * The 44-byte header is written first with zero sizes and patched by [finish], so a file
 * left behind by a killed process holds valid PCM and can be fixed with [repairHeader].
 * Not thread-safe: one thread writes, and [finish] runs after that thread has stopped.
 */
class WavFileWriter(file: File) {

    companion object {
        const val SAMPLE_RATE = 16000
        const val CHANNELS = 1
        const val BITS_PER_SAMPLE = 16
        const val HEADER_BYTES = 44
        const val BLOCK_ALIGN = CHANNELS * BITS_PER_SAMPLE / 8
        const val BYTE_RATE = SAMPLE_RATE * BLOCK_ALIGN

        fun durationMsForDataBytes(dataBytes: Long): Long = dataBytes * 1000L / BYTE_RATE

        /**
         * Rewrites the header of [file] from its length, dropping a trailing half sample.
         * Returns false when the file is too short to hold a header.
         */
        fun repairHeader(file: File): Boolean {
            val length = file.length()
            if (length < HEADER_BYTES) return false
            val dataBytes = (length - HEADER_BYTES) / BLOCK_ALIGN * BLOCK_ALIGN
            RandomAccessFile(file, "rw").use { raf ->
                raf.setLength(HEADER_BYTES + dataBytes)
                raf.seek(0)
                raf.write(header(dataBytes))
            }
            return true
        }

        private fun header(dataBytes: Long): ByteArray {
            val bytes = ByteArray(HEADER_BYTES)
            fun ascii(offset: Int, tag: String) {
                tag.forEachIndexed { i, c -> bytes[offset + i] = c.code.toByte() }
            }
            fun int32(offset: Int, value: Long) {
                for (i in 0 until 4) bytes[offset + i] = (value shr (8 * i)).toByte()
            }
            fun int16(offset: Int, value: Int) {
                bytes[offset] = value.toByte()
                bytes[offset + 1] = (value shr 8).toByte()
            }
            ascii(0, "RIFF")
            int32(4, 36 + dataBytes)
            ascii(8, "WAVE")
            ascii(12, "fmt ")
            int32(16, 16)
            int16(20, 1) // PCM
            int16(22, CHANNELS)
            int32(24, SAMPLE_RATE.toLong())
            int32(28, BYTE_RATE.toLong())
            int16(32, BLOCK_ALIGN)
            int16(34, BITS_PER_SAMPLE)
            ascii(36, "data")
            int32(40, dataBytes)
            return bytes
        }
    }

    private val raf = RandomAccessFile(file, "rw")

    var dataBytes: Long = 0
        private set

    init {
        try {
            raf.setLength(0)
            raf.write(header(0))
        } catch (e: Exception) {
            raf.close()
            throw e
        }
    }

    fun write(buffer: ByteArray, offset: Int, length: Int) {
        raf.write(buffer, offset, length)
        dataBytes += length
    }

    /** Patches the header sizes, closes the file and returns the number of PCM bytes. */
    fun finish(): Long {
        raf.use {
            it.seek(0)
            it.write(header(dataBytes))
        }
        return dataBytes
    }

    /** Closes the file without patching the header (for a recording that failed to start). */
    fun close() {
        try {
            raf.close()
        } catch (_: Exception) {}
    }
}
