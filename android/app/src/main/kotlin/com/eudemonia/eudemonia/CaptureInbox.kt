package com.eudemonia.eudemonia

import java.io.File

/** A finished capture waiting in the inbox for Dart to ingest. */
data class CommittedCapture(val file: File, val startedAtMs: Long)

/**
 * The directory finished recordings are handed over through.
 *
 * A recording is written to `<startedAtMs>.wav.part` and renamed to `<startedAtMs>.wav`
 * once complete, so a `.wav` file is always whole. Exactly one writer per file: after
 * [commit] native code never touches the file again; Dart moves it out of the inbox.
 */
class CaptureInbox(private val directory: File) {

    companion object {
        private const val WAV_SUFFIX = ".wav"
        private const val PART_SUFFIX = ".wav.part"
        private val COMMITTED_NAME = Regex("""^(\d+)\.wav$""")

        /** A stale part shorter than this (0.3 s of audio) holds nothing worth keeping. */
        const val MIN_SALVAGE_DATA_BYTES = WavFileWriter.BYTE_RATE * 3 / 10
    }

    fun newPartFile(startedAtMs: Long): File {
        directory.mkdirs()
        return File(directory, "$startedAtMs$PART_SUFFIX")
    }

    /** Atomically renames [part] to its `.wav` name; returns null if the rename failed. */
    fun commit(part: File): File? {
        val target = File(directory, part.name.removeSuffix(PART_SUFFIX) + WAV_SUFFIX)
        return if (part.renameTo(target)) target else null
    }

    fun discard(part: File) {
        part.delete()
    }

    fun listCommitted(): List<CommittedCapture> =
        (directory.listFiles() ?: emptyArray())
            .mapNotNull { file ->
                val startedAtMs = COMMITTED_NAME.matchEntire(file.name)
                    ?.groupValues?.get(1)?.toLongOrNull()
                if (startedAtMs != null && file.isFile) CommittedCapture(file, startedAtMs) else null
            }
            .sortedBy { it.startedAtMs }

    /**
     * Recovers part files left by a process that died mid-recording: keeps those with more
     * than [MIN_SALVAGE_DATA_BYTES] of audio (header repaired, then committed) and deletes
     * the rest. Must only run while nothing is recording. Returns the committed files.
     */
    fun salvageStaleParts(): List<File> {
        val parts = (directory.listFiles() ?: emptyArray()).filter { it.name.endsWith(PART_SUFFIX) }
        val salvaged = mutableListOf<File>()
        for (part in parts) {
            // One unreadable part must not stop the others from being recovered.
            try {
                val dataBytes = part.length() - WavFileWriter.HEADER_BYTES
                if (dataBytes > MIN_SALVAGE_DATA_BYTES && WavFileWriter.repairHeader(part)) {
                    // A failed rename leaves the part for the next salvage rather than losing it.
                    commit(part)?.let { salvaged.add(it) }
                } else {
                    discard(part)
                }
            } catch (_: java.io.IOException) {}
        }
        return salvaged
    }
}
