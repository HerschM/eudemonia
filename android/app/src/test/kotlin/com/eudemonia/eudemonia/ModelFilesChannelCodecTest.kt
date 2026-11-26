package com.eudemonia.eudemonia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ModelFilesChannelCodecTest {

    @Test
    fun channelContractConstants() {
        assertEquals("com.eudemonia/model_files", ModelFilesChannelCodec.CHANNEL)
        assertEquals("getDeviceInfo", ModelFilesChannelCodec.METHOD_GET_DEVICE_INFO)
        assertEquals("status", ModelFilesChannelCodec.METHOD_STATUS)
        assertEquals("download", ModelFilesChannelCodec.METHOD_DOWNLOAD)
        assertEquals("cancel", ModelFilesChannelCodec.METHOD_CANCEL)
        assertEquals("delete", ModelFilesChannelCodec.METHOD_DELETE)
        assertEquals("onChanged", ModelFilesChannelCodec.METHOD_ON_CHANGED)
    }

    @Test
    fun decodesQueriesWithIntOrLongSizes() {
        val queries = ModelFilesChannelCodec.decodeQueries(
            mapOf(
                "files" to listOf(
                    mapOf("relativePath" to "a.gguf", "sizeBytes" to 12),
                    mapOf("relativePath" to "b/c.onnx", "sizeBytes" to 3_000_000_000L)
                )
            )
        )

        assertEquals(listOf(ModelFileQuery("a.gguf", 12L), ModelFileQuery("b/c.onnx", 3_000_000_000L)), queries)
    }

    @Test
    fun decodesDownload() {
        val request = ModelFilesChannelCodec.decodeDownload(
            mapOf(
                "relativePath" to "qwen3-4b.gguf",
                "url" to "https://example.org/q.gguf",
                "sha256" to "ab".repeat(32),
                "sizeBytes" to 2_500_000_000L,
                "title" to "Language model",
                "wifiOnly" to false
            )
        )

        assertEquals(
            ModelDownloadRequest(
                "qwen3-4b.gguf", "https://example.org/q.gguf", "ab".repeat(32), 2_500_000_000L, "Language model", false
            ),
            request
        )
    }

    @Test
    fun missingArgumentsAreRejected() {
        assertThrows(IllegalArgumentException::class.java) { ModelFilesChannelCodec.decodeQueries(null) }
        assertThrows(IllegalArgumentException::class.java) {
            ModelFilesChannelCodec.decodeQueries(mapOf("files" to listOf(mapOf("relativePath" to "a"))))
        }
        assertThrows(IllegalArgumentException::class.java) {
            ModelFilesChannelCodec.decodeDownload(mapOf("relativePath" to "a.gguf"))
        }
        assertThrows(IllegalArgumentException::class.java) { ModelFilesChannelCodec.decodeRelativePath(mapOf<String, Any>()) }
    }

    @Test
    fun encodesDeviceInfo() {
        val info = ModelFilesChannelCodec.encodeDeviceInfo(
            totalRamBytes = 7_680L * 1024 * 1024 + 123, freeStorageBytes = 50_000_000_000L
        )

        assertEquals(setOf("totalRamMb", "freeStorageBytes"), info.keys)
        assertEquals("RAM goes to Dart as an int of whole MB", 7_680, info["totalRamMb"] as Int)
        assertEquals(50_000_000_000L, info["freeStorageBytes"] as Long)
    }
}
