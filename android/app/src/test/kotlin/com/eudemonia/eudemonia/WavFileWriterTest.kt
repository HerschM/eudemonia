package com.eudemonia.eudemonia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class WavFileWriterTest {

    @get:Rule
    val tmp = TemporaryFolder()

    private fun header(file: File): ByteBuffer =
        ByteBuffer.wrap(file.readBytes(), 0, WavFileWriter.HEADER_BYTES).order(ByteOrder.LITTLE_ENDIAN)

    private fun tag(buffer: ByteBuffer, offset: Int): String =
        String(ByteArray(4) { buffer.get(offset + it) }, Charsets.US_ASCII)

    private fun assertValidHeader(file: File, dataBytes: Int) {
        val h = header(file)
        assertEquals("RIFF", tag(h, 0))
        assertEquals(36 + dataBytes, h.getInt(4))
        assertEquals("WAVE", tag(h, 8))
        assertEquals("fmt ", tag(h, 12))
        assertEquals(16, h.getInt(16))
        assertEquals(1, h.getShort(20).toInt()) // PCM
        assertEquals(1, h.getShort(22).toInt()) // mono
        assertEquals(16000, h.getInt(24))
        assertEquals(32000, h.getInt(28)) // byte rate
        assertEquals(2, h.getShort(32).toInt()) // block align
        assertEquals(16, h.getShort(34).toInt()) // bits per sample
        assertEquals("data", tag(h, 36))
        assertEquals(dataBytes, h.getInt(40))
        assertEquals((WavFileWriter.HEADER_BYTES + dataBytes).toLong(), file.length())
    }

    @Test
    fun newWriterLeavesHeaderPlaceholderWithZeroSizes() {
        val file = tmp.newFile("a.wav")
        val writer = WavFileWriter(file)

        assertEquals(WavFileWriter.HEADER_BYTES.toLong(), file.length())
        assertEquals(0, header(file).getInt(40))
        writer.finish()
    }

    @Test
    fun finishPatchesRiffAndDataSizes() {
        val file = tmp.newFile("b.wav")
        val writer = WavFileWriter(file)
        writer.write(ByteArray(3200) { 1 }, 0, 3200)
        writer.write(ByteArray(10) { 2 }, 0, 4)

        val dataBytes = writer.finish()

        assertEquals(3204L, dataBytes)
        assertValidHeader(file, 3204)
    }

    @Test
    fun durationIsDerivedFromDataBytes() {
        assertEquals(1000L, WavFileWriter.durationMsForDataBytes(32000))
        assertEquals(300L, WavFileWriter.durationMsForDataBytes(9600))
        assertEquals(0L, WavFileWriter.durationMsForDataBytes(0))
    }

    @Test
    fun repairHeaderFixesFileWhoseHeaderWasNeverFinished() {
        val file = tmp.newFile("killed.wav")
        // What a killed process leaves behind: the placeholder header plus raw PCM.
        file.writeBytes(ByteArray(WavFileWriter.HEADER_BYTES) + ByteArray(1000) { 7 })

        assertTrue(WavFileWriter.repairHeader(file))

        assertValidHeader(file, 1000)
    }

    @Test
    fun repairHeaderDropsTrailingHalfSample() {
        val file = tmp.newFile("odd.wav")
        file.writeBytes(ByteArray(WavFileWriter.HEADER_BYTES) + ByteArray(1001))

        assertTrue(WavFileWriter.repairHeader(file))

        assertValidHeader(file, 1000)
    }

    @Test
    fun repairHeaderRejectsFileShorterThanHeader() {
        val file = tmp.newFile("short.wav")
        file.writeBytes(ByteArray(10))

        assertFalse(WavFileWriter.repairHeader(file))
    }
}
