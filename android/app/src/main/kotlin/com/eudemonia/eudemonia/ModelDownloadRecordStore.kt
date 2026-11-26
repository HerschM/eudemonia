package com.eudemonia.eudemonia

import android.content.Context
import android.content.SharedPreferences

/** A model file transfer handed to DownloadManager and not yet finalised. */
data class ModelDownloadRecord(
    val relativePath: String,
    val downloadId: Long,
    val sha256: String,
    val sizeBytes: Long
) {
    fun encode(): String = "$downloadId|$sha256|$sizeBytes"

    companion object {
        fun decode(relativePath: String, encoded: String?): ModelDownloadRecord? {
            val parts = encoded?.split('|') ?: return null
            if (parts.size != 3) return null
            val id = parts[0].toLongOrNull() ?: return null
            val size = parts[2].toLongOrNull() ?: return null
            return ModelDownloadRecord(relativePath, id, parts[1], size)
        }
    }
}

/** Keeps transfer records across process death, keyed by relative path. */
interface ModelDownloadRecordStore {
    fun get(relativePath: String): ModelDownloadRecord?
    fun all(): List<ModelDownloadRecord>
    fun put(record: ModelDownloadRecord)
    fun remove(relativePath: String)
}

class SharedPreferencesModelDownloadRecordStore(context: Context) : ModelDownloadRecordStore {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("eudemonia_model_downloads", Context.MODE_PRIVATE)

    override fun get(relativePath: String) = ModelDownloadRecord.decode(relativePath, prefs.getString(relativePath, null))

    override fun all(): List<ModelDownloadRecord> =
        prefs.all.mapNotNull { (key, value) -> ModelDownloadRecord.decode(key, value as? String) }

    // commit, not apply: callers run off the main thread and the id must survive a kill right after.
    override fun put(record: ModelDownloadRecord) {
        prefs.edit().putString(record.relativePath, record.encode()).commit()
    }

    override fun remove(relativePath: String) {
        prefs.edit().remove(relativePath).commit()
    }
}
