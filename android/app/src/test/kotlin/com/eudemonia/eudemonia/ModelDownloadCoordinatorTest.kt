package com.eudemonia.eudemonia

import android.app.DownloadManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.security.MessageDigest

class ModelDownloadCoordinatorTest {

    @get:Rule
    val tmp = TemporaryFolder()

    private class FakeStore : ModelDownloadRecordStore {
        val records = linkedMapOf<String, ModelDownloadRecord>()
        override fun get(relativePath: String) = records[relativePath]
        override fun all() = records.values.toList()
        override fun put(record: ModelDownloadRecord) {
            records[record.relativePath] = record
        }
        override fun remove(relativePath: String) {
            records.remove(relativePath)
        }
    }

    private class FakeTransport : ModelDownloadTransport {
        val enqueued = mutableListOf<ModelTransferRequest>()
        val rows = mutableMapOf<Long, DownloadRow>()
        val removed = mutableListOf<Long>()
        private var nextId = 100L

        override fun enqueue(request: ModelTransferRequest): Long {
            enqueued.add(request)
            val id = nextId++
            rows[id] = DownloadRow(DownloadManager.STATUS_PENDING, 0, 0L, -1L, null)
            return id
        }

        override fun query(downloadId: Long) = rows[downloadId]

        override fun remove(downloadId: Long) {
            removed.add(downloadId)
            rows.remove(downloadId)
        }
    }

    private val content = "model weights".toByteArray()
    private val goodHash =
        MessageDigest.getInstance("SHA-256").digest(content).joinToString("") { "%02x".format(it) }
    private val path = "parakeet/encoder.int8.onnx"

    private lateinit var root: File
    private lateinit var store: FakeStore
    private lateinit var transport: FakeTransport
    private var freeSpace = Long.MAX_VALUE
    private var hashCalls = 0
    private val pendingVerifications = mutableListOf<Runnable>()
    private var runVerificationInline = true
    private var changes = 0
    private lateinit var coordinator: ModelDownloadCoordinator

    @Before
    fun setUp() {
        root = tmp.newFolder("files")
        store = FakeStore()
        transport = FakeTransport()
        val verifier = Sha256Verifier()
        coordinator = ModelDownloadCoordinator(
            rootDir = root,
            store = store,
            transport = transport,
            freeSpaceBytes = { freeSpace },
            hasher = { file -> hashCalls++; verifier.hexDigest(file) },
            runVerification = { task -> if (runVerificationInline) task.run() else pendingVerifications.add(task) },
            onChanged = { changes++ }
        )
    }

    private fun request(relativePath: String = path, sha256: String = goodHash, size: Long = content.size.toLong()) =
        ModelDownloadRequest(relativePath, "https://example.org/$relativePath", sha256, size, "Speech model", wifiOnly = true)

    private fun stateOf(relativePath: String = path, size: Long = content.size.toLong()) =
        coordinator.status(listOf(ModelFileQuery(relativePath, size))).single()

    /** Plays DownloadManager finishing the transfer: the bytes land in the partial file. */
    private fun completeTransfer(bytes: ByteArray = content) {
        val record = store.records.getValue(path)
        File(root, "model_downloads/$path.part").apply { parentFile!!.mkdirs(); writeBytes(bytes) }
        transport.rows[record.downloadId] =
            DownloadRow(DownloadManager.STATUS_SUCCESSFUL, 0, bytes.size.toLong(), bytes.size.toLong(), null)
    }

    @Test
    fun downloadEnqueuesTransferAndPersistsRecord() {
        assertTrue(coordinator.download(request()))

        val sent = transport.enqueued.single()
        assertEquals("https://example.org/$path", sent.url)
        assertEquals("model_downloads/$path.part", sent.destinationSubPath)
        assertEquals("Speech model", sent.title)
        assertTrue(sent.wifiOnly)
        assertEquals(ModelDownloadRecord(path, 100L, goodHash, content.size.toLong()), store.records[path])
        assertEquals(ModelFileStateResolver.STATE_QUEUED, stateOf().state)
    }

    @Test
    fun downloadDeletesStalePartialFileFirst() {
        val stale = File(root, "model_downloads/$path.part").apply { parentFile!!.mkdirs(); writeText("old") }

        coordinator.download(request())

        assertFalse(stale.exists())
    }

    @Test
    fun downloadWhileActiveDoesNotEnqueueAgain() {
        coordinator.download(request())

        assertTrue(coordinator.download(request()))

        assertEquals(1, transport.enqueued.size)
    }

    @Test
    fun downloadOfReadyFileDoesNothing() {
        File(root, path).apply { parentFile!!.mkdirs(); writeBytes(content) }

        assertTrue(coordinator.download(request()))

        assertTrue(transport.enqueued.isEmpty())
    }

    @Test
    fun insufficientSpaceRefusesAndReportsFailure() {
        freeSpace = content.size + ModelDownloadCoordinator.SPACE_HEADROOM_BYTES - 1

        assertFalse(coordinator.download(request()))

        assertTrue(transport.enqueued.isEmpty())
        assertTrue(store.records.isEmpty())
        val state = stateOf()
        assertEquals(ModelFileStateResolver.STATE_FAILED, state.state)
        assertEquals("insufficient_space", state.reason)
    }

    @Test
    fun successfulTransferWithGoodHashBecomesReady() {
        coordinator.download(request())
        completeTransfer()

        val state = stateOf()

        assertEquals(ModelFileStateResolver.STATE_READY, state.state)
        assertTrue(File(root, path).readBytes().contentEquals(content))
        assertFalse(File(root, "model_downloads/$path.part").exists())
        assertTrue(store.records.isEmpty())
        assertEquals(listOf(100L), transport.removed)
        assertEquals(1, changes)
    }

    @Test
    fun badHashDeletesFileAndFailsWithChecksum() {
        coordinator.download(request())
        completeTransfer("tampered bits!".toByteArray().copyOf(content.size))

        val state = stateOf()

        assertEquals(ModelFileStateResolver.STATE_FAILED, state.state)
        assertEquals("checksum", state.reason)
        assertFalse(File(root, path).exists())
        assertFalse(File(root, "model_downloads/$path.part").exists())
        assertTrue(store.records.isEmpty())
        assertEquals(1, changes)
    }

    @Test
    fun wrongLengthFailsWithChecksumWithoutHashing() {
        coordinator.download(request())
        completeTransfer(content + 1)

        assertEquals("checksum", stateOf().reason)
        assertEquals(0, hashCalls)
    }

    @Test
    fun checksumFailureIsClearedByNextDownload() {
        coordinator.download(request())
        completeTransfer(ByteArray(content.size))
        assertEquals("checksum", stateOf().reason)

        assertTrue(coordinator.download(request()))

        assertEquals(ModelFileStateResolver.STATE_QUEUED, stateOf().state)
    }

    @Test
    fun unknownDownloadIdIsCancelled() {
        coordinator.download(request())
        transport.rows.clear()

        val state = stateOf()

        assertEquals(ModelFileStateResolver.STATE_FAILED, state.state)
        assertEquals("cancelled", state.reason)
    }

    @Test
    fun failedTransferIsReplacedOnRetry() {
        coordinator.download(request())
        transport.rows[100L] = DownloadRow(DownloadManager.STATUS_FAILED, 404, 0L, -1L, null)
        assertEquals("http_404", stateOf().reason)

        assertTrue(coordinator.download(request()))

        assertEquals(listOf(100L), transport.removed)
        assertEquals(101L, store.records.getValue(path).downloadId)
    }

    @Test
    fun doubleReconcileVerifiesOnce() {
        runVerificationInline = false
        coordinator.download(request())
        completeTransfer()

        coordinator.reconcile()
        coordinator.reconcile()
        assertEquals(ModelFileStateResolver.STATE_VERIFYING, stateOf().state)

        assertEquals(1, pendingVerifications.size)
        pendingVerifications.removeAt(0).run()
        coordinator.reconcile()

        assertTrue(pendingVerifications.isEmpty())
        assertEquals(1, hashCalls)
        assertEquals(ModelFileStateResolver.STATE_READY, stateOf().state)
    }

    @Test
    fun cancelDuringVerificationDiscardsTheResult() {
        runVerificationInline = false
        coordinator.download(request())
        completeTransfer()
        coordinator.reconcile()

        coordinator.cancel(path)
        pendingVerifications.removeAt(0).run()

        assertFalse(File(root, path).exists())
        assertEquals(ModelFileStateResolver.STATE_ABSENT, stateOf().state)
    }

    @Test
    fun cancelRemovesTransferPartialAndRecord() {
        coordinator.download(request())
        val partial = File(root, "model_downloads/$path.part").apply { parentFile!!.mkdirs(); writeText("half") }

        coordinator.cancel(path)

        assertEquals(listOf(100L), transport.removed)
        assertFalse(partial.exists())
        assertTrue(store.records.isEmpty())
        assertEquals(ModelFileStateResolver.STATE_ABSENT, stateOf().state)
    }

    @Test
    fun deleteRemovesFinalFile() {
        val finalFile = File(root, path).apply { parentFile!!.mkdirs(); writeBytes(content) }
        assertEquals(ModelFileStateResolver.STATE_READY, stateOf().state)

        coordinator.delete(path)

        assertFalse(finalFile.exists())
        assertEquals(ModelFileStateResolver.STATE_ABSENT, stateOf().state)
    }

    @Test
    fun statusKeepsRequestOrder() {
        File(root, "b.gguf").writeBytes(content)

        val states = coordinator.status(
            listOf(ModelFileQuery("a.gguf", content.size.toLong()), ModelFileQuery("b.gguf", content.size.toLong()))
        )

        assertEquals(listOf("a.gguf", "b.gguf"), states.map { it.relativePath })
        assertEquals(listOf("absent", "ready"), states.map { it.state })
    }

    @Test
    fun pathsEscapingTheFilesDirAreRejected() {
        val bad = listOf(
            "../evil.gguf", "/etc/passwd", "a/../../b", "a/./b", "a//b", "", "a\\b",
            "model_downloads/x.gguf", "parakeet/"
        )
        for (relativePath in bad) {
            assertThrows("download $relativePath", IllegalArgumentException::class.java) {
                coordinator.download(request(relativePath = relativePath))
            }
            assertThrows("status $relativePath", IllegalArgumentException::class.java) {
                coordinator.status(listOf(ModelFileQuery(relativePath, 1L)))
            }
            assertThrows("cancel $relativePath", IllegalArgumentException::class.java) {
                coordinator.cancel(relativePath)
            }
            assertThrows("delete $relativePath", IllegalArgumentException::class.java) {
                coordinator.delete(relativePath)
            }
        }
        assertTrue(transport.enqueued.isEmpty())
    }

    @Test
    fun malformedDownloadArgumentsAreRejected() {
        assertThrows(IllegalArgumentException::class.java) { coordinator.download(request(sha256 = "abc")) }
        assertThrows(IllegalArgumentException::class.java) { coordinator.download(request(size = 0L)) }
        assertNull(store.records[path])
    }

    @Test
    fun recordEncodingRoundTrips() {
        val record = ModelDownloadRecord(path, 42L, goodHash, 1_234_567_890_123L)

        assertEquals(record, ModelDownloadRecord.decode(path, record.encode()))
        assertNull(ModelDownloadRecord.decode(path, "garbage"))
        assertNull(ModelDownloadRecord.decode(path, null))
    }
}
