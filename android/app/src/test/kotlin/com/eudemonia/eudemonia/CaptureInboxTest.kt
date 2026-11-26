package com.eudemonia.eudemonia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class CaptureInboxTest {

    @get:Rule
    val tmp = TemporaryFolder()

    private lateinit var dir: File
    private lateinit var inbox: CaptureInbox

    @Before
    fun setUp() {
        dir = File(tmp.root, "capture_inbox")
        inbox = CaptureInbox(dir)
    }

    private fun writePart(startedAtMs: Long, dataBytes: Int): File {
        val part = inbox.newPartFile(startedAtMs)
        part.writeBytes(ByteArray(WavFileWriter.HEADER_BYTES) + ByteArray(dataBytes) { 3 })
        return part
    }

    @Test
    fun newPartFileIsNamedAfterStartTimeInsideCreatedDirectory() {
        val part = inbox.newPartFile(1700000000123)

        assertEquals(File(dir, "1700000000123.wav.part"), part)
        assertTrue(dir.isDirectory)
    }

    @Test
    fun commitRenamesPartToWavAndReturnsIt() {
        val part = writePart(42, 100)
        val content = part.readBytes()

        val committed = inbox.commit(part)

        assertEquals(File(dir, "42.wav"), committed)
        assertFalse(part.exists())
        assertTrue(content.contentEquals(committed!!.readBytes()))
    }

    @Test
    fun discardDeletesPartFile() {
        val part = writePart(7, 10)

        inbox.discard(part)

        assertFalse(part.exists())
        assertTrue(inbox.listCommitted().isEmpty())
    }

    @Test
    fun listCommittedIsSortedByStartTimeAndIgnoresPartsAndForeignFiles() {
        inbox.commit(writePart(300, 10))
        inbox.commit(writePart(100, 10))
        inbox.commit(writePart(200, 10))
        writePart(50, 10)
        File(dir, "notes.txt").writeText("x")
        File(dir, "abc.wav").writeText("x")

        val listed = inbox.listCommitted()

        assertEquals(listOf(100L, 200L, 300L), listed.map { it.startedAtMs })
        assertEquals(File(dir, "100.wav"), listed.first().file)
    }

    @Test
    fun listCommittedIsEmptyWhenDirectoryIsMissing() {
        assertTrue(inbox.listCommitted().isEmpty())
    }

    @Test
    fun salvageCommitsLongEnoughPartWithRepairedHeaderAndDeletesTooShortOne() {
        val minimum = CaptureInbox.MIN_SALVAGE_DATA_BYTES
        val longPart = writePart(1000, minimum + 2)
        val shortPart = writePart(2000, minimum)

        val salvaged = inbox.salvageStaleParts()

        val committed = File(dir, "1000.wav")
        assertEquals(listOf(committed), salvaged)
        assertFalse(longPart.exists())
        assertFalse(shortPart.exists())
        assertFalse(File(dir, "2000.wav").exists())
        val header = ByteBuffer.wrap(committed.readBytes(), 0, WavFileWriter.HEADER_BYTES)
            .order(ByteOrder.LITTLE_ENDIAN)
        assertEquals(minimum + 2, header.getInt(40))
        assertEquals(listOf(1000L), inbox.listCommitted().map { it.startedAtMs })
    }

    @Test
    fun minimumSalvageLengthIsThreeTenthsOfASecond() {
        assertEquals(9600, CaptureInbox.MIN_SALVAGE_DATA_BYTES)
    }
}
