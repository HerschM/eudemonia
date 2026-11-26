package com.eudemonia.eudemonia

import android.app.DownloadManager
import java.io.File

/** Dart's request to fetch one model file. */
data class ModelDownloadRequest(
    val relativePath: String,
    val url: String,
    val sha256: String,
    val sizeBytes: Long,
    val title: String,
    val wifiOnly: Boolean
)

/** One file Dart asks the state of. */
data class ModelFileQuery(val relativePath: String, val sizeBytes: Long)

/**
 * Downloads, verifies and places the on-device model files below [rootDir] (the app's external
 * files dir, where the models are loaded from).
 *
 * A file's identity is its relative path below [rootDir]. DownloadManager writes to
 * `model_downloads/<relativePath>.part`; the file only takes its final name after its length and
 * SHA-256 match, so a file at the final path is never a half or corrupt download. Records live in
 * [store] so a transfer that finished while the app was closed is finalised by the next [reconcile].
 *
 * Every method does disk I/O: call them off the main thread. Hashing runs through
 * [runVerification], outside the lock, so [status] keeps answering while a large file verifies.
 */
class ModelDownloadCoordinator(
    private val rootDir: File,
    private val store: ModelDownloadRecordStore,
    private val transport: ModelDownloadTransport,
    private val freeSpaceBytes: () -> Long,
    private val hasher: (File) -> String,
    private val runVerification: (Runnable) -> Unit,
    private val onChanged: () -> Unit
) {

    companion object {
        const val PARTIAL_DIR = "model_downloads"
        private const val PARTIAL_SUFFIX = ".part"

        /** Left free beyond the file itself so a model download never fills the phone. */
        const val SPACE_HEADROOM_BYTES = 200L * 1024 * 1024

        private val SHA256_HEX = Regex("^[0-9a-fA-F]{64}$")
    }

    private val verifying = mutableSetOf<String>()

    /** Failures with no DownloadManager row behind them; kept until the next download or cancel. */
    private val failures = mutableMapOf<String, String>()

    /** True when a transfer was enqueued or is already active or ready; false when refused. */
    @Synchronized
    fun download(request: ModelDownloadRequest): Boolean {
        val rel = request.relativePath
        val finalFile = finalFileFor(rel)
        require(request.url.isNotBlank()) { "url must not be blank" }
        require(SHA256_HEX.matches(request.sha256)) { "sha256 must be 64 hex characters" }
        require(request.sizeBytes > 0) { "sizeBytes must be positive" }

        failures.remove(rel)
        if (finalFile.isFile && finalFile.length() == request.sizeBytes) return true
        if (rel in verifying) return true
        store.get(rel)?.let { existing ->
            val row = transport.query(existing.downloadId)
            if (row != null && row.status != DownloadManager.STATUS_FAILED) return true
            // Failed, or removed behind our back (e.g. cancelled from the notification): start over.
            transport.remove(existing.downloadId)
            store.remove(rel)
        }

        if (freeSpaceBytes() < request.sizeBytes + SPACE_HEADROOM_BYTES) {
            failures[rel] = ModelFileStateResolver.REASON_INSUFFICIENT_SPACE
            return false
        }

        val partial = partialFileFor(rel)
        // DownloadManager would pick another name rather than overwrite a stale file.
        partial.delete()
        partial.parentFile?.mkdirs()
        val id = transport.enqueue(
            ModelTransferRequest(request.url, partialSubPath(rel), request.title, request.wifiOnly)
        )
        store.put(ModelDownloadRecord(rel, id, request.sha256.lowercase(), request.sizeBytes))
        return true
    }

    /** Stops the transfer, deletes its partial file and forgets it. */
    @Synchronized
    fun cancel(relativePath: String) {
        val partial = partialFileFor(relativePath)
        failures.remove(relativePath)
        store.get(relativePath)?.let { transport.remove(it.downloadId) }
        store.remove(relativePath)
        // A verification still running for it finds no record and discards its result.
        verifying.remove(relativePath)
        partial.delete()
    }

    /** Removes the model file and anything still in flight for it. */
    @Synchronized
    fun delete(relativePath: String) {
        val finalFile = finalFileFor(relativePath)
        cancel(relativePath)
        finalFile.delete()
    }

    /** Starts verification of every finished transfer not already being verified. */
    @Synchronized
    fun reconcile() {
        for (record in store.all()) {
            if (record.relativePath in verifying) continue
            val row = transport.query(record.downloadId) ?: continue
            if (row.status != DownloadManager.STATUS_SUCCESSFUL) continue
            val downloaded = downloadedFileFor(record.relativePath, row) ?: continue
            verifying.add(record.relativePath)
            runVerification(Runnable { verify(record, downloaded) })
        }
    }

    /** The state of each of [files], in the same order, after a [reconcile]. */
    fun status(files: List<ModelFileQuery>): List<ModelFileStatus> {
        files.forEach { finalFileFor(it.relativePath) }
        reconcile()
        synchronized(this) {
            return files.map { query ->
                val rel = query.relativePath
                val finalFile = finalFileFor(rel)
                val record = store.get(rel)
                ModelFileStateResolver.resolve(
                    ModelFileFacts(
                        relativePath = rel,
                        expectedSizeBytes = query.sizeBytes,
                        finalLength = if (finalFile.isFile) finalFile.length() else null,
                        hasRecord = record != null,
                        row = record?.let { transport.query(it.downloadId) },
                        verifying = rel in verifying,
                        rememberedFailure = failures[rel]
                    )
                )
            }
        }
    }

    private enum class Outcome { MATCH, MISMATCH, FILE_ERROR }

    private fun verify(record: ModelDownloadRecord, downloaded: File) {
        val outcome = try {
            when {
                !downloaded.isFile -> Outcome.FILE_ERROR
                downloaded.length() != record.sizeBytes -> Outcome.MISMATCH
                hasher(downloaded).equals(record.sha256, ignoreCase = true) -> Outcome.MATCH
                else -> Outcome.MISMATCH
            }
        } catch (e: Exception) {
            Outcome.FILE_ERROR
        }
        synchronized(this) {
            val rel = record.relativePath
            // Cancelled or replaced while hashing: this result is about a transfer nobody wants.
            if (store.get(rel)?.downloadId != record.downloadId || rel !in verifying) return
            verifying.remove(rel)
            if (outcome == Outcome.MATCH && placeFinal(downloaded, finalFileFor(rel))) {
                failures.remove(rel)
            } else {
                downloaded.delete()
                failures[rel] = if (outcome == Outcome.MISMATCH) {
                    ModelFileStateResolver.REASON_CHECKSUM
                } else {
                    ModelFileStateResolver.REASON_FILE_ERROR
                }
            }
            // The file has been moved or deleted already, so this only drops the system's entry.
            transport.remove(record.downloadId)
            store.remove(rel)
        }
        onChanged()
    }

    private fun placeFinal(downloaded: File, finalFile: File): Boolean {
        finalFile.parentFile?.mkdirs()
        // A same-directory rename is atomic: readers see either no model or the whole verified one.
        if (downloaded.renameTo(finalFile)) return true
        finalFile.delete()
        return downloaded.renameTo(finalFile)
    }

    private fun downloadedFileFor(relativePath: String, row: DownloadRow): File? {
        val expected = partialFileFor(relativePath)
        if (expected.exists()) return expected
        // DownloadManager may have chosen another name; accept it only inside our partial dir.
        val reported = row.localPath?.let(::File) ?: return expected
        val partialRoot = File(rootDir, PARTIAL_DIR).canonicalPath + File.separator
        return if (reported.canonicalPath.startsWith(partialRoot)) reported else expected
    }

    private fun partialSubPath(relativePath: String) = "$PARTIAL_DIR/$relativePath$PARTIAL_SUFFIX"

    private fun partialFileFor(relativePath: String): File {
        finalFileFor(relativePath)
        return File(rootDir, partialSubPath(relativePath))
    }

    /** The final path of [relativePath]; rejects anything that could land outside [rootDir]. */
    private fun finalFileFor(relativePath: String): File {
        val segments = relativePath.split('/')
        require(
            relativePath.isNotEmpty() &&
                !relativePath.startsWith("/") &&
                '\\' !in relativePath &&
                '\u0000' !in relativePath &&
                segments.none { it.isEmpty() || it == "." || it == ".." } &&
                segments.first() != PARTIAL_DIR
        ) { "Invalid model file path: $relativePath" }
        val file = File(rootDir, relativePath)
        require(file.canonicalPath.startsWith(rootDir.canonicalPath + File.separator)) {
            "Model file path escapes the files dir: $relativePath"
        }
        return file
    }
}
