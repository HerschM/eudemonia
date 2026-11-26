package com.eudemonia.eudemonia

import android.app.DownloadManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ModelFileStateResolverTest {

    private val path = "parakeet/encoder.int8.onnx"
    private val size = 1_000L

    private fun facts(
        finalLength: Long? = null,
        hasRecord: Boolean = false,
        row: DownloadRow? = null,
        verifying: Boolean = false,
        failure: String? = null
    ) = ModelFileFacts(path, size, finalLength, hasRecord, row, verifying, failure)

    private fun row(status: Int, reason: Int = 0, soFar: Long = 0L, total: Long = size) =
        DownloadRow(status, reason, soFar, total, localPath = null)

    @Test
    fun finalFileOfExpectedSizeIsReadyWhateverElseIsKnown() {
        val status = ModelFileStateResolver.resolve(
            facts(finalLength = size, hasRecord = true, row = row(DownloadManager.STATUS_RUNNING), failure = "checksum")
        )

        assertEquals(ModelFileStatus(path, ModelFileStateResolver.STATE_READY, size, size, null), status)
    }

    @Test
    fun finalFileOfWrongSizeIsNotReady() {
        val status = ModelFileStateResolver.resolve(facts(finalLength = size - 1))

        assertEquals(ModelFileStatus(path, ModelFileStateResolver.STATE_ABSENT, 0L, size, null), status)
    }

    @Test
    fun nothingKnownIsAbsent() {
        val status = ModelFileStateResolver.resolve(facts())

        assertEquals(ModelFileStateResolver.STATE_ABSENT, status.state)
        assertEquals(0L, status.downloadedBytes)
        assertEquals(size, status.totalBytes)
        assertNull(status.reason)
    }

    @Test
    fun verifyingWinsOverTheDownloadRow() {
        val status = ModelFileStateResolver.resolve(
            facts(hasRecord = true, row = row(DownloadManager.STATUS_SUCCESSFUL, soFar = size), verifying = true)
        )

        assertEquals(ModelFileStatus(path, ModelFileStateResolver.STATE_VERIFYING, size, size, null), status)
    }

    @Test
    fun successfulRowNotYetPickedUpIsVerifying() {
        val status = ModelFileStateResolver.resolve(
            facts(hasRecord = true, row = row(DownloadManager.STATUS_SUCCESSFUL, soFar = size))
        )

        assertEquals(ModelFileStateResolver.STATE_VERIFYING, status.state)
    }

    @Test
    fun pendingRowIsQueued() {
        val status = ModelFileStateResolver.resolve(
            facts(hasRecord = true, row = row(DownloadManager.STATUS_PENDING, total = -1L))
        )

        assertEquals(ModelFileStatus(path, ModelFileStateResolver.STATE_QUEUED, 0L, size, null), status)
    }

    @Test
    fun runningRowReportsProgress() {
        val status = ModelFileStateResolver.resolve(
            facts(hasRecord = true, row = row(DownloadManager.STATUS_RUNNING, soFar = 400L))
        )

        assertEquals(ModelFileStatus(path, ModelFileStateResolver.STATE_RUNNING, 400L, size, null), status)
    }

    @Test
    fun pausedReasonsAreMapped() {
        val cases = mapOf(
            DownloadManager.PAUSED_QUEUED_FOR_WIFI to "waiting_for_wifi",
            DownloadManager.PAUSED_WAITING_FOR_NETWORK to "waiting_for_network",
            DownloadManager.PAUSED_WAITING_TO_RETRY to "waiting_to_retry",
            DownloadManager.PAUSED_UNKNOWN to "unknown",
            77 to "unknown"
        )
        for ((reason, expected) in cases) {
            val status = ModelFileStateResolver.resolve(
                facts(hasRecord = true, row = row(DownloadManager.STATUS_PAUSED, reason = reason, soFar = 10L))
            )
            assertEquals(ModelFileStateResolver.STATE_PAUSED, status.state)
            assertEquals("reason $reason", expected, status.reason)
            assertEquals(10L, status.downloadedBytes)
        }
    }

    @Test
    fun failedReasonsAreMapped() {
        val cases = mapOf(
            DownloadManager.ERROR_INSUFFICIENT_SPACE to "insufficient_space",
            DownloadManager.ERROR_FILE_ERROR to "file_error",
            DownloadManager.ERROR_DEVICE_NOT_FOUND to "file_error",
            DownloadManager.ERROR_FILE_ALREADY_EXISTS to "file_error",
            404 to "http_404",
            503 to "http_503",
            DownloadManager.ERROR_UNHANDLED_HTTP_CODE to "unknown",
            DownloadManager.ERROR_UNKNOWN to "unknown"
        )
        for ((reason, expected) in cases) {
            val status = ModelFileStateResolver.resolve(
                facts(hasRecord = true, row = row(DownloadManager.STATUS_FAILED, reason = reason))
            )
            assertEquals(ModelFileStateResolver.STATE_FAILED, status.state)
            assertEquals("reason $reason", expected, status.reason)
        }
    }

    @Test
    fun recordUnknownToDownloadManagerIsCancelled() {
        val status = ModelFileStateResolver.resolve(facts(hasRecord = true, row = null))

        assertEquals(ModelFileStatus(path, ModelFileStateResolver.STATE_FAILED, 0L, size, "cancelled"), status)
    }

    @Test
    fun rememberedFailureWithoutRecordIsFailed() {
        val status = ModelFileStateResolver.resolve(facts(failure = "checksum"))

        assertEquals(ModelFileStatus(path, ModelFileStateResolver.STATE_FAILED, 0L, size, "checksum"), status)
    }

    @Test
    fun statusEncodesEveryKey() {
        val map = ModelFileStatus(path, "paused", 5L, size, "waiting_for_wifi").toMap()

        assertEquals(
            mapOf(
                "relativePath" to path,
                "state" to "paused",
                "downloadedBytes" to 5L,
                "totalBytes" to size,
                "reason" to "waiting_for_wifi"
            ),
            map
        )
    }
}
