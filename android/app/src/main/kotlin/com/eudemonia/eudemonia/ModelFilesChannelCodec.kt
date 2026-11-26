package com.eudemonia.eudemonia

/** Message shapes of the `com.eudemonia/model_files` method channel. */
object ModelFilesChannelCodec {
    const val CHANNEL = "com.eudemonia/model_files"
    const val METHOD_GET_DEVICE_INFO = "getDeviceInfo"
    const val METHOD_STATUS = "status"
    const val METHOD_DOWNLOAD = "download"
    const val METHOD_CANCEL = "cancel"
    const val METHOD_DELETE = "delete"

    /** Native to Dart, no payload: a transfer completed or a verification finished. */
    const val METHOD_ON_CHANGED = "onChanged"

    private const val BYTES_PER_MB = 1024L * 1024L

    fun decodeQueries(arguments: Any?): List<ModelFileQuery> {
        val files = (arguments as? Map<*, *>)?.get("files") as? List<*>
            ?: throw IllegalArgumentException("files is required")
        return files.map { entry ->
            val map = entry as? Map<*, *> ?: throw IllegalArgumentException("each file must be a map")
            ModelFileQuery(map.string("relativePath"), map.long("sizeBytes"))
        }
    }

    fun decodeDownload(arguments: Any?): ModelDownloadRequest {
        val map = arguments as? Map<*, *> ?: throw IllegalArgumentException("arguments are required")
        return ModelDownloadRequest(
            relativePath = map.string("relativePath"),
            url = map.string("url"),
            sha256 = map.string("sha256"),
            sizeBytes = map.long("sizeBytes"),
            title = map.string("title"),
            wifiOnly = map["wifiOnly"] as? Boolean ?: throw IllegalArgumentException("wifiOnly is required")
        )
    }

    fun decodeRelativePath(arguments: Any?): String =
        (arguments as? Map<*, *>)?.string("relativePath") ?: throw IllegalArgumentException("arguments are required")

    fun encodeDeviceInfo(totalRamBytes: Long, freeStorageBytes: Long): Map<String, Any> =
        mapOf("totalRamMb" to (totalRamBytes / BYTES_PER_MB).toInt(), "freeStorageBytes" to freeStorageBytes)

    private fun Map<*, *>.string(key: String): String =
        this[key] as? String ?: throw IllegalArgumentException("$key is required")

    // Dart ints arrive as Integer when they fit in 32 bits, Long otherwise.
    private fun Map<*, *>.long(key: String): Long =
        (this[key] as? Number)?.toLong() ?: throw IllegalArgumentException("$key is required")
}
