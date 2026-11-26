package com.eudemonia.eudemonia

import android.app.DownloadManager

/** One DownloadManager row as the model file logic sees it; status and reason are DownloadManager's codes. */
data class DownloadRow(
    val status: Int,
    val reason: Int,
    val bytesSoFar: Long,
    /** -1 until the server has announced the length. */
    val totalBytes: Long,
    /** Where DownloadManager says it wrote the file, when it says so. */
    val localPath: String?
)

/** Everything known about one model file at the moment its state is asked for. */
data class ModelFileFacts(
    val relativePath: String,
    val expectedSizeBytes: Long,
    /** Length of the file at its final path, or null when there is none. */
    val finalLength: Long?,
    val hasRecord: Boolean,
    /** The record's DownloadManager row, or null when DownloadManager no longer knows the id. */
    val row: DownloadRow?,
    val verifying: Boolean,
    val rememberedFailure: String?
)

/** The state of one model file as sent to Dart on `com.eudemonia/model_files`. */
data class ModelFileStatus(
    val relativePath: String,
    val state: String,
    val downloadedBytes: Long,
    val totalBytes: Long,
    val reason: String?
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "relativePath" to relativePath,
        "state" to state,
        "downloadedBytes" to downloadedBytes,
        "totalBytes" to totalBytes,
        "reason" to reason
    )
}

/**
 * Turns what is on disk, in our records and in DownloadManager into one model file state.
 *
 * A file only ever gets its final name after its checksum matched, so a final file of the
 * expected length is ready whatever else is known (a developer-pushed file counts too).
 */
object ModelFileStateResolver {
    const val STATE_ABSENT = "absent"
    const val STATE_QUEUED = "queued"
    const val STATE_RUNNING = "running"
    const val STATE_PAUSED = "paused"
    const val STATE_VERIFYING = "verifying"
    const val STATE_READY = "ready"
    const val STATE_FAILED = "failed"

    const val REASON_WAITING_FOR_WIFI = "waiting_for_wifi"
    const val REASON_WAITING_FOR_NETWORK = "waiting_for_network"
    const val REASON_WAITING_TO_RETRY = "waiting_to_retry"
    const val REASON_UNKNOWN = "unknown"
    const val REASON_CHECKSUM = "checksum"
    const val REASON_INSUFFICIENT_SPACE = "insufficient_space"
    const val REASON_FILE_ERROR = "file_error"
    const val REASON_CANCELLED = "cancelled"
    const val HTTP_REASON_PREFIX = "http_"

    fun resolve(facts: ModelFileFacts): ModelFileStatus {
        val size = facts.expectedSizeBytes
        fun status(state: String, downloaded: Long = 0L, total: Long = size, reason: String? = null) =
            ModelFileStatus(facts.relativePath, state, downloaded, total, reason)

        if (facts.finalLength == size) return status(STATE_READY, size)
        if (facts.verifying) return status(STATE_VERIFYING, size)
        if (facts.hasRecord) {
            val row = facts.row ?: return status(STATE_FAILED, reason = REASON_CANCELLED)
            val downloaded = row.bytesSoFar.coerceAtLeast(0L)
            val total = if (row.totalBytes > 0L) row.totalBytes else size
            return when (row.status) {
                DownloadManager.STATUS_PENDING -> status(STATE_QUEUED, downloaded, total)
                DownloadManager.STATUS_RUNNING -> status(STATE_RUNNING, downloaded, total)
                DownloadManager.STATUS_PAUSED -> status(STATE_PAUSED, downloaded, total, pausedReason(row.reason))
                // Transferred but not yet picked up for verification; reconcile is about to.
                DownloadManager.STATUS_SUCCESSFUL -> status(STATE_VERIFYING, size)
                DownloadManager.STATUS_FAILED -> status(STATE_FAILED, downloaded, total, failedReason(row.reason))
                else -> status(STATE_QUEUED, downloaded, total)
            }
        }
        facts.rememberedFailure?.let { return status(STATE_FAILED, reason = it) }
        return status(STATE_ABSENT)
    }

    private fun pausedReason(reason: Int): String = when (reason) {
        DownloadManager.PAUSED_QUEUED_FOR_WIFI -> REASON_WAITING_FOR_WIFI
        DownloadManager.PAUSED_WAITING_FOR_NETWORK -> REASON_WAITING_FOR_NETWORK
        DownloadManager.PAUSED_WAITING_TO_RETRY -> REASON_WAITING_TO_RETRY
        else -> REASON_UNKNOWN
    }

    // DownloadManager reports an HTTP failure as the bare status code.
    private fun failedReason(reason: Int): String = when (reason) {
        in 100..599 -> HTTP_REASON_PREFIX + reason
        DownloadManager.ERROR_INSUFFICIENT_SPACE -> REASON_INSUFFICIENT_SPACE
        DownloadManager.ERROR_FILE_ERROR,
        DownloadManager.ERROR_DEVICE_NOT_FOUND,
        DownloadManager.ERROR_FILE_ALREADY_EXISTS -> REASON_FILE_ERROR
        else -> REASON_UNKNOWN
    }
}
