package com.eudemonia.eudemonia

import java.io.File
import java.security.MessageDigest

/** Streams a file through SHA-256; a multi-GB model takes seconds, so never call it on the main thread. */
class Sha256Verifier {

    companion object {
        const val BUFFER_BYTES = 1024 * 1024
    }

    /** Lower-case hex SHA-256 of [file]. */
    fun hexDigest(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val buffer = ByteArray(BUFFER_BYTES)
        file.inputStream().use { input ->
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    fun matches(file: File, expectedHex: String): Boolean = hexDigest(file).equals(expectedHex, ignoreCase = true)
}
