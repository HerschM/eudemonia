# IMPLEMENTATION.md — Eudemonia Deep Technical Reference & Evolution History

> [!NOTE]
> **LIVING BLUEPRINT NOTICE**: This document represents a point-in-time snapshot of the system architecture and its current implementation mechanics. It is **NOT** an immutable dogma or absolute truth set in stone.
>
> **Agent Operating Directive**:
> - Treat this document as a current blueprint, not an unchangeable constraint.
> - When touching any subsystem, **always question it, audit it, and seek to improve it** rather than blindly conforming to past patterns.
> - Whenever you modify, refactor, or evolve a subsystem to meet new requirements, **you must update this document** to ensure the blueprint accurately reflects the latest codebase.

---

## 1. Production Subsystem Architecture & Runtime Mechanics (`lib/` & `android/`)

### A. Hardware Trigger & Native Android Layer (Accessibility Service, Volume Safety & Debouncing)
- **Location**: `android/app/src/main/kotlin/com/eudemonia/eudemonia/`
- **Files**:
  - `ButtonInterceptorService.kt`: Android `AccessibilityService` running in an isolated process (`:interceptor`).
  - `VolumeButtonCoordinator.kt`: State machine managing key events, dual-press windows, and repeating volume steps.
  - `TriggerDebouncer.kt`: Shared thread-safe 500ms cooldown debouncer.
  - `RecordingStateTracker.kt`: Pure Kotlin recording-state mirror used by the interceptor process to pick the start vs stop haptic.
  - `MainActivity.kt`: Flutter activity establishing the `com.eudemonia/hardware_buttons` `MethodChannel`.
- **Mechanics**:
  1. `ButtonInterceptorService` intercepts `KEYCODE_VOLUME_UP` and `KEYCODE_VOLUME_DOWN`.
  2. If only one button is pressed or held, `VolumeButtonCoordinator` dispatches `audioManager.adjustSuggestedStreamVolume(..., FLAG_SHOW_UI)`, transparently preserving system volume changes with smooth repetition (`repeatIntervalMs = 110L`, `initialRepeatDelayMs = 300L`).
  3. When both buttons are depressed within a 50ms window (`dualPressWindowMs = 50L`):
     - An instant native haptic pulse is triggered directly via `Vibrator` / `VibratorManager`: single crisp pulse for start recording (`createOneShot(45)`), and distinct double-pulse completion buzz for stop recording (`createWaveform(longArrayOf(0, 30, 50, 30), -1)`).
     - **Start/stop prediction with authoritative correction**: the haptic must fire before the app process reacts, so `RecordingStateTracker.onTriggerFired()` optimistically predicts the toggle. After every trigger Flutter reports the real outcome (`setRecordingState` → package-scoped `RECORDING_STATE_CHANGED` broadcast → `onAuthoritativeState()`), so a dropped trigger, a denied microphone, or a recording toggled from the notification can never leave the two patterns inverted.
     - An explicit broadcast (`com.eudemonia.eudemonia.HARDWARE_TRIGGER`) is sent with the current device lock state (`isLocked`).
  4. Both `MainActivity` and `EudemoniaForegroundService` listen for the trigger broadcast, pass it through `TriggerDebouncer.shared.tryTrigger()` (cooldown 500ms), and invoke the Flutter method `onHardwareTrigger`.
  5. On the Dart side the trigger is received by `CaptureController` (`lib/features/capture/capture_controller.dart`, see Subsystem C), not by a widget.
  6. The main manifest declares **no `INTERNET` permission** (it exists only in the `debug`/`profile` manifests for Flutter tooling), enforcing the 0-bytes-outbound privacy NFR at the OS level in release builds.

### B. Background Persistence & Permissions (Foreground Keep-Alive & Battery Exemption)
- **Files**:
  - `android/app/src/main/kotlin/com/eudemonia/eudemonia/EudemoniaForegroundService.kt`
  - `lib/features/settings/background_permission_service.dart`
  - `lib/features/settings/settings_screen.dart`
- **Mechanics**:
  1. **Dual Permission Requirement**:
     - *Accessibility Service*: Required for intercepting physical volume hardware keys outside the app and while locked.
     - *Battery Optimization Exemption (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`)*: Required to exempt the application from Android Doze mode and OS background hibernation.
  2. **Foreground Service Keep-Alive**:
     - `EudemoniaForegroundService` runs with `foregroundServiceType="microphone"` and displays a persistent low-priority ongoing notification (`eudemonia_background_channel`).
     - Elevates the app process priority to `FOREGROUND_SERVICE`, preventing the Android Low Memory Killer (LMK) from terminating the background listener.
     - **Runtime permission gate**: a `microphone` foreground service cannot enter the foreground before `RECORD_AUDIO` is granted. `MainActivity.startCaptureServiceOrRequestPermissions()` therefore requests `RECORD_AUDIO` (and `POST_NOTIFICATIONS` on API 33+) while the activity is visible, starts the service only once the microphone is granted (immediately, or from `onRequestPermissionsResult`), and returns `false` otherwise.
     - `EudemoniaForegroundService.isRunning` becomes `true` only after `startForeground()` succeeds; on failure the service stops itself instead of lingering without foreground priority.
  3. **UI Coordination**:
     - `BackgroundPermissionService` queries both permissions simultaneously via `MethodChannel`.
     - `showSimultaneousPermissionModal()` provides an educational bottom sheet guiding the user to grant both requirements in one flow.
     - Standardized status badges: **Enabled** (Green) and **Disabled** (Amber).
  4. **Permanent Lock Screen Notification Banner & Capture Controller (FR10)**:
     - `EudemoniaForegroundService` maintains dynamic interactive notification action buttons:
       - Idle: Displays `[ 🎙️ Record Thought ]` (`ACTION_START_CAPTURE`).
       - Recording: Updates title to `Recording Thought...` and displays `[ ⏹ Stop & Save ]` (`ACTION_STOP_CAPTURE`).
     - `ForegroundServiceCoordinator` coordinates lock screen intents and dispatches triggers via `deliverTrigger(isLocked = true, desiredRecording = true|false)` without requiring phone unlock. The explicit `desiredRecording` argument makes the two actions idempotent: a stale `Stop & Save` can never start a recording.
     - Synchronized bidirectionally with Flutter via `MethodChannel("setRecordingState")`: `CaptureController` reports the authoritative state after every trigger, and `MainActivity.publishRecordingState()` fans it out to the notification and to the interceptor process.

### C. Zero-Latency Audio Queue & Dispatch (FIFO Queue & Non-Blocking Worker)
- **Files**:
  - `lib/features/capture/capture_controller.dart`
  - `lib/features/ai_processing/batch_pipeline_service.dart`
  - `lib/features/ai_processing/audio_recording_service.dart`
  - `lib/features/ai_processing/audio_queue_service.dart`
  - `lib/features/ai_processing/audio_queue_item.dart`
- **Mechanics**:
  0. **Capture Trigger Ownership (`CaptureController`)**:
     - Riverpod `NotifierProvider<CaptureController, bool>` (`captureControllerProvider`, state = is recording) owns the `com.eudemonia/hardware_buttons` `onHardwareTrigger` handler. It is instantiated in `main()` before `runApp`, so triggers are handled regardless of which screen is mounted; `CaptureScreen` only watches it for the listening indicator.
     - The state flips to recording immediately (indicator appears without waiting on the recorder) and is **reverted if `startRecording()` returns `false`** (microphone permission missing or recorder failure), so a failed start is never followed by a phantom "stop".
     - Honors the optional `desiredRecording` argument (explicit notification actions) as a no-op when it already matches, keeps the 500ms Dart-side cooldown, and reports the authoritative state to native via `setRecordingState` after every trigger.
  1. **Decoupled Recording Capture**:
     - `BatchPipelineService.startRecording()` starts microphone capture with 0ms delay and returns whether capture actually began.
     - `BatchPipelineService.stopRecordingAndProcess()` stops audio capture and immediately dispatches the recorded WAV path to `AudioQueueService.enqueue()`. The call completes in **<5ms**, immediately returning control to the UI.
     - `enqueue()` notifies the UI providers **before** the disk write and takes its daily sequence number from an in-memory high-water mark (seeded once per calendar day from `NotesRepository.maxDailySequenceFor()` during hydration), so the capture path performs no database scan.
  2. **FIFO Disk Persistence**:
     - Enqueued items are serialized to `${appDocumentsDir}/queue/queue.json` as `AudioQueueItem` objects.
     - Status progression: `pending` -> `transcribing` -> `categorizing` -> `completed` (or `failed`).
     - Writes are **serialized and atomic** (snapshot → `queue.json.tmp` → `rename`), so overlapping mutations or a process kill can never leave a truncated or interleaved file.
     - **Cold-start hydration & recovery**: `main()` calls `AudioQueueService.resumePendingWork()`, which hydrates the queue and drains it. During hydration, items left in `transcribing`/`categorizing` by a killed process are reset to `pending`, and `completed` items (already persisted as notes) are pruned so the file cannot grow without bound. `enqueue()` awaits hydration first, so a capture arriving during startup can never be overwritten by (or overwrite) the persisted queue.
  3. **Reactive UI State Management**:
     - Count tracking is managed via Riverpod 3 `NotifierProvider<PendingQueueCountNotifier, int>` and `NotifierProvider<FailedQueueCountNotifier, int>`.
     - `onQueueChanged` callbacks update synchronous state notifiers immediately, avoiding dropped stream events.
  4. **Failure Recovery**:
     - If transcription or categorization fails, the item is marked `failed` with an `errorMessage`.
     - `retryFailed()` resets all failed items back to `pending` and restarts processing without blocking incoming thoughts.
     - A thought deleted while it is being processed is dropped silently: the worker re-checks queue membership after each inference step and never saves a note (or marks a failure) for a removed item.

### D. AI Model Lifecycle & Memory Management (Sequential Loading, Inactivity Eviction & <60MB Baseline)
- **Files**:
  - `lib/features/ai_processing/model_lifecycle_manager.dart`
  - `lib/features/ai_processing/model_file_validator.dart`
  - `lib/features/ai_processing/model_load_guard.dart`
  - `lib/features/ai_processing/llm_config.dart`
  - `download_models.sh`
- **Mechanics**:
  1. **Lifecycle State Machine**:
     - Three discrete states: `unloaded` (<60 MB RAM), `loading`, and `ready` (~1.6 GB RAM).
  2. **Sequential Model Loading**:
     - To prevent RAM allocation spikes above physical memory thresholds, `ensureModelsLoaded()` loads models sequentially:
       - Step 1: Sherpa-ONNX Parakeet v3 STT model (~600 MB).
       - Step 2: Qwen-2.5 1.5B GGUF LLM model (~1.0 GB).
     - Concurrent callers share one in-flight load `Future`, ensuring thread-safe idempotency; a load failure is delivered to every caller (never to an unlistened completer).
     - If any step fails, both services are disposed so a half-finished load cannot strand the STT model (~600 MB) in RAM while the state reads `unloaded`.
  3. **Inactivity TTL Eviction**:
     - Default TTL: 3 minutes (`modelInactivityTtl`).
     - Every queue item runs inside `runWithModels()`, which calls `touch()` when the item finishes **whether it succeeded or failed**, restarting the 3-minute timer. (Previously only successful items re-armed the timer, so a failing queue kept ~1.6 GB resident indefinitely.)
     - Upon expiry, `evictModels()` disposes the native C++ handles for both STT and LLM, freeing ~1.6 GB of RAM and restoring baseline memory footprint to <60 MB.
  4. **Eviction Safety (In-Use Leases)**:
     - `runWithModels(task)` holds a lease for the duration of an inference task. `evictModels()` returns `Future<bool>`: `true` once the models are out of RAM; `false` when a lease is active, in which case eviction is deferred and executed the moment the task completes. An eviction requested during loading waits for the load to settle first. Native handles are therefore never freed underneath a running inference (e.g. the Settings `Evict Models Now` button during queue processing).
  5. **Reactive Lifecycle State**:
     - State transitions are published through `onStateChanged` into `modelLifecycleStateProvider` (`NotifierProvider<ModelLifecycleStateNotifier, ModelLifecycleState>`), which the Pipeline HUD and Settings memory telemetry watch, so the displayed footprint follows loads and evictions live.
  6. **Model File Integrity & Crash-Loop Protection**:
     - The native runtimes (ONNX Runtime, llama.cpp) abort the whole process on a malformed file; an uncaught C++ exception cannot be caught from Dart. `_loadModels()` therefore runs two defenses before any native call:
       1. `ModelFileValidator.validate(ModelFiles)`: walks the top-level protobuf fields of each `.onnx` file (a few bytes per field, ~10ms for the 650 MB encoder) and requires them to end exactly at end-of-file, rejecting truncated, spliced, zero-filled and non-model files; checks `tokens.txt` exists and the LLM file starts with the `GGUF` magic. Failures throw `ModelFileException` with a user-readable message naming the file.
       2. `ModelLoadGuard`: writes a marker (`${appDocumentsDir}/model_load_in_progress`) containing the file-set signature (path, size, mtime) before the native load and deletes it in `finally`. A marker that survives means the process died inside the load; the next launch throws `ModelLoadBlockedException` instead of loading the same files again. The block lifts when the files change or on an explicit user retry (`AudioQueueService.retryFailed()` → `allowLoadRetry()`).
     - Either failure marks queue items `failed` with the message shown on the card, so the startup queue resume can never crash-loop the app.
     - `download_models.sh` pins both upstream repositories to a commit, downloads each file to `<name>.part`, verifies its SHA-256 before moving it into place, and re-verifies the copies on the device after `adb push`. It never resumes onto an existing file.
  7. **Proactive Pre-Warming (available, not wired)**:
     - `warmupOnRecordingStart()` is called by `CaptureController` once a recording has actually started (since 2026-11-21), so the speech model loads on the STT worker isolate while the user is speaking and the first thought is not delayed by a cold load. It is fire-and-forget, never awaited by the capture path, and starts the idle countdown itself if no processing follows. It had been disabled after Chronicle #5 when a warmup meant loading two models (~1.6 GB) during capture; with the LLM out of the capture path that reason no longer applies. A future Synthesis LLM load must NOT be attached to this warmup.

### E. Speech-to-Text Pipeline, Language Model Call & Model Residency (Sherpa-ONNX STT, llama.cpp Worker Isolate, Speech/Language Arbiter)
- **Files**:
  - `lib/features/ai_processing/stt_service.dart`
  - `lib/features/ai_processing/stt_engine.dart`
  - `lib/features/ai_processing/llm_service.dart`
  - `lib/features/ai_processing/llama_isolate_engine.dart`
  - `lib/features/ai_processing/model_residency_arbiter.dart`
- **Mechanics**:
  1. **STT Transcription**:
     - Powered by `sherpa_onnx` using an offline recognizer configured with Parakeet CTC/Transducer models.
     - **Dedicated worker isolate**: `STTService` is a message-passing facade over a long-lived `stt-worker` isolate. The synchronous native work (model load, `readWave`, resampling, `decode`) lives in `SherpaSttEngine` (`stt_engine.dart`, behind the `SttEngine` interface) and executes only inside that isolate, which calls `initBindings()` itself. The UI isolate, which also services hardware capture triggers, is never blocked by transcription; the LLM already runs in `llama_cpp_dart`'s own isolate.
     - Requests are processed strictly in order, so `dispose()` issued during a decode frees the recognizer only after that decode returns, then the isolate exits. `initialize()` awaits the previous worker's teardown so two copies of the model are never resident.
     - The engine is injected through a top-level `SttEngineFactory`, which lets host tests exercise the real isolate protocol with a contract-enforcing fake engine.
     - Preserved audio safeguards: automatic linear resampling to 16kHz (`resampleLinear`), 300ms tail-silence padding, `stream.free()` in `finally`, plus an explicit `Audio recording not found` failure when the WAV file is missing.
  2. **Language Model Call (`LLMService` on our own worker isolate; used only by Synthesis, never by capture)** *(rebuilt 2026-11-21, TASK-049)*:
     - `LLMService.generate(prompt, maxOutputTokens)` runs one stateless turn and returns `LlmGeneration` (text, time to first token, total, chunks, `hitOutputCap`). It throws `StateError` (not loaded / a turn already running), `TimeoutException` (`LLMConfig.generationTimeout`, 5 min), `LlmCancelledException` (after `cancelActiveGeneration()`), `LlmEngineStuckException`, and engine errors; partial text is never returned as success. Output is cut at `<|im_end|>` / `<|eot_id|>`.
     - **Engine seam**: `LlmEngine` / `LlmPromptSession` / `LlmPromptCompletion` (in `llm_service.dart`) let tests fake the model. The real engine is [`llama_isolate_engine.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/ai_processing/llama_isolate_engine.dart): one long-lived `llm-worker` isolate owning the package's `Llama` object directly. `llama_cpp_dart`'s own `LlamaParent`/`LlamaScope` are **not used** (they cannot stop or unload during generation, see Chronicle #33).
     - **Worker loop (`runTokenLoop`, pure and unit-tested)**: each prompt starts with `llama.clear()` + `setPrompt` (empty context, no state between turns — AGENTS.md 4.C); the per-turn output cap is counted in the worker (no stop needed); the loop returns to the event loop after every token so a stop message is honoured within one token; exactly one completion message per prompt.
     - **Stop and unload**: timeout and cancel request a stop and wait for the completion up to `stopTimeout` (2 min, because reading a long prompt is one uninterruptible native call); only then, as a last resort, the worker is killed (which does not free native memory). `dispose()` is awaited: the worker frees the model and acknowledges (5 s bound).
     - **`LLMConfig`**: `kvCacheMaxSize` 4096 (context; `nBatch` is raised to the same value because the binding rejects a prompt longer than `nBatch`), `gpuLayers` 99, `greedySampling` true, `generationTimeout` 5 min, `modelLoadTimeout` 180 s, `nPredict` −1.
     - **Measured (Pixel 7a, Qwen2.5-1.5B Q4, TASK-070)**: reading ≈ 50 tokens/s, writing ≈ 9 tokens/s, load ≈ 10 s warm / 76 s cold; full figures in `TASKS.md` TASK-070.
     - **Phone measurement test**: `integration_test/synthesis_llm_eval_test.dart` (run only with `flutter drive ... --keep-app-running`, then rebuild and reinstall the normal APK).
  3. **Model Residency Arbiter ([`model_residency_arbiter.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/ai_processing/model_residency_arbiter.dart))**: the speech model and the language model are never in RAM together and capture always wins. `ModelLifecycleManager` calls `acquireSpeech()` before loading the speech model (this preempts a running synthesis and waits until the language model is unloaded) and `releaseSpeech()` on eviction or failed load; the synthesis runner uses `tryAcquireLanguage(onPreempt)`, refused while speech holds. There is no classifier and no heuristic fallback anywhere (FR5.5).

### F. Local Storage & Isar Persistence (Collections, Schemas & Note Lifecycle)
- **Files**:
  - `lib/features/notes/data/note_model.dart`
  - `lib/features/notes/data/notes_repository.dart`
  - `lib/features/notes/note_model.dart`
  - `lib/core/database/app_database.dart`
- **Mechanics**:
  - Managed with Isar database, via the maintained `isar_community` 3.4.1 fork (`isar_community`, `isar_community_flutter_libs`, `isar_community_generator`). It is API- and file-compatible with Isar 3.1 and ships 16 KB page-aligned Android libraries; the abandoned upstream `isar_flutter_libs 3.1.0+1` bundles a 4 KB-aligned `libisar.so`.
  - **Single Shared Database Instance**: `openAppDatabase()` opens one Isar instance with every collection (`appDatabaseSchemas`: `NoteSchema`, `SynthesisSessionRecordSchema`). `main()` injects it through `appDatabaseProvider`; `notesRepositoryProvider` and `synthesisSessionStoreProvider` both read it. The provider defaults to `null`, which makes repositories fall back to in-memory storage in unit and widget tests.
  - `Note` schema includes `id`, `rawText`, `correctedText`, indexed `folder`, `createdAt`, `originalAudioPath`, `isRead`, `state`, and `failureReason`.
  - **Thought Lifecycle States**: The `ThoughtState` enum (`enqueued`, `processed`, `failed`, `synthesized`) represents the lifecycle progression of captured thoughts, persisted using `@Enumerated(EnumType.name)` in Isar.
  - **Durable Persistence Across Cold Starts**: `isRead`, `state`, and `failureReason` are fully persisted properties within `note_model.g.dart`. Calling `markAsRead(id)` or `saveNote(note)` updates the Isar database directly in a write transaction, guaranteeing that unread/read state and processing metadata survive process kills and phone reboots.
  - **Repository Operations**: `NotesRepository` supports `saveNote`, `getNoteById`, `deleteNote`, `getAllNotes`, `getNotesByFolder`, `searchNotes`, `updateNoteText`, `updateNoteFolder`, `markAsRead`, `getUnreadNotes`, and `maxDailySequenceFor`, with transparent fallback to in-memory storage during isolated unit and widget tests.
  - **Audio Lifecycle on Delete**: `deleteNote(id)` also deletes the note's raw WAV recording (`originalAudioPath`), so deleted thoughts leave no audio behind on device storage.

### G. Production Capture Screen & Thought Card Presentation (`lib/features/capture/presentation/`)
- **Files**:
  - [`lib/features/capture/presentation/capture_screen.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/capture/presentation/capture_screen.dart)
  - [`lib/features/capture/presentation/floating_capture_capsule.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/capture/presentation/floating_capture_capsule.dart)
  - [`lib/features/notes/presentation/thought_card.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/notes/presentation/thought_card.dart)
  - [`lib/features/notes/audio_playback_controller.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/notes/audio_playback_controller.dart)
  - [`lib/features/home/presentation/smooth_processing_indicator.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/home/presentation/smooth_processing_indicator.dart)
- **Mechanics**:
  - **Unified Reactive Feed**: `CaptureScreen` synthesizes the feed by watching both `recentNotesProvider` (persisted notes) and `queueItemsProvider` (in-flight & failed queue items). Newly captured audio enqueues immediately (<5ms) with `ThoughtState.enqueued` (yellow, shimmer, date/time, audio play button), transitioning seamlessly to `ThoughtState.processed` (blue) upon worker completion without requiring an app restart. Rows are built lazily (`ListView.builder`) under per-day headers (`TODAY — DD/MM`, `YESTERDAY — DD/MM`, `DD/MM/YYYY`).
  - **No Categorization on Capture (FR9.1, FR11.2)**: The Capture screen has no folder carousel and no per-folder list screen, and `ThoughtCard` renders no folder badge or category picker. Folders appear only on Synthesis sessions.
  - **ThoughtCard Lifecycle Rendering**:
    - *Enqueued*: Light pastel yellow background (`#FEF3C7`), animated shimmer subtext, active spinner, `⏳ Enqueued` footer badge.
    - *Processed*: Soft blue background (`#DBEAFE`), footer `[ ✎ Edit ]` opening the inline text editor, and raw audio playback.
    - *Failed*: Soft red background (`#FEE2E2`), explicit failure message, 1-tap `Retry` button, and audio playback.
    - *Synthesized*: Soft mint background (`#DCFCE7`) with footer `🧩 Synthesized in #S-NN`, resolved by `CaptureScreen` from `synthesisRepositoryProvider`.
    - Header order is strictly `[# Number]` → `[▶ Play Audio]` → `[• Unread Dot]` → `[🗑️ Delete]`; footer timestamp is `DD/MM  HH:MM AM/PM`.
  - **Compact Dual Dropdown Filters (FR9.2)**: `capture_triage_filter_dropdown` (`All Triage`, `Unread`, `Read`) and `capture_status_filter_dropdown` (`All Statuses`, `Processing`, `Processed`, `Synthesized`, `Failed`) in a `Wrap`, replacing the former chip row. Both filters combine; an empty result reads `No thoughts matching active filters`.
  - **Interactive Floating Capture Trigger (FR9.3)**: `FloatingCaptureCapsule` (pure presentational) floats above the feed: `[ 🎙️ / Press Vol Up + Down to Capture ]`. Tapping calls `CaptureController.handleTrigger()` (the same path as the hardware trigger). While recording it morphs into a stop icon, animated waveform and a live elapsed timer (`00:04 • Tap to Stop`). When the tap finishes a recording, the screen shows `Captured a new note [#0X]` using the sequence number of the item returned by the controller.
  - **Machine Status Lives in the Shell**: The Capture screen carries no pending pill or processing banner; pipeline state is shown by the shell's Pipeline HUD pill (Subsystem I).
  - **Recording Indicator**: `CaptureScreen` watches `captureControllerProvider` (Subsystem C); it does not own the hardware trigger channel.
  - **Dedicated Audio Playback Controller**: Powered by Riverpod 3 `NotifierProvider<AudioPlaybackController, AudioPlaybackState>` over `MethodChannel('com.eudemonia/audio_playback')`. A native playback error (`PlatformException`, e.g. missing file) resets the state instead of showing a card as playing. In Kotlin, `MediaPlayer` plays private audio files via `player.setDataSource(file.absolutePath)` with speech `AudioAttributes` (see Chronicle #12).
  - **Hardware-Accelerated Smooth Progress Indicator**: `SmoothProcessingIndicator` uses a GPU-accelerated `CustomPainter` with an internal `RepaintBoundary` and ticking `AnimationController`, guaranteeing locked 60/120fps sweep fluidity even during heavy CPU-bound background inference.
  - **Unread Thought Status & In-Card Triage**: Unreviewed processed cards feature a subtle electric blue indicator dot (`•`). Tapping the card marks it as read and clears the indicator.
  - **In-Card Failure Presentation**: Failed thoughts render directly as cards with `ThoughtState.failed` (soft red, failure reason, audio playback, 1-tap `[ Retry ]`), eliminating intrusive full-screen error banners.
  - **Ambient Permissions Alert**: Automatically warns the user if Accessibility or Battery Exemption permissions are missing, auto-dismissing via `WidgetsBindingObserver` when granted.
  - **Known Deviation from FR5.2 (Capture-Time Folder Inference)**: The capture LLM turn still returns a folder alongside the cleaned text and stores it on the note as hidden metadata, because `SynthesisRepository.synthesizeRawNotes()` routes thoughts into sessions by that folder. It is never displayed on Capture. Moving classification into the synthesis turn belongs to the Milestone 9 clustering engine (TASK-049); removing it earlier would collapse every session into `Uncategorized`.

### H. Diagnostic Telemetry & Rotating Logging (2MB Capped Log File & Telemetry Dump)
- **Files**:
  - `lib/core/logger/app_logger.dart`
  - `lib/features/settings/settings_screen.dart`
- **Mechanics**:
  - `AppLogger` logs hardware triggers, state transitions, audio queue steps, and exceptions to disk at `${appDocumentsDir}/logs/app_logs.txt`.
  - Enforces a 2MB rotating file cap to prevent unbounded storage consumption.
  - `SettingsScreen` includes interactive actions to view system logs in a live modal, copy a full diagnostic dump to clipboard, or clear logs.

### I. Four-Stage Production Navigation Shell & Mind Pipeline HUD (`lib/features/home/presentation/`)
- **Files**:
  - [`lib/features/home/presentation/main_navigation_shell.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/home/presentation/main_navigation_shell.dart)
  - [`lib/features/home/presentation/pipeline_hud_modal.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/home/presentation/pipeline_hud_modal.dart)
  - [`lib/features/insights/presentation/insights_placeholder_screen.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/insights/presentation/insights_placeholder_screen.dart)
  - [`lib/features/action/presentation/action_placeholder_screen.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/action/presentation/action_placeholder_screen.dart)
- **Mechanics**:
  - **Top Bar**: Minimalist header with branding `Eudemonia`, interactive Mind Pipeline HUD pill (`[ ⚡ X in Pipeline ▾ ]` or `[ 🌿 In Sync ▾ ]`), and Settings gear navigation.
  - **Interactive Mind Pipeline HUD Modal**: Bottom sheet revealing real-time machine pipeline state across stages:
    - *Stage 1 (Capture)*: Shows pending raw audio in queue and processing state.
    - *Stage 2 (Synthesis)*: Shows count of buffered thoughts awaiting clustering with an on-demand `[ ⚡ Synthesize Now ]` trigger button.
    - *Stages 3 & 4 (Insights & Action)*: Indicates synchronicity status.
    - *Memory footer*: the sheet opens immediately and fills in a live OS reading (`describePipelineMemory`): model state, app memory (PSS) and device free/total RAM, or `live memory reading unavailable`. No estimated figures are shown.
  - **Four-Stage Tab Bar & Zero-Suppression**:
    - `Capture (X)`: Zero-suppressed unconsumed thought count ($X = \text{unread processed} + \text{in-flight queue}$). Thoughts already consumed by a synthesis session (`ThoughtState.synthesized`) are excluded, matching the unread dot and `Unread` filter.
    - `Synthesis (Y)`: Zero-suppressed unconsumed session count ($Y = \text{unread clusters}$).
    - `Insights` & `Action`: Visually greyed out (`Opacity(0.38)`) and tap-intercepted to remain unclickable placeholders with friendly explanatory empty states until backend stages are activated.

### J. Production Synthesis Subsystem & Session Clustering (`lib/features/synthesis/`)
- **Files**:
  - [`lib/features/synthesis/domain/synthesis_cluster.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/synthesis/domain/synthesis_cluster.dart)
  - [`lib/features/synthesis/data/synthesis_repository.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/synthesis/data/synthesis_repository.dart)
  - [`lib/features/synthesis/data/synthesis_session_store.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/synthesis/data/synthesis_session_store.dart)
  - [`lib/features/synthesis/data/synthesis_session_record.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/synthesis/data/synthesis_session_record.dart)
  - [`lib/features/synthesis/presentation/synthesis_screen.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/synthesis/presentation/synthesis_screen.dart)
  - [`lib/features/synthesis/presentation/style_rewriter_sheet.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/synthesis/presentation/style_rewriter_sheet.dart)
  - [`lib/features/synthesis/presentation/note_ejection_sheet.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/synthesis/presentation/note_ejection_sheet.dart)
  - [`lib/features/synthesis/presentation/note_merge_sheet.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/synthesis/presentation/note_merge_sheet.dart)
- **Mechanics**:
  - **State Architecture**: `SynthesisRepository` extends Riverpod 3 `Notifier<List<SynthesisCluster>>` exposed via `synthesisRepositoryProvider`.
  - **Durable Sessions (Write-Through Persistence)**:
    - `SynthesisSessionRecord` is an Isar collection (indexed `clusterId`) holding every durable cluster field plus embedded `SynthesisOriginRecord` snapshots of the origin thoughts. `isExpanded` is transient view state and is not stored.
    - `SynthesisSessionStore` wraps the collection (`loadAll`, `put`, `delete`) with an in-memory fallback that stores the same records, so both paths persist identical fields.
    - `SynthesisRepository.build()` returns an empty list and hydrates from the store asynchronously (`hydrated`). Its `state` setter diffs the previous and next lists and writes changed sessions and deletions through to the store in order (`pendingWrites`), so every mutation (create, read, expand, folder, style, merge, eject, delete) is durable without per-method persistence code. `synthesizeRawNotes()` awaits hydration first so new `#S-NN` identifiers never collide with stored ones.
    - **Synthesis engine (since 2026-11-21, TASK-049; pure Dart in `domain/`)**: `session_clock.dart` (45 min idle window, 2 h cap), `folder_definition.dart` (`defaultFolders`: Work, Personal, Journal, Uncategorized, each with a description), `synthesis_prompts.dart` (organise / write / structured-write prompts, `ChatFormat` chatml or llama3, `parseOrganiseReply`, output budgets), `synthesis_model_profile.dart` (`SynthesisModelProfile`: model file, chat format, note style cleanUp/structured, organise batch 5, write limit 700 words, output-length sanity bounds — the single place to swap the model), `synthesis_engine.dart`:
      - `organise()`: new thoughts in time order → time groups → batches ≤ 5; each batch is shown the sessions it could join (existing or formed earlier in the run; note or thoughts cut to 60 words); the reply must give every thought exactly one known folder; an invalid, capped or timed-out reply splits the batch (never the same prompt twice; sampling is greedy); a single thought that still fails is reported failed. A thought joins the session of its folder when `t ≥ start`, `t − start < 2 h`, `t − last ≤ 45 min` (by capture time), else starts a new one.
      - `write()`: all raw thoughts of the session in one turn while ≤ 700 words (note replaced); beyond that with an existing note only the new thoughts are written and appended; otherwise pieces ≤ 700 words joined by a blank line. Each reply is checked (not capped, non-empty, length within the profile's bounds); invalid → split; a single thought failing → the session is not written.
      - No fallback: the engine never assigns a folder or produces note text by code.
    - **Runner ([`application/synthesis_runner.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/synthesis/application/synthesis_runner.dart))**: one run at a time; returns `busy` while recording, while the capture queue has pending items or while the speech model is in use; evicts the speech model, takes the language slot, loads the LLM, organises, then writes session by session and **commits each session only after its write succeeded** (`createSession` / `updateSession`, unread, thoughts → `synthesized`). Thoughts that could not be filed or written stay `processed` and get `Note.synthesisAttempts + 1` (automatic runs skip a thought at 3; manual runs always retry; preemption and engine faults count nothing). Sessions flagged `isReprocessing` (style, merge, eject) are rewritten from their raw thoughts in the same run and the flag cleared; a flagged session without thoughts is removed. Preemption by capture cancels the turn, unloads the LLM, then releases the arbiter; result `preempted`. The LLM is always unloaded before the run returns.
    - **Triggers ([`application/synthesis_trigger_controller.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/synthesis/application/synthesis_trigger_controller.dart), FR11.8)**: started in `main.dart`, notified by the audio queue when a thought is saved. Count trigger (default 3 waiting thoughts) after a 20 s settle delay that restarts on every new thought; quiet trigger (default 15 min without a new thought); `busy` and `preempted` runs are retried after 60 s while thoughts wait. Thresholds live in `application/synthesis_settings.dart` (persisted with `shared_preferences`, edited in Settings). Manual: `presentation/manual_synthesis.dart` `startManualSynthesis()` starts a run without waiting and shows a SnackBar.
    - **Verified on the Pixel 7a 2026-11-21 (Qwen2.5-1.5B)**: automatic run at launch with the screen locked filed and wrote 10 sessions from the user's ≈ 30 waiting thoughts in ≈ 5 min; 4 thoughts failed validation and stayed in Capture; process memory ≈ 2.45 GB during the run and 572 MB after unload.
    - **Not yet implemented**: `appliedStyleId` does not change the write prompt (styles are UI state only); the HUD button is not disabled during a run; no UI for failed thoughts or run progress; folder list in the UI still shows the old names (TASK-048).
  - **Cluster Cards**:
    - Header shows sequence badge (e.g., `#S-01`), folder tag with dropdown reassignment, and unread indicator dot (`•`). New identifiers are derived from the highest existing `#S-NN`, so deleting or merging a session never yields a duplicate.
    - Expandable raw origin notes pill (`X Raw Notes ▾`) displaying constituent thought transcriptions and origin sequence numbers (`#01`, `#02`).
    - Actions: `[ ✨ Style ▾ ]` (Executive, Action-Oriented, Exploratory re-writing), `[ 🔗 Merge ]` (cross-cluster consolidation), and `[ 🗑️ Delete ]`.
    - **Single-Note Ejection Guard**: Single-thought clusters hide the `[ Move Out ]` button to prevent creating empty, orphaned synthesis sessions. In multi-note clusters, `[ Move Out ]` opens `NoteEjectionModal` offering to move the note into an existing cluster or spawn an independent session.
  - **Triage & Folder Filtering**: Compact dual dropdowns (`All Triage`, `Unread`, `Read`) and (`All Folders`, `Work`, `Ideas`, `Todos`, `Journal`, `Uncategorized`) prevent screen real-estate wastage.
  - **Pending Batch Banner**: Prominently shows unprocessed thought buffer count with an instant `[ ⚡ Synthesize Now ]` action.

### K. Production Settings & Advanced Diagnostics (`lib/features/settings/`)
- **Files**:
  - [`lib/features/settings/settings_screen.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/settings/settings_screen.dart)
- **Mechanics**:
  - **Background & Hardware Permissions**: Persistent foreground service keep-alive toggle, battery optimization exemption, and accessibility service controls with simultaneous permission guidance.
  - **Automatic Synthesis Trigger & Batching**: Configurable capture threshold ($X$ thoughts) and session quiet window ($Y$ minutes) plus instant buffer synthesis trigger.
  - **Folder Management & Semantic Manifestos**: Real-time display of folder manifestos (`Work`, `Ideas`, `Todos`, `Journal`) with an interactive dialog to add custom user folders and keyword anchors.
  - **Calendar Synchronization**: Toggle to automatically block out schedule commitments extracted from thoughts.
  - **On-Device AI Memory & Thermal Telemetry (Live OS Readings)**:
    - Files: `lib/features/settings/system_telemetry_service.dart`, `android/app/src/main/kotlin/com/eudemonia/eudemonia/SystemTelemetryCollector.kt`.
    - `SystemTelemetryCollector.snapshot()` (served on `MethodChannel('com.eudemonia/system_telemetry')`, method `getSnapshot`, executed off the UI thread) reports: `PowerManager.currentThermalStatus` (API 29+), `PowerManager.getThermalHeadroom(10)` (API 30+, `NaN` → null), app process memory as total PSS from `Debug.getMemoryInfo`, and device `availMem` / `totalMem` / `lowMemory` from `ActivityManager.MemoryInfo`. A value the OS cannot provide is `null`, never estimated.
    - `SystemTelemetry` derives display values: thermal summary `N% (Status)` where `N = (1 − headroom) × 100` clamped to 0–100 (headroom 1.0 = `THERMAL_STATUS_SEVERE`), `isThermallyThrottled` from Severe upwards, and byte formatting.
    - `SettingsScreen` watches `systemTelemetryProvider` and invalidates it every 5 seconds while open (timer cancelled in `dispose`). Thermal headroom, app memory and device memory show the live values or `Unavailable`; the `[ Evict Models Now ]` button confirms with `AI models evicted from memory.` and the memory row updates from the next reading.
  - **Diagnostic Logging**: Rotating 2MB log inspector modal, one-click clipboard telemetry dump, and log clearing.

---

## 2. UI/UX Component Sandbox Architecture & Contracts (`previews/`)

### A. Isolated Sandbox Architecture & Zero-Boilerplate Guardrail
- **Location**: `previews/`
- **Launcher**: `~/flutter/bin/flutter run -t previews/main_preview.dart -d macos` (or chrome / emulator)
- **Key Files**:
  - `previews/main_preview.dart`: Standalone sandbox entrypoint running without native services or platform channels.
  - `previews/mock_data.dart`: Typed mock datasets for all edge cases across the four maturation stages.
  - `previews/preview_theme.dart`: Design tokens (OLED dark palette, typography, radii, spacing).
  - `previews/gallery_shell.dart`: Stage navigation shell, AI Pipeline HUD, and settings switcher.
  - `previews/screens/`: Dedicated screen prototypes (`capture_screen_preview.dart`, `synthesis_screen_preview.dart`, `insights_screen_preview.dart`, `action_screen_preview.dart`, `settings_preview.dart`, `note_merge_preview.dart`, `note_ejection_preview.dart`).
- **Core Guardrails**:
  1. **Strict Sandbox Isolation**: All exploratory UI/UX design, visual redesigns, mock data experiments, and layout modifications requested by the user **must take place in `previews/`**.
  2. **Zero Production Boilerplate**: Never commit prototype boilerplate, mock datasets, or preview scenario switchers into production code (`lib/`).
  3. **Pure Presentational Widget Contract**: Presentational widgets in `lib/` must remain pure: accept primitive models/values and callback closures. Never make direct calls to native platform channels (`MethodChannel`), local databases (`Isar`), or heavy AI models (`sherpa_onnx`, `llama_cpp_dart`) from presentation widgets.

### B. Mind Pipeline HUD & Navigation Shell (`GalleryShell`)
- **Pipeline HUD Modal**:
  - Global Header features the interactive AI Pipeline Status Pill (`[ ⚡ X in Pipeline ▾ ]` when active / `[ 🌿 In Sync ▾ ]` when idle).
  - Tapping opens the **Pipeline HUD Modal** detailing jobs across all 4 stages:
    - *Capture Stage*: STT audio transcription queue with progress percentage.
    - *Synthesis Stage*: Pending raw thoughts count with manual override button `[ ⚡ Synthesize Now ]`.
    - *Insights Stage*: Periodic background cognitive synthesis countdown (e.g. `"Next refresh in 1 day"`).
    - *Action Stage*: Extracted commitments status and calendar sync state.
- **Human Attention Stage Tabs (Zero-Suppression Badges)**:
  - Tab bar headers display counts strictly for **unconsumed human value** (`Capture (2)`, `Synthesis (1)`, `Insights (1)`, `Action (3)`).
  - **Zero Suppression**: If a stage has 0 unconsumed items, the number is cleanly omitted (e.g., `Capture`, `Synthesis`).
  - Stage switching preserves scroll position and view state.

### C. Four-Stage Screen Mocks & Interactive Component Contracts
1. **Stage 1 — Capture (`CaptureScreenPreview`)**:
   - Raw, uncategorized stream with daily sequence numbering resetting every midnight (`#01`, `#02`...).
   - Status color accents: Yellow for enqueued (`stateEnqueuedBg`), Blue for STT processed (`stateProcessedBg`), Green for synthesized (`stateSynthesizedBg`), and Red for failed (`stateFailedBg`).
   - Compact dual dropdown filters: Triage dropdown (`[ 👁️ All Triage ▾ ]` for `All`, `Unread`, `Read`) and Status dropdown (`[ ⚡ All Statuses ▾ ]` for `All`, `Processing`, `Processed`, `Synthesized`, `Failed`).
   - Strict card header order: `[# Number]` $\rightarrow$ `[▶ Play Audio]` $\rightarrow$ `[• Unread Dot]` $\rightarrow$ `[🗑️ Delete]`.
   - Timestamps formatted as Date then Time: `DD/MM  HH:MM AM/PM` (e.g. `05/11  09:42 AM`).
   - Floating capture capsule: `[ 🎙️ / Press Vol Up + Down to Capture ]` at bottom. Tapping acts as an in-app soft trigger, mutating into an active listening loader/waveform during capture and enqueuing a pending card upon release.
2. **Stage 2 — Synthesis (`SynthesisScreenPreview`)**:
   - Clustered notes (`#S-01`, `#S-02`) with duration metadata (`05/11  07:10 AM - 07:45 AM • ⏱️ 35m session`).
   - Enforces strict **Single-Folder Discipline** (`Work`, `Ideas`, `Todos`, `Journal`, `Uncategorized`).
   - Compact dual dropdown filters: Triage (`[ 👁️ All Triage ▾ ]`) and Folder (`[ 📁 All Folders ▾ ]`).
   - Tri-color maturation states: Yellow (re-synthesizing), Blue (synthesized narrative complete; action pass queued), Green (action pass completed).
   - AI Style Re-Writer modal (`[ ✨ Style ▾ ]`) with 6 preset context prompts (`Concise Executive`, `Bullet Point Actions`, `Stream of Consciousness`, `Technical Specification`, `Personal Reflection`, `Original Transcript`).
   - Expandable origin notes drawer (`[ 🧩 3 Raw Notes Included ▾ ]`) with raw note ejection guard (hidden when `originNotes.length <= 1`).
   - Ejection modal (`note_ejection_preview.dart`) and Explicit Merge modal (`note_merge_preview.dart`).
3. **Stage 3 — Insights (`InsightsScreenPreview`)**:
   - Sub-view switcher: Emotional Climate Heatmap (-1.0 to +1.0 valence with 2-minute Coherence Breathing exercise), Topic Density distribution, and Recurrent Thought Loops.
4. **Stage 4 — Action (`ActionScreenPreview`)**:
   - Commitments todo list with interactive checkboxes, urgency chips (`⚡ High Urgency`), temporal anchors (`05/11  02:00 PM`), and calendar time-block timeline with `[ 📅 Push to Calendar ]`.
5. **Settings Screen (`SettingsPreview`)**:
   - Hardware permissions status badges (Accessibility & Battery exemption), synthesis batching thresholds ($X$ note accumulation count and $Y$ minutes session quiet window) with manual buffer synthesis override, calendar sync controls, RAM telemetry & manual model eviction, and rotating diagnostic log console.

### D. Viewport Hardening (360dp) & Test Double Suite (`test/previews/`)
- Responsive layouts using `Wrap(spacing: ..., runSpacing: ...)` and `SingleChildScrollView(scrollDirection: Axis.horizontal)`.
- Verified with 14 automated unit and widget tests in `test/previews/` running on 360dp narrow viewport constraints with 0 `RenderFlex` overflows and 0 framework assertions.

---

## 3. Chronicle of Historical Issues, Root Causes & Fixes

### 1. Volume Button Runaway & Unhandled Repeats
- **Symptom**: Repeated single clicks or continuous holds of the volume up/down buttons either got consumed without changing volume or entered an uncontrolled runaway volume loop.
- **Root Cause**: The accessibility service consumed all `KeyEvent` actions unconditionally without delegating back to `AudioManager`, and lacked a stateful coordinator to differentiate single presses from long-press repeats.
- **Solution**: Implemented `VolumeButtonCoordinator.kt` with a 50ms dual-press detection window, a 300ms initial repeat delay, and an 110ms repeat interval. Single-key presses call `audioManager.adjustSuggestedStreamVolume(..., FLAG_SHOW_UI)`, and only simultaneous dual-presses trigger the voice capture pipeline.

### 2. Multi-Folder Tagging & Language Correction
- **Symptom**: Notes were frequently categorized as `"Work/Ideas/Todos/Journal"` or default `"Uncategorized"`, and transcripts lacked grammar/filler-word cleanup.
- **Root Cause**: The LLM prompt lacked explicit negative constraints and JSON schema contracts, causing the model to output multi-folder slash lists.
- **Solution**: Implemented `NoteClassifier.dart` using a strict ChatML schema with two distinct phases (Language Correction and Single-Folder Classification). Output is parsed from strict JSON with normalized confidence scores per folder.

### 3. Background Process Hibernation & Simultaneous Permissions
- **Symptom**: After sitting idle in the background for several minutes, the app was terminated by the Android OS and hardware triggers stopped responding.
- **Root Cause**: The app only requested Accessibility Service permissions. Without `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, Android Doze suspended the process. Without a Foreground Service, the app priority was dropped to cached/background.
- **Solution**:
  1. Added `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` and `WAKE_LOCK` to `AndroidManifest.xml`.
  2. Implemented `EudemoniaForegroundService.kt` (`foregroundServiceType="microphone"`) with an ongoing notification.
  3. Created `BackgroundPermissionService.showSimultaneousPermissionModal()` to educate and prompt for both permissions simultaneously.

### 4. UI Layout Overflows & Material Ink Splash Contract Violations
- **Symptom**:
  1. Opening the permission bottom sheet produced a `Right overflowed by 16 pixels` `RenderFlex` error.
  2. Framework assertion: `ListTile background color or ink splashes may be invisible. The ListTile is wrapped in a DecoratedBox...`.
- **Root Cause**:
  1. Title text inside a `Row` lacked an `Expanded` boundary, causing text to overflow on narrow viewports (e.g. 360dp).
  2. `ListTile` was wrapped in a `Container(decoration: BoxDecoration(...))` without a `Material` ancestor, violating Flutter's Material ink splash painting contract.
- **Solution**:
  1. Wrapped row children in `Expanded` and the modal content in `SingleChildScrollView`.
  2. Replaced `Container(decoration: ...)` with `Material(color: ..., shape: ..., child: ListTile(...))`.
  3. Added regression widget tests (`background_permission_ui_test.dart`) running against a 360dp narrow viewport.

### 5. Device Screen Blackouts, OOM Kills & Haptic Latency
- **Symptom**: Triggering recording outside the app caused significant UI stutter, delayed vibration, and occasional device screen blackouts.
- **Root Cause**:
  1. The app attempted to load both heavy AI models (~1.6 GB RAM) concurrently via `Future.wait` inside `startRecording()`, causing a peak memory spike that triggered the Android Low Memory Killer (LMK).
  2. Trigger vibrations were dispatched across the asynchronous Flutter `MethodChannel` instead of executing natively.
- **Solution**:
  1. **Decoupled Queue**: Extracted `AudioQueueService.dart`. Audio recording start/stop is purely non-blocking (<5ms). Heavy model loading is deferred to the sequential background worker.
  2. **Sequential Model Loading**: `ModelLifecycleManager` loads STT first, then LLM second.
  3. **Native Haptics**: Moved vibration directly into `ButtonInterceptorService.kt`, executing instantly upon dual-key confirmation.

### 6. Rogue Background Activity Launches
- **Symptom**: Pressing the trigger outside the app forcibly launched the main activity and brought the app to the foreground.
- **Root Cause**: `ButtonInterceptorService` contained a fallback call to `startActivity(launchIntent)` when intercepting keys.
- **Solution**: Removed `startActivity` completely from the background interceptor process. Triggers are dispatched strictly via explicit broadcast (`HARDWARE_TRIGGER`) to the registered receivers.

### 7. Worker Failure: STT Service Not Initialized & Test Double False Positives
- **Symptom**: Audio was enqueued, but every item immediately failed in the worker with `Exception: STT Service not initialized`.
- **Root Cause**:
  1. When `AudioQueueService` was extracted, `ModelLifecycleManager` was not injected, and `ensureModelsLoaded()` was never called before `_sttService.transcribe()`.
  2. **Why Unit Tests Missed It**: `FakeSTTService` in unit tests unconditionally returned mock text without checking `isInitialized`, creating a false-positive pass while production crashed.
- **Solution**:
  1. Updated `FakeSTTService` and `FakeLLMService` to enforce lifecycle state: throwing `Exception` if invoked before `initialize()`.
  2. Injected `ModelLifecycleManager` into `AudioQueueService`, ensuring `ensureModelsLoaded()` is awaited before calling `_sttService.transcribe()`.

### 8. Disappearing Pending Counts & Broadcast Stream Loss
- **Symptom**: The pending count indicator was stuck at 1 or vanished immediately; completed and failed counts did not reflect accurately in the UI.
- **Root Cause**:
  1. Items failing within ~3ms transitioned immediately to `failed`, dropping the pending count to 0 instantly.
  2. `pendingQueueCountProvider` was backed by `StreamController.broadcast()`, which does not buffer or replay values. Late subscribers (such as `HomeScreen`) received `null`.
- **Solution**:
  1. Replaced broadcast streams with Riverpod 3 `NotifierProvider<PendingQueueCountNotifier, int>` and `NotifierProvider<FailedQueueCountNotifier, int>`.
  2. Added prominent in-body processing and failed retry banners to `HomeScreen`.
  3. Added unit and widget tests verifying state updates across the queue lifecycle.

### 9. Concurrent Queue Execution Race Condition & Retry Completer
- **Symptom**: When retrying failed items or enqueuing rapid successive recordings, `AudioQueueService.processPending()` was triggered concurrently, causing duplicate processing loops and race conditions where item statuses jumped unpredictably.
- **Root Cause**: `AudioQueueService.processPending()` lacked an active processing completer or mutex lock. Multiple asynchronous invocations executed parallel while-loops over the same in-memory list.
- **Solution**:
  1. Implemented `Completer<void>? _processingCompleter` in `AudioQueueService`.
  2. If a processing loop is already active, subsequent calls to `processPending()` or `retryFailed()` simply await `_processingCompleter!.future`, ensuring sequential single-threaded worker passes without duplicative model invocations.

### 10. Feed Optimistic Hydration, Dedicated Audio Playback Architecture & In-Card Triage
- **Symptom**:
  1. Capturing a thought did not display an entry in the feed immediately; thoughts only appeared after a cold restart of the app.
  2. Audio playback button did not play recorded audio.
  3. A global error banner occupied screen real estate instead of displaying failures directly in the entry with a dedicated Failed filter chip.
- **Root Cause**:
  1. `HomeScreen` declared a duplicate `recentNotesProvider` separate from `notes_repository.dart`. When `AudioQueueService` called `ref.invalidate(recentNotesProvider)`, it invalidated the instance in `notes_repository.dart`, leaving `HomeScreen` unaware until restart. Furthermore, `HomeScreen` only watched database notes, ignoring in-flight items in `AudioQueueService`.
  2. `AudioPlaybackController` and `HomeScreen` shared `MethodChannel('com.eudemonia/hardware_buttons')`, where `HomeScreen.initState`'s `setMethodCallHandler` overwrote `AudioPlaybackController`'s message handler. On the Android side, `MediaPlayer.setDataSource(path)` string failed on private app storage due to `mediaserver` process sandbox permissions.
  3. Filter chips inside a single horizontal `Row` overflowed on narrow viewports when the third filter chip was introduced.
- **Solution**:
  1. **Unified Reactive Feed**: `HomeScreen` synthesizes `allThoughts` by watching both `recentNotesProvider` (persisted notes) and `queueItemsProvider` (in-flight & failed queue items). Newly enqueued audio items appear instantly (<5ms) with `ThoughtState.enqueued` (pastel yellow, shimmer, date/time, audio play button). Upon worker completion, the note transitions smoothly to `ThoughtState.processed` (pastel blue) without app restart.
  2. **Dedicated Audio Channel & FileDescriptor**: Extracted `com.eudemonia/audio_playback` with its own platform channel handler. In Kotlin, `MediaPlayer` reads private audio files via `FileInputStream(file).use { fis -> player.setDataSource(fis.fd) }` with speech `AudioAttributes`, ensuring robust audio playback without sandbox permission failures.
  3. **In-Card Failure Presentation & Responsive Failed Chip**: Removed the top error banner. Failed thoughts render directly as cards with `ThoughtState.failed` (soft red, failure reason, audio playback, 1-tap `[ Retry ]`). Placed `Recent Thoughts` heading and an adaptive, horizontally scrollable chip row (`All`, `Unread`, `Failed`) to prevent `RenderFlex` overflows on any device viewport.

### 11. Isar Schema Persistence, True Unread Durability & Complete Note Lifecycle
- **Symptom**:
  1. Marking notes as read appeared to work in-session, but upon restarting the app, all notes reverted to unread state with unread dots (`•`).
  2. Notes could not be deleted from the persistent database (`NotesRepository` lacked `deleteNote`).
- **Root Cause**:
  1. `Note.isRead`, `Note.state`, and `Note.failureReason` were annotated with `@ignore` in `lib/features/notes/data/note_model.dart` to bypass `build_runner`. `NotesRepository` relied on an ephemeral, in-memory `Set<Id> _readNoteIds = {}` that vanished on app restart.
  2. `markAsRead(id)` mutated the in-memory object but did not write to Isar because the field was ignored by the database schema generator.
- **Solution**:
  1. Promoted `isRead`, `@Enumerated(EnumType.name) ThoughtState state`, and `failureReason` to first-class persistent properties in `note_model.dart`.
  2. Regenerated `note_model.g.dart` via `dart run build_runner build --delete-conflicting-outputs`.
  3. Replaced `_readNoteIds` in `NotesRepository` with genuine Isar write transactions (`await _isar!.notes.put(note)`).
  4. Implemented `deleteNote(Id id)` in `NotesRepository` with full unit and widget test coverage.

### 12. Sherpa-ONNX Native Stream Resource Leak & Android MediaPlayer Audio Safety
- **Symptom**:
  1. Potential native memory accumulation during high-volume audio transcription if speech recognition threw an exception.
  2. Audio playback occasionally failed with `MediaPlayer error: what=1, extra=-2147483648` on specific Android devices.
  3. Android build deprecation warnings regarding `Context.VIBRATOR_SERVICE`.
- **Root Cause**:
  1. In `stt_service.dart`, `stream.free()` was called after sequential decoding steps without a `try ... finally` block. If `readWave`, `acceptWaveform`, or `decode` failed, the native C++ stream remained allocated in process memory.
  2. In `MainActivity.kt`, `player.setDataSource(fis.fd)` was executed within `FileInputStream(file).use { ... }`, causing the file descriptor to be closed when the block exited before `MediaPlayer` completed streaming audio.
  3. `getSystemService(Context.VIBRATOR_SERVICE)` was deprecated in Android 12 (API 31).
- **Solution**:
  1. Wrapped `stream.free()` in `try ... finally` in `STTService.transcribe`.
  2. Refactored `MainActivity.kt` to pass `player.setDataSource(file.absolutePath)` directly to `MediaPlayer` with speech `AudioAttributes`.
  3. Updated `MainActivity.kt` to use `VibratorManager` on API 31+ with safe backward-compatible fallbacks, eliminating compiler deprecation warnings.

### 13. Repository-wide Central Logging Unification (`AppLogger`) & 0-Issue Static Analysis Gate
- **Symptom**:
  1. `dart analyze` reported 75 linter issues (`avoid_print`, `prefer_initializing_formals`, `prefer_interpolation_to_compose_strings`, `unnecessary_import`).
  2. Diagnostic logs were scattered across raw `print()` statements, failing to persist to disk for export via the Settings screen.
- **Root Cause**:
  1. AI processing services (`AudioRecordingService`, `STTService`, `LLMService`, `ModelLifecycleManager`, `NoteClassifier`) lacked dependency injection of `AppLogger`, relying on unformatted `print()`.
  2. Constructor parameters used redundant type annotations or non-initializing formals.
- **Solution**:
  1. Injected `AppLogger` across all services via Riverpod providers. Replaced all raw `print()` calls with structured, timestamped `logger.info()`, `logger.warning()`, and `logger.error()`.
  2. Fixed all constructor formals (`this._logger`, `this._maxSizeBytes`, etc.) and string interpolations.
  3. Achieved **0 errors and 0 warnings** across `dart analyze`.

### 14. Folder Navigation Wiring & ThoughtCard Header Standardization
- **Symptom**:
  1. Tapping on folder cards (`Ideas`, `Work`, `Journal`, `Todos`) in `HomeScreen` was a no-op (`onTap: () {}`).
  2. `NoteListScreen` rendered a static placeholder text rather than actual stored notes.
  3. `ThoughtCard` lacked the sequence badge (`#01`, `#02`...) specified in FR9.4 and lacked an inline deletion trigger.
- **Root Cause**:
  1. Folder navigation was prototyped in `previews/` but the production callback in `home_screen.dart` was never wired to `Navigator.push`.
  2. `NoteListScreen` was a static `StatelessWidget` without Riverpod data binding.
- **Solution**:
  1. Converted `NoteListScreen` to a `ConsumerWidget` powered by `notesByFolderProvider(folder)` and integrated `ThoughtCard` list rendering with audio playback, editing, and deletion.
  2. Wired `_buildFolderCard` in `HomeScreen` to navigate to `NoteListScreen`.
  3. Standardized `ThoughtCard` header layout: `[# Number]` -> `[▶ Play Audio]` -> `[• Unread Dot]` -> `[Timestamp]` -> `[Category/State]` -> `[✎ Edit]` -> `[🗑️ Delete]`, with full widget test coverage.

### 13. Dynamic Note Sequence Renumbering on Capture & Filter Toggles
- **Symptom**: When opening the app, note numbers shifted dynamically whenever a new recording was started, when items were queued, or when filters were toggled (e.g. from `All` to `Unread`).
- **Root Cause**: `ThoughtCard` sequence numbers were calculated dynamically in `HomeScreen` and `NoteListScreen` as `displayedNotes.length - index`. Every time the list length changed, all notes were recalculated and renumbered on the fly, violating FR9.4 and FR9.5.
- **Solution**: Added `int? dailySequenceNumber` to `Note` and `int? sequenceNumber` to `AudioQueueItem`. `NotesRepository.saveNote` calculates an immutable daily sequence number per calendar day (resetting at midnight per FR9.4) and preserves gaps on deletion (FR9.5). `AudioQueueService.enqueue` computes the next daily sequence for pending items and carries it through to the persisted note. Existing notes in the database are backfilled chronologically.

### 14. Horizontal Text & Icon Overflow in ThoughtCard on Narrow Viewports
- **Symptom**: An unread note caused a horizontal `RenderFlex` overflow error on 360dp mobile viewports when rendering sequence badge, play audio button, unread dot, timestamp, category pill, edit button, and delete button in a single horizontal row.
- **Root Cause**: All 8 header elements and action controls were crammed into a single unconstrained `Row` exceeding 440dp of horizontal width.
- **Solution**: Restructured `ThoughtCard` layout to strictly match `UX.md` Visual ASCII Wireframe:
  - **Header Row**: `[# Number]` $\rightarrow$ `[▶ Play Audio]` $\rightarrow$ `[• Unread Dot]` $\rightarrow$ `Spacer()` $\rightarrow$ `[🗑️ Delete]`. Maximum width is ~120dp, completely eliminating horizontal crowding.
  - **Footer Row**: `SizedBox(width: double.infinity, child: Wrap(alignment: WrapAlignment.spaceBetween, ...))` hosting `[Timestamp: DD/MM  HH:MM AM/PM]` on the left and `[Status / Edit / Retry]` actions on the right, mathematically guaranteeing 0 `RenderFlex` overflows on any screen width or font scale.

### 15. STT Word Dropping & Permission Latency
- **Symptom**: Despite clear audio recording, STT dropped initial words and chopped the ending of speech (e.g. note #116).
- **Root Cause**:
  1. `AudioRecordingService.checkPermission()` called `Permission.microphone.request()` on every single recording start gesture, causing a 300ms-700ms Android IPC latency window that dropped the user's initial speech.
  2. Parakeet transducer STT lacked audio sample rate validation/resampling for non-16kHz recordings (e.g. 44.1kHz or 48kHz audio was 3x time-compressed).
  3. Transducer subsampling kernels and joiner blank predictor lacked trailing context frames, truncating final words.
- **Solution**:
  1. Updated `AudioRecordingService.checkPermission()` to check `Permission.microphone.status` first, returning immediately with 0ms lag when granted.
  2. Added automatic linear resampling in `STTService.transcribe()` to guarantee 16kHz audio input.
  3. Added 300ms (4800 samples at 16kHz) tail acoustic silence padding in `STTService.transcribe()`, ensuring complete convolution receptive field and token emission.

### 16. Lock Screen Intermittent Recording & Redundant Double Vibration
- **Symptom**: Recording from lock screen or other screens failed intermittently, and volume key presses always produced an identical double-vibration buzz for both start and stop.
- **Root Cause**:
  1. `ButtonInterceptorService.kt` executed `VibrationEffect.createWaveform(longArrayOf(0, 40, 60, 40), -1)` on both start and stop without differentiating state.
  2. When waking `MainActivity` via `autoTrigger`, `MainActivity.kt` called `TriggerDebouncer.shared.tryTrigger()` a second time, dropping the trigger because the foreground service had already activated the 500ms cooldown window.
  3. `MainActivity` lacked `setShowWhenLocked(true)` and `setTurnScreenOn(true)` in Kotlin and `android:showWhenLocked="true"` in `AndroidManifest.xml`, allowing Android keyguard to suppress activity wakeups.
  4. `EudemoniaForegroundService` was never initialized on startup, leaving background microphone recording unprivileged.
- **Solution**:
  1. Tracked pipeline recording state in `ButtonInterceptorService.kt`. Start triggers a crisp single haptic tick (`createOneShot(45)`), while stop triggers a distinct double-pulse completion buzz (`createWaveform(longArrayOf(0, 30, 50, 30), -1)`).
  2. Removed redundant debouncer check in `MainActivity`'s `autoTrigger` branch.
  3. Configured `setShowWhenLocked(true)` and `setTurnScreenOn(true)` in `MainActivity.kt` and `AndroidManifest.xml`.
  4. Auto-started foreground service on app launch.

### 17. Inconsistent Delete Button on Failed Cards
- **Symptom**: Delete button was missing on failed and enqueued thought cards.
- **Root Cause**: `HomeScreen` only passed `onDelete` if `note.id > 0`. Items in the active queue have temporary negative IDs, so `onDelete` was passed as `null`. Additionally, `AudioQueueService` lacked a method to remove items from the queue.
- **Solution**:
  1. Added `removeItemByAudioPath(String audioFilePath)` and `removeItemById(String id)` to `AudioQueueService` with storage persistence and temporary audio file cleanup.
  2. Updated `HomeScreen` to pass `onDelete` uniformly for all notes: deleting persisted notes via `NotesRepository.deleteNote` and queue items via `AudioQueueService.removeItemByAudioPath`.
  3. Placed the delete button in the top-right header row of `ThoughtCard` across all states (enqueued, processed, synthesized, and failed).

### 18. UI Isolate Blocked by Synchronous STT Inference (Capture Latency Violation)
- **Symptom**: While a queued thought was being transcribed, the UI froze and a new dual-volume trigger was only acted on after the decode finished, delaying the start of the next recording by up to seconds.
- **Root Cause**: `STTService.transcribe()` was declared `async` but executed `readWave`, resampling and `OfflineRecognizer.decode` as synchronous FFI calls on the main isolate — the same isolate that receives `onHardwareTrigger`. Model loading (`OfflineRecognizer(config)`) blocked it too.
- **Solution**: Moved all Sherpa-ONNX work into a dedicated worker isolate (`SttEngine` / `SherpaSttEngine` + message-passing `STTService`). Covered by `stt_service_isolate_test.dart`, which asserts the calling isolate keeps ticking during a blocking decode.

### 19. Lost, Stuck & Unbounded Queue Items Across App Restarts
- **Symptom**: (1) After the app was killed mid-processing, the affected thought stayed "pending" forever and was never transcribed. (2) Pending and failed thoughts from a previous session were invisible and unprocessed until the next recording. (3) A capture made during startup could wipe, or be wiped by, the persisted queue. (4) `queue.json` grew with every thought ever captured.
- **Root Cause**:
  1. Items persisted as `transcribing`/`categorizing` were counted as pending but the worker only picks `pending` items.
  2. `audioQueueServiceProvider` was created lazily on the first trigger, and nothing called `processPending()` after hydration.
  3. `_loadFromStorage()` cleared the in-memory list after an `enqueue()` had already appended to it, and unsynchronized `writeAsString` calls could interleave.
  4. `completed` items were never removed.
- **Solution**: Hydration resets interrupted items to `pending` and prunes `completed` ones; `main()` eagerly runs `resumePendingWork()`; `enqueue()` awaits hydration; saves are serialized and atomic (temp file + rename). Covered by `queue_resilience_test.dart`.

### 20. Models Pinned in RAM After Failures, Partial Loads & Unsafe Eviction
- **Symptom**: After a failed item (e.g. silent or corrupt audio) the ~1.6 GB models were never evicted. A failed LLM load left the STT model resident while the state reported `unloaded`. Model load failures surfaced as unhandled asynchronous errors. Tapping `Evict Models Now` during processing freed native handles under a running inference.
- **Root Cause**: `touch()` ran only on the success path while `ensureModelsLoaded()` had already cancelled the inactivity timer; the load `catch` block did not dispose the already-initialized service; the shared `Completer` was completed with an error that had no listener; `evictModels()` had no notion of in-flight work.
- **Solution**: Introduced `runWithModels()` leases (touch in `finally`, deferred eviction), disposal of both services on load failure, and a shared load `Future`. Covered by the `load failure & eviction safety` group in `model_lifecycle_manager_test.dart`.

### 21. Phantom Recording State, Inverted Haptics & Stale Capture Notification
- **Symptom**: If recording failed to start (microphone permission not yet granted), the UI still showed `Listening...` and the next trigger performed a "stop" with nothing to save. Start/stop haptic patterns could become permanently inverted. The lock screen notification did not reflect recordings started with the volume buttons, and `Stop & Save` could start a recording.
- **Root Cause**: `HomeScreen` (a widget) owned the trigger channel and set `isRecording = true` unconditionally; `AudioRecordingService.startRecording()` swallowed failures; `ButtonInterceptorService` toggled a private boolean that the app never corrected; Flutter never called `setRecordingState`; both notification actions sent the same undirected toggle.
- **Solution**: Extracted `CaptureController` (state reverts on failed start, reports authoritative state to native after every trigger, honors `desiredRecording`), added `RecordingStateTracker` + `RECORDING_STATE_CHANGED` broadcast, and removed the unused deferred `playHaptic` channel method. Covered by `capture_controller_test.dart` and `RecordingStateTrackerTest.kt`.

### 22. Foreground Service Start Before Microphone Permission & Daily Sequence Reuse
- **Symptom**: (1) On a fresh install the app started its `microphone` foreground service at launch, before `RECORD_AUDIO` was granted; on Android 14+ `startForeground()` throws, the exception was swallowed, and a service started via `startForegroundService()` that never reaches the foreground is terminated by the OS. The microphone prompt itself was only ever requested from the first trigger, which cannot display a dialog from a pocket or lock screen. (2) Deleting the newest thought of the day caused the next capture to reuse its number; every `enqueue()` scanned the full notes table on the capture path.
- **Root Cause**: (1) No runtime-permission gate in front of the service start, and `isRunning` was set before `startForeground()`. (2) Sequence numbers were recomputed as `max(existing) + 1` from a full `getAllNotes()` read.
- **Solution**: (1) `MainActivity.startCaptureServiceOrRequestPermissions()` + `onRequestPermissionsResult`; the service reports running only after entering the foreground. (2) In-memory per-day high-water mark seeded from `NotesRepository.maxDailySequenceFor()`.

### 23. Synthesis Sessions Lost on Restart, Leaving Thoughts Permanently Orphaned
- **Symptom**: After restarting the app the Synthesis tab was empty, while the thoughts that had been clustered stayed green ("synthesized") in Capture and could never be clustered again.
- **Root Cause**: `SynthesisRepository` kept sessions only in Riverpod memory, but `synthesizeRawNotes()` persisted `ThoughtState.synthesized` on every origin note in Isar. The two halves of one operation had different lifetimes.
- **Solution**: Added the `SynthesisSessionRecord` collection, `SynthesisSessionStore`, write-through persistence in the repository's `state` setter, a single shared Isar instance (`app_database.dart`), and a one-time repair that returns orphaned thoughts to `processed`. Covered by `synthesis_persistence_test.dart`.

### 24. Capture Screen Diverged from the Four-Stage Specification
- **Symptom**: The production Capture tab still showed the legacy `Folders` carousel with per-folder list screens, a folder picker on every card, a chip filter row, a duplicate pending pill and processing banner, and had no in-app capture trigger.
- **Root Cause**: The four-stage shell was promoted around the pre-existing `HomeScreen` instead of promoting the approved `previews/screens/capture_screen_preview.dart` design; the legacy widget tests kept the old layout pinned.
- **Solution**: Replaced `HomeScreen` and `NoteListScreen` with `CaptureScreen` + `FloatingCaptureCapsule` per FR9/FR11.2 and UX.md §5, removed folder UI from `ThoughtCard`, and migrated the affected widget tests to the new contracts (cold-start queue visibility is now asserted on the shell's pipeline pill).

### 25. Fabricated Thermal and Memory Figures in Production UI
- **Symptom**: Settings always displayed `84% (Nominal)` thermal headroom and `~1.58 GB` / `<60 MB` RAM regardless of the device; the Pipeline HUD and eviction confirmation repeated the same constants.
- **Root Cause**: Mock values from the settings preview were copied into `lib/` as string literals.
- **Solution**: Added `SystemTelemetryCollector` (Kotlin) and `SystemTelemetryService` (Dart) and replaced every literal with live OS readings or `Unavailable`. Covered by `system_telemetry_test.dart`.

### 26. App Crash Loop on Launch from a Corrupt Speech Model File
- **Symptom**: The app aborted within ~10 seconds of every launch: `terminating due to uncaught exception of type Ort::Exception: Load model from .../parakeet/encoder.int8.onnx failed:Protobuf parsing failed`.
- **Root Cause**:
  1. The encoder on the device was not a valid ONNX file. Its size matched the published file but its SHA-256 did not; it had been rewritten that day by `download_models.sh`, which resumed downloads with `wget -c` and verified nothing, while the upstream repository had moved to a newer revision (the decoder and joiner were also from the older revision).
  2. ONNX Runtime reports a malformed model by throwing a C++ exception through the C API, which terminates the process and cannot be caught in Dart.
  3. The queue resume at startup (Chronicle #19) retried the same load on every launch, turning one bad file into a crash loop.
- **Solution**: `ModelFileValidator` + `ModelLoadGuard` in front of every native load (Subsystem D.6), and a rewritten `download_models.sh` with pinned revisions and checksum verification. The validator was confirmed to reject the actual corrupt encoder; the fixed build was run on the affected Pixel 7a, where models loaded and a queued recording was processed. Covered by `model_load_safety_test.dart`.

### 27. Android "This app isn't 16 KB compatible" Warning
- **Symptom**: On launch, Android showed an App Compatibility dialog listing native libraries as not 16 KB aligned.
- **Root Cause**: Inspecting the APK with `llvm-readelf` showed every arm64 library had 16 KB (or 64 KB) `LOAD` alignment and correct zip alignment except `libisar.so` from `isar_flutter_libs 3.1.0+1`, which was linked for 4 KB pages.
- **Solution**: Migrated to `isar_community 3.4.1` and regenerated the schemas. All 16 arm64 libraries in the rebuilt APK are 16 KB aligned, the existing on-device database opened unchanged, and the dialog no longer appears.

### 28. LLM Turns Always Timing Out into the Heuristic Fallback (31s per Thought, Broken Timeout)
- **Symptom**: On a Pixel 7a a ~40-word thought took 31.6s of LLM time and produced only the keyword-heuristic result; the queue stayed blocked far longer than the 25s timeout.
- **Root Cause**:
  1. The prompt asked for `confidence_scores` and `reasoning`, so ~95 of 148 generated tokens were never used, and its ~11s evaluation is repeated every turn because the KV cache is purged per FR5.6.
  2. The 25s timeout did not stop generation: `clearKvCache()` → `disposeScope()` waited for the model to run to `maxOutputTokens`, and the buffer captured at the timeout was truncated JSON.
  3. Assumed but refuted by measurement: GPU (Vulkan) offload was suspected of being the slow path; it is in fact ~6–8x faster than CPU on this device.
- **Solution**: Two-key folder-first prompt, `LlamaParent.stop()` on timeout, 60s configurable timeout, greedy sampling, per-turn metrics, and an on-device benchmark. Result: 14.5s with a real LLM reply. Benchmark tables are under TASK-062.
- **Process Incident**: The first benchmark was run with `flutter test integration_test/... -d <device>`, which uninstalled the app from the user's phone and deleted its notes, recordings and model files. The app and models were restored; the notes were not recoverable. Benchmarks now go through `flutter drive --keep-app-running`.

### 29. "Speech model file is missing" After Reinstall (Model Folder Unreadable to the App)
- **Symptom**: After reinstalling, every capture failed with `Speech model file encoder.int8.onnx is missing` although `download_models.sh` had pushed and checksum-verified the files.
- **Root Cause**: Folders created by `adb` under `/sdcard/Android/data/<pkg>/files` are owned by the shell user with mode `drwxrws---`. The reinstalled app (new UID) could not enter `parakeet/`, and `File.exists()` returns false on a permission error, so `ModelFileValidator` reported "missing". (`run-as` cannot read that path either, so it is not a valid probe.) Unexplained: the same ownership worked two days earlier.
- **Solution**: `download_models.sh` and `tool/push_voice_samples.sh` run `adb shell chmod -R a+rwX` on what they push. Fallback if it recurs: store models in app-private storage.

### 30. First LLM Load After Install Fails with `Operation "model loading" timed out`
- **Symptom**: The first thought after an install fell back or failed while the model was still loading.
- **Root Cause**: `llama_cpp_dart` hard-codes a 60s limit on the load command; a cold first load on the Pixel 7a exceeds it, but the load itself continues.
- **Solution**: `LLMService.initialize()` catches that `TimeoutException` and polls `LlamaParent.status` until `ready`, up to `LLMConfig.modelLoadTimeout` (180s), disposing the parent on `error`/`disposed`/overall timeout.

### 31. Voice Evaluation Harness Findings on Real Speech (Open, TASK-062 / TASK-066)
- **What exists**: `integration_test/voice_pipeline_eval_test.dart` runs the real `STTService` and `LLMService` over `integration_test/voice_samples/` (synthetic clips in git; the user's recordings git-ignored under `real/`) and reports WER, cleanup fidelity (`integration_test/support/text_eval.dart`), timings and app PSS. Run only with `flutter drive --keep-app-running`, then rebuild and reinstall the normal APK.
- **Open defects it exposed (2026-11-20, Pixel 7a; details and work list in `TASKS.md` TASK-066)**: the cleanup prompt rewrites and condenses instead of only cleaning; thoughts above ~180 words fall back (256-token output limit, and ~290 words fails immediately); STT runs at about real time once the LLM is loaded (0.1–0.2x expected); app PSS peaks at 5.0 GB in a debug build against the documented ~1.6 GB; capture-time folder choice over-uses `Ideas`.
- **Not yet true in Section 1**: the memory figures and STT latency stated there are unverified against these measurements and must be corrected once the investigation concludes.

### 32. LLM Removed from the Capture Path (Product Decision After Real-Voice Evaluation)
- **Evidence (Pixel 7a, the user's 22 recordings)**: with the LLM in the capture path the cleanup step dropped clauses, went telegraphic and invented words (`11 AM`, a false causal link); added 7–26s per thought; failed outright above ~180 words (256-token reply cap, 2048-token context); slowed speech recognition to about real time once loaded; and pushed app PSS to 5.0 GB (debug build). It corrected none of the recognition errors. Parakeet already emits punctuation and capitalization.
- **Decision (user, 2026-11-21)**: Capture shows the transcript as spoken, fillers and misspoken words included, as a fact check; no LLM at capture. The LLM runs only in Synthesis. `PRODUCT_SPEC.md` FR5.2 amended accordingly.
- **Code**: `AudioQueueService` saves `correctedText = rawText` and no folder; `ModelLifecycleManager` manages the speech model only, and a missing/corrupt GGUF no longer blocks capture. `AudioQueueStatus.categorizing` is legacy (read from stored queues only).
- **Consequences**: per-thought latency is STT time; Sections 1.D/1.E memory and latency figures for the two-model capture path are obsolete and must be re-measured; KV-prefix caching for capture is dropped (FR5.6 stays as written); the long-input problem moves to the Synthesis design (context size, output budget scaled to input, map-reduce over a session).
- **Reference finding**: Whisper large-v3 on a Mac transcribed every clip Parakeet int8 got wrong from the same audio, so remaining capture errors are recognition-model errors, not audio capture errors.

### 33. Language Model Could Not Be Stopped or Unloaded Mid-Generation (Output Leaking Between Turns, Memory Never Freed)
- **Symptom**: after a turn hit its output cap, text from it appeared in later turns (TASK-070 run 3); the first end-to-end synthesis run on the phone failed with "Stop command timed out, forcing state reset" → `LlmEngineStuckException`; after "disposed" the process stayed at ≈ 2.6–2.9 GB (and 1.5 GB was left after unloading Llama 3.2 3B).
- **Root Cause**: `llama_cpp_dart` 0.2.2's child isolate consumes an `async*` generator around the synchronous FFI token call and never returns to its event loop, so stop, free-slot and dispose messages are only read when the model ends by itself. With `nPredict = -1` and a cap enforced by "stop", every capped turn kept generating.
- **Solution**: own worker isolate on the package's `Llama` class (`llama_isolate_engine.dart`): cap counted in the worker, event-loop yield after every token, awaited unload. Verified on the Pixel 7a: a full run completes and memory returns to 572 MB after unload.
- **Remaining limit**: reading the prompt is one native call and cannot be interrupted (tens of seconds for a long prompt), so a recording that preempts a run may wait that long for its transcript; feeding the prompt in smaller batches would remove this and the `nBatch = nCtx` memory cost (TASK-071).

---

## 4. Architectural Decisions & Target Engineering Blueprints

### A. Four-Stage Cognitive Maturation Architecture Rationale
- **Context & Motivation**: The legacy single-feed UI placed category-folder pills horizontally across the top, forcing immediate categorization and cluttering rapid raw voice capture. Furthermore, users needed a clear maturation lifecycle from disjoint raw walk captures to synthesised clusters, emotional/topic insights, and calendar/todo action items.
- **Architectural Shift**: Transitioned from immediate category tagging to a four-stage cognitive transformation pipeline:
  $$\mathbf{Capture} \longrightarrow \mathbf{Synthesis} \longrightarrow \mathbf{Insights} \longrightarrow \mathbf{Action}$$
- **Key Principles**:
  1. *Capture is Zero-Friction*: Raw voice capture must never require picking folders, adding tags, or reviewing text immediately.
  2. *Separation of Human Attention from Machine Compute*: Top navigation tabs show counts strictly for unconsumed human value (new unread notes, new synthesized clusters), while machine processing status is housed in the persistent top AI Pipeline HUD (`[ ⚡ X in Pipeline ▾ ]`).
  3. *Single-Folder Discipline*: High-level cognitive separation occurs across disciplined domains (`Work`, `Ideas`, `Todos`, `Journal`), avoiding open-ended tag sprawl.

### B. Deep Synthesis Backend Mechanics: Active Session Horizon, Delta Processing & Semantic Manifestos (Milestone 9 Active Blueprint)
> [!NOTE]
> **TARGET ARCHITECTURE (Milestone 9 — In-Scope Active, TASK-048 through TASK-051)**:
> The following mechanics represent the approved engineering design for upcoming implementation. They are not yet wired into `lib/features/`.
> Upon completion and verification of Milestone 9 tasks, their concrete production files and runtime mechanics will be promoted to Section 1 under a dedicated subsystem heading (`### I. Deep Synthesis Clustering & Folder Manifestos`).

> [!IMPORTANT]
> **APPROVED REVISION (user, 2026-11-21) — supersedes items 1, 2 and 4 below wherever they conflict. Built 2026-11-21 (TASK-049) except folder management (TASK-048) and action extraction (TASK-050); the runtime description is Section 1.J / 1.E.** One change to the text below, made on TASK-070 evidence: for a session too long to rewrite, the LLM "existing note + new thoughts" update is replaced by writing only the new thoughts and appending them. Reached after the LLM left the capture path (Chronicle #32) and two rounds of discussion; the first orchestrator proposal (per-thought labelling, code-only grouping, staged condensing with a per-thought cache, keyword fallback) was rejected by the user and must not be revived.
> - **Capture carries nothing but audio and transcript.** No folder, no hidden tagging, no classifier state. `Note.folder`, `AudioQueueItem.folder`, `AudioQueueStatus.categorizing`, `NoteClassifier` (prompt, JSON parser, `fallbackClassify`) and the classify path in `LLMService` are leftovers of the old flow and are removed (TASK-069). `Note.correctedText` stays: it is the displayed, user-editable text of a thought (`rawText` is the recognizer output), not a duplicate.
> - **Session definition (user's words)**: a session is temporal, for one subject. One folder = one subject (single-level folders). A session starts at the capture time of the first thought filed to that folder, stays open while thoughts keep arriving within the rolling 45 min idle window, and closes at the 2 h cap. Same folder within an open window = same session.
> - **A synthesis run has two kinds of LLM turn, kept separate** (a small model sorts and writes less reliably in one reply):
>   1. *Organise* — one turn that sees all new thoughts together plus the folder and current note of every session still open, and assigns exactly one folder to each new thought. The LLM makes the judgement; code only (a) works out from the clock which sessions are open and (b) validates the reply (every thought has exactly one valid folder) and reruns the turn if not.
>   2. *Write* — one turn per affected session.
> - **Adding thoughts to a session (size-based rule, to be confirmed by measurement)**: while the session's raw thoughts fit the context window, the note is rewritten from the raw thoughts (no drift, no over-weighting of the newest thought). Once a session outgrows the window, the turn receives the existing note plus the new thoughts and is told to keep everything the new thoughts do not change. No staged condensing and no stored per-thought condensed text.
> - **Wording churn (raised by both user and orchestrator)**: a rewrite can change wording the user already read. An open session is therefore presented as a live draft and marked unread when it changes; after it closes the note changes only on an explicit user action (merge, move out, style).
> - **A session exists only once both turns have succeeded (user, 2026-11-21).** Nothing appears on the Synthesis screen for thoughts whose organise and write turns have not both completed; until then the thoughts simply remain unsynthesized in Capture (the Pipeline HUD may show that work is waiting). Every session shown therefore has an LLM-assigned folder and an LLM-written note. An existing session being rewritten keeps its previous note and shows Yellow until the new note is ready.
> - **No fallback, anywhere.** A turn either yields a valid LLM result or nothing is created/changed and the run is retried a bounded number of times. No keyword classifier, no heuristic text. `Uncategorized` may remain only as a folder the LLM itself chooses when nothing fits (to confirm with the user when the folder list is fixed).
> - **Context window**: much larger than today's 2048 now that only one model is resident. Orchestrator estimate from the model architecture, unverified: ~30 KB of memory per token of window (8,000 tokens ≈ 250 MB). The real limits are reading time, battery and how well a small model uses long input; all three are measured (TASK-070). A larger LLM is now physically possible on the Pixel 7a but is a separate decision (licence check, TASK-065).
> - **Model exclusivity**: the LLM gets its own lifecycle owner (the speech `ModelLifecycleManager` stays speech-only) and an arbiter guarantees the two models are never resident together. Capture has priority: recording is never blocked; a pending transcription makes the synthesis run yield after its current turn, the LLM is evicted, speech runs, synthesis resumes. The recording-start warmup is deferred while the LLM is resident.
> - **Schema**: `Note.folder` removed (TASK-069, done). Retry bookkeeping for a failed run is to be designed in TASK-049b; it must not create a visible session.
> - **Prompt work** is iterated on the Mac with the same GGUF (`/opt/homebrew/bin/llama-cli`, `models/qwen2.5-1.5b.gguf`); speed and memory are measured only on the phone.
> - **Order**: TASK-069 capture cleanup → TASK-070 measurement and prompts → TASK-049 (049a session clock, 049b organise/write engine, arbiter, automatic triggers per FR11.8) → TASK-048 folder descriptions and custom folders → TASK-050 actions → TASK-041/042/051 remaining UI.
> - **Parked for later (user, 2026-11-21)**: two subjects inside one folder (e.g. App 1 and App 2 under Work). The user's intent is a separate folder per subject, single level, to avoid nested-folder complexity; tags (roadmap: Many-to-Many Secondary Tagging) may help but are not thought through. Revisit after real synthesis output exists.

1. **Active Session Horizon & 2D Domain-Bounded Clustering**:
   - **2D Routing (`Temporal Window ∩ Target Folder`)**: Raw notes captured within an active temporal session are strictly segregated by target folder domain. If a user dictates a technical development note and a personal emotional journal note within the same 45-minute window, the engine separates them into their respective domain-specific active clusters (`#S-01` Work vs `#S-02` Journal), preventing narrative cross-contamination.
   - **Sliding Inactivity Window ($Y=45$m)**: The session remains open and receptive to incoming notes until 45 minutes of quiet elapse in that domain.
   - **Hard Session Ceiling ($T_{max}=2$ hours)**: Prevents runaway infinite clusters across full-day captures by automatically capping the cluster at 2 hours from its first note (`09:00 AM – 11:00 AM • ⏱️ 2h session`), cleanly starting subsequent notes in a fresh cluster.
   - **Delta Synthesis**: When new notes arrive for an active cluster, an additive synthesis pass integrates them into the existing narrative with low token cost (<300 tokens) rather than re-running the full cluster context from scratch.
2. **Delta Action Extraction & State Immutability**:
   - **Action Immutability**: Existing action items stored in Isar have persistent IDs and completed states (`isCompleted = true`). They are never deleted or modified when a cluster receives new notes.
   - **Additive Delta Pass**: When a cluster is updated, the LLM prompt receives the current action list alongside the new note delta, extracting strictly *new* tasks and preventing duplicate creation or state resets.
3. **Explicit Cross-Session Note Merging (`[ 🔗 Merge With Note... ]`)**:
   - Manual user-initiated consolidation across synthesis clusters. The target cluster absorbs origin raw notes, the source cluster is deleted, and the target cluster transitions to Yellow (`stateEnqueuedBg` / `isReprocessing = true`) for consolidated re-synthesis.
4. **Semantic Folder Manifestos & Custom Folder Management**:
   - Folders maintain a persistent `FolderManifesto` record: `id`, `name`, `description` (user-defined or AI-generated semantic manifesto detailing keywords, apps, projects, and entities), `autoGeneratedSummary` (AI-maintained digest of recently filed keywords and themes), and `lastUpdated`.
   - Settings Screen hosts a dedicated **Folder Management & Semantic Manifestos** section where users can view existing folders, edit descriptions, and add new custom folders (e.g., `Eudemonia`, `Personal Health`, `Client CRM`).
   - Dynamic Evolution: After every 5 notes filed into a folder, a low-priority background task refreshes `autoGeneratedSummary` with dominant keywords and entities.
   - Prompt Injection: Injects folder manifestos into Stage 1 classification and Stage 2 clustering prompts, allowing the local LLM to accurately categorize abrupt, context-dependent voice notes.
5. **Future Scope / Non-Goals for V1**:
   - **AI-Assisted Topical Merge Suggestions**: Zero-LLM entity and keyword set-intersection matching across the last 48 hours to display proactive suggestion pills without LLM compute overhead.
   - **User Persona & Custom Prompt Editing**: Formally excluded for V1 to guarantee strict JSON output compliance, prevent mobile token/KV-cache overflow, and avoid breaking backend parsers.

### C. Capture-Independent Three-Part Runtime Architecture (Approved Direction, Not Yet Implemented — TASK-063 & TASK-064)
> [!NOTE]
> **TARGET ARCHITECTURE**: Chosen by the user on 2026-11-19 as the long-term answer to the foreground service launching the activity. Nothing in this section is in `lib/` or `android/` yet. Promote to Section 1 as each phase lands.

- **Problem Being Solved**: The Flutter engine is owned by `MainActivity`. When the activity is destroyed (swiped from recents, reclaimed by the OS) while `EudemoniaForegroundService` keeps the process alive, no Dart code exists to record. `deliverTrigger()` then calls `startActivity()`, which (1) pulls the app over whatever the user is doing, contradicting Scenario 2 and the "No Rogue Launches" invariant, (2) loses the first seconds of speech during cold start, and (3) may be blocked by Android's background-activity-start restrictions, leaving a haptic with no recording. Separately, because capture, UI and inference share one process, a native abort in a model library (Chronicle #26) takes capture down with it.
- **Decision**: Split the runtime into three parts with independent lifetimes.
  1. **Native capture core (Kotlin, in the foreground service)**: owns the microphone, haptics, notification and the capture hand-off end to end. A trigger becomes a WAV file on disk with no Flutter involvement. The only always-on part.
  2. **Inference in its own process**: started when work exists, killed when idle. Process death is the guaranteed way back to the memory baseline, and a native crash kills only this worker.
  3. **Flutter as UI only**: reads the database and renders; opening or closing the app does not affect capture or processing.
- **Alternatives Rejected**:
  - *Keep launching the activity*: the status quo and its three defects.
  - *Service-owned Flutter engine (activity attaches to a cached engine)*: least new code and removes the launch, but keeps everything in one process, so it would not have contained the corrupt-model crash, and capture still depends on Dart being responsive.
  - *Notify instead of recording*: loses the thought.
- **Phasing**: Phase 1 = native capture core (TASK-063): self-contained and fixes the user-facing problem. Phase 2 = inference process (TASK-064): hosted either by a headless Flutter engine running the existing Dart pipeline (cheaper) or by the native sherpa-onnx / llama.cpp APIs directly (removes Flutter from background work); decide after TASK-062 fixes the runtime settings.
- **Constraints to Honor**: the hand-off between processes is files plus the database (a capture inbox directory), with exactly one writer per file; the inference process must be started by the foreground service (Android background-start limits); FR3 queue semantics, FR9.4/FR9.5 sequence numbering and the <5ms capture budget are unchanged contracts.
