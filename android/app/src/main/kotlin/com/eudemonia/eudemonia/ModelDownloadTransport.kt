package com.eudemonia.eudemonia

import android.app.DownloadManager
import android.content.Context
import android.net.Uri

/** One transfer to hand to the system; [destinationSubPath] is relative to the app's external files dir. */
data class ModelTransferRequest(
    val url: String,
    val destinationSubPath: String,
    val title: String,
    val wifiOnly: Boolean
)

/** The part of DownloadManager the model file logic uses. */
interface ModelDownloadTransport {
    fun enqueue(request: ModelTransferRequest): Long

    /** The row for [downloadId], or null when DownloadManager no longer knows it. */
    fun query(downloadId: Long): DownloadRow?

    /** Forgets the transfer and deletes whatever file DownloadManager still has for it. */
    fun remove(downloadId: Long)
}

/**
 * DownloadManager runs the transfer outside our process: it survives the app being closed,
 * resumes after network loss and shows its own notification.
 */
class SystemModelDownloadTransport(private val context: Context) : ModelDownloadTransport {

    companion object {
        private const val DESCRIPTION = "Eudemonia model download"
    }

    private val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

    override fun enqueue(request: ModelTransferRequest): Long {
        val systemRequest = DownloadManager.Request(Uri.parse(request.url))
            .setDestinationInExternalFilesDir(context, null, request.destinationSubPath)
            .setAllowedOverMetered(!request.wifiOnly)
            .setAllowedOverRoaming(false)
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
            .setTitle(request.title)
            .setDescription(DESCRIPTION)
        return manager.enqueue(systemRequest)
    }

    override fun query(downloadId: Long): DownloadRow? =
        manager.query(DownloadManager.Query().setFilterById(downloadId))?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            fun int(column: String) = cursor.getInt(cursor.getColumnIndexOrThrow(column))
            fun long(column: String) = cursor.getLong(cursor.getColumnIndexOrThrow(column))
            val localUri = cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
            DownloadRow(
                status = int(DownloadManager.COLUMN_STATUS),
                reason = int(DownloadManager.COLUMN_REASON),
                bytesSoFar = long(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR),
                totalBytes = long(DownloadManager.COLUMN_TOTAL_SIZE_BYTES),
                localPath = localUri?.let { Uri.parse(it).path }
            )
        }

    override fun remove(downloadId: Long) {
        manager.remove(downloadId)
    }
}
