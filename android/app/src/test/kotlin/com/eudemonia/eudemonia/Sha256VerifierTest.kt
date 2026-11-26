package com.eudemonia.eudemonia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.security.MessageDigest

class Sha256VerifierTest {

    @get:Rule
    val tmp = TemporaryFolder()

    private val verifier = Sha256Verifier()

    @Test
    fun knownVectors() {
        val abc = tmp.newFile("abc").apply { writeText("abc") }
        val empty = tmp.newFile("empty")

        assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", verifier.hexDigest(abc))
        assertEquals("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", verifier.hexDigest(empty))
    }

    @Test
    fun fileLargerThanOneBufferHashesLikeTheWholeContent() {
        val bytes = ByteArray(Sha256Verifier.BUFFER_BYTES * 2 + 12_345) { (it * 31 + 7).toByte() }
        val file = tmp.newFile("big.bin").apply { writeBytes(bytes) }
        val expected = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

        assertEquals(expected, verifier.hexDigest(file))
        assertTrue(verifier.matches(file, expected))
        assertTrue("comparison ignores case", verifier.matches(file, expected.uppercase()))
    }

    @Test
    fun mismatchIsDetected() {
        val file = tmp.newFile("abc").apply { writeText("abd") }

        assertFalse(verifier.matches(file, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"))
    }
}
