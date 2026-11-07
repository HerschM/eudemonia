# TASKS_archive.md — Eudemonia Completed Task History & Archive

> **Purpose**: This archive preserves the completed engineering tasks, verification records, and test breakdowns for Milestones 1 through 7 of the Eudemonia project.
> 
> **Active Task Backlog**: For active and pending development tasks, refer to [TASKS.md](./TASKS.md).
> 
> **Context Optimization**: AI agents should **not** load this full archive into the active context window. Consult this file only when auditing historical test coverage or verifying completed milestones. Use heading anchors or line-range reads when inspecting past tasks.

---

## Completed Tasks Summary
- **Milestone 1**: TASK-001 through TASK-006 (Hardware Trigger & Native Android Layer)
- **Milestone 2**: TASK-007 through TASK-010 (Background Reliability & Permissions)
- **Milestone 3**: TASK-011 through TASK-015 (Decoupled FIFO Queue & Zero-Latency Capture)
- **Milestone 4**: TASK-016 through TASK-022 (On-Device AI Models & Memory Management)
- **Milestone 5**: TASK-023 through TASK-028 (Persistence, UI Observability & Diagnostics)
- **Milestone 6**: TASK-047 (Four-Stage Screen Mockups & Interactive Preview Sandbox)
- **Milestone 7**: TASK-031 through TASK-036 (Thought Lifecycle & Feed State Transparency)

---

## Milestone 1: Hardware Trigger & Native Android Layer (In-Scope v1.0)

- [x] **TASK-001: Accessibility Service & Volume Key Interception**
  - **Area**: `android/app/src/main/kotlin/com/eudemonia/eudemonia/ButtonInterceptorService.kt`
  - **Spec**: [`PRODUCT_SPEC.md#fr1-hardware-key-trigger--volume-safety`](./PRODUCT_SPEC.md#fr1-hardware-key-trigger--volume-safety) (`FR1.1: The system must intercept VOLUME_UP and VOLUME_DOWN key events via an Android AccessibilityService`)
  - **Details**: Implement an Android `AccessibilityService` running in isolated process `:interceptor` capturing `KEYCODE_VOLUME_UP` and `KEYCODE_VOLUME_DOWN`.
  - **Verification**:
    - **Unit Tests**:
      - File: [`android/app/src/test/kotlin/com/eudemonia/eudemonia/VolumeButtonCoordinatorTest.kt`](file:///Users/harshmavani/Documents/Eudemonia/android/app/src/test/kotlin/com/eudemonia/eudemonia/VolumeButtonCoordinatorTest.kt)
      - Cases:
        1. Verifies interception of volume up key events.
        2. Verifies interception of volume down key events.
        3. Verifies non-volume key events are passed through to the system.
    - **Widget Tests**:
      - N/A — Native Android service component.
    - **Integration / Command Tests**:
      - `cd android && ./gradlew :app:testDebugUnitTest`

- [x] **TASK-002: Dual-Volume Key Detection & Timing Windows**
  - **Area**: `android/app/src/main/kotlin/com/eudemonia/eudemonia/VolumeButtonCoordinator.kt`
  - **Spec**: [`PRODUCT_SPEC.md#fr1-hardware-key-trigger--volume-safety`](./PRODUCT_SPEC.md#fr1-hardware-key-trigger--volume-safety) (`FR1.2: If both volume keys are pressed within a 50ms window, trigger thought recording toggle`)
  - **Details**: Implement a state machine detecting simultaneous dual-press within 50ms window (`dualPressWindowMs = 50L`) to toggle thought capture.
  - **Verification**:
    - **Unit Tests**:
      - File: [`android/app/src/test/kotlin/com/eudemonia/eudemonia/VolumeButtonCoordinatorTest.kt`](file:///Users/harshmavani/Documents/Eudemonia/android/app/src/test/kotlin/com/eudemonia/eudemonia/VolumeButtonCoordinatorTest.kt)
      - Cases:
        1. Pressing VolUp then VolDown within 50ms triggers `triggerVoicePipeline()`.
        2. Pressing VolDown then VolUp within 50ms triggers `triggerVoicePipeline()`.
        3. Pressing second key after 50ms does not trigger dual press.
        4. Releasing either key resets dual-press detection state.
    - **Widget Tests**:
      - N/A — Native Android component.
    - **Integration / Command Tests**:
      - `cd android && ./gradlew :app:testDebugUnitTest`

- [x] **TASK-003: Volume Key Pass-Through & Runaway Prevention**
  - **Area**: `android/app/src/main/kotlin/com/eudemonia/eudemonia/VolumeButtonCoordinator.kt`
  - **Spec**: [`PRODUCT_SPEC.md#fr1-hardware-key-trigger--volume-safety`](./PRODUCT_SPEC.md#fr1-hardware-key-trigger--volume-safety) (`FR1.4: Single volume clicks and holds must delegate transparently to AudioManager with repeat delays without runaway loops`)
  - **Details**: Route single clicks and long-press holds transparently to `AudioManager.adjustSuggestedStreamVolume(..., FLAG_SHOW_UI)` with 300ms initial delay and 110ms repeat intervals.
  - **Verification**:
    - **Unit Tests**:
      - File: [`android/app/src/test/kotlin/com/eudemonia/eudemonia/VolumeButtonCoordinatorTest.kt`](file:///Users/harshmavani/Documents/Eudemonia/android/app/src/test/kotlin/com/eudemonia/eudemonia/VolumeButtonCoordinatorTest.kt)
      - Cases:
        1. Single VolUp click raises volume once via `adjustVolume(DIRECTION_UP)`.
        2. Single VolDown click lowers volume once via `adjustVolume(DIRECTION_DOWN)`.
        3. Continuous VolUp hold schedules repeat after 300ms, then steps at 110ms intervals.
        4. Key release cancels repeat scheduler, preventing runaway volume loops.
        5. Maximum repeat steps cap (`maxRepeatSteps = 25`) prevents infinite repeat loops.
    - **Widget Tests**:
      - N/A — Native Android component.
    - **Integration / Command Tests**:
      - `cd android && ./gradlew :app:testDebugUnitTest`

- [x] **TASK-004: Instant Native Haptic Vibration**
  - **Area**: `android/app/src/main/kotlin/com/eudemonia/eudemonia/ButtonInterceptorService.kt`
  - **Spec**: [`PRODUCT_SPEC.md#fr1-hardware-key-trigger--volume-safety`](./PRODUCT_SPEC.md#fr1-hardware-key-trigger--volume-safety) (`FR1.3: Trigger haptic feedback must execute directly in Android native code upon event confirmation without deferring to Flutter`)
  - **Details**: Trigger dual-pulse haptic vibration (`VibrationEffect.createWaveform(longArrayOf(0, 40, 60, 40), -1)`) directly in native code upon dual-key confirmation (<20ms).
  - **Verification**:
    - **Unit Tests**:
      - File: [`android/app/src/test/kotlin/com/eudemonia/eudemonia/VolumeButtonCoordinatorTest.kt`](file:///Users/harshmavani/Documents/Eudemonia/android/app/src/test/kotlin/com/eudemonia/eudemonia/VolumeButtonCoordinatorTest.kt)
      - Cases:
        1. Verifies `triggerVoicePipeline()` is called synchronously upon dual-press confirmation.
    - **Widget Tests**:
      - N/A — Native Android component.
    - **Integration / Command Tests**:
      - `cd android && ./gradlew :app:testDebugUnitTest`

- [x] **TASK-005: Native Trigger Debounce Cooldown**
  - **Area**: `android/app/src/main/kotlin/com/eudemonia/eudemonia/TriggerDebouncer.kt`
  - **Spec**: [`PRODUCT_SPEC.md#fr1-hardware-key-trigger--volume-safety`](./PRODUCT_SPEC.md#fr1-hardware-key-trigger--volume-safety) (`FR1.5: The system must enforce a 500ms cooldown (TriggerDebouncer) to prevent duplicate trigger cascades across receivers`)
  - **Details**: Create shared thread-safe 500ms cooldown debouncer across `MainActivity` and `EudemoniaForegroundService` to eliminate duplicate trigger cascades.
  - **Verification**:
    - **Unit Tests**:
      - File: [`android/app/src/test/kotlin/com/eudemonia/eudemonia/NativeTriggerDebounceTest.kt`](file:///Users/harshmavani/Documents/Eudemonia/android/app/src/test/kotlin/com/eudemonia/eudemonia/NativeTriggerDebounceTest.kt)
      - Cases:
        1. First trigger call returns `true`.
        2. Immediate subsequent call within 500ms returns `false` (debounced).
        3. Trigger call after 500ms cooldown returns `true`.
        4. Explicit `reset()` clears cooldown timestamp.
    - **Widget Tests**:
      - N/A — Native Android component.
    - **Integration / Command Tests**:
      - `cd android && ./gradlew :app:testDebugUnitTest`

- [x] **TASK-006: Explicit Broadcast Dispatch without Rogue Activity Launches**
  - **Area**: `android/app/src/main/kotlin/com/eudemonia/eudemonia/ButtonInterceptorService.kt`
  - **Spec**: [`PRODUCT_SPEC.md#fr1-hardware-key-trigger--volume-safety`](./PRODUCT_SPEC.md#fr1-hardware-key-trigger--volume-safety) (`FR1: Hardware Key Trigger & Volume Safety`)
  - **Details**: Remove `startActivity(launchIntent)` from the interceptor process. Route hardware events strictly via `com.eudemonia.eudemonia.HARDWARE_TRIGGER` broadcast with `isLocked` extra.
  - **Verification**:
    - **Unit Tests**:
      - File: [`android/app/src/test/kotlin/com/eudemonia/eudemonia/EudemoniaForegroundServiceTest.kt`](file:///Users/harshmavani/Documents/Eudemonia/android/app/src/test/kotlin/com/eudemonia/eudemonia/EudemoniaForegroundServiceTest.kt)
      - Cases:
        1. Broadcast receiver unpacks `isLocked: false` and forwards to MethodChannel.
        2. Broadcast receiver unpacks `isLocked: true` and forwards to MethodChannel.
        3. Unrelated broadcast action is ignored.
    - **Widget Tests**:
      - N/A — Native Android component.
    - **Integration / Command Tests**:
      - `cd android && ./gradlew :app:testDebugUnitTest`

---

## Milestone 2: Background Reliability & Permissions (In-Scope v1.0)

- [x] **TASK-007: Android Foreground Keep-Alive Service**
  - **Area**: `android/app/src/main/kotlin/com/eudemonia/eudemonia/EudemoniaForegroundService.kt`
  - **Spec**: [`PRODUCT_SPEC.md#fr8-background-reliability--permissions`](./PRODUCT_SPEC.md#fr8-background-reliability--permissions) (`FR8.1: Provide an Android Foreground Service with an ongoing low-priority notification to protect from OS termination`)
  - **Details**: Implement foreground service with `foregroundServiceType="microphone"`, low-priority ongoing notification (`eudemonia_background_channel`), and broadcast receiver for triggers.
  - **Verification**:
    - **Unit Tests**:
      - File: [`android/app/src/test/kotlin/com/eudemonia/eudemonia/EudemoniaForegroundServiceTest.kt`](file:///Users/harshmavani/Documents/Eudemonia/android/app/src/test/kotlin/com/eudemonia/eudemonia/EudemoniaForegroundServiceTest.kt)
      - Cases:
        1. Verifies notification channel ID and constants.
        2. Coordinator starts foreground and updates `isRunning` flag to true.
        3. Coordinator stops foreground and updates `isRunning` flag to false.
        4. MethodChannel delivery forwards trigger when active channel is available.
    - **Widget Tests**:
      - N/A — Native Android component.
    - **Integration / Command Tests**:
      - `cd android && ./gradlew :app:testDebugUnitTest`

- [x] **TASK-008: Battery Optimization Exemption Integration**
  - **Area**: `android/app/src/main/AndroidManifest.xml`, `MainActivity.kt`
  - **Spec**: [`PRODUCT_SPEC.md#fr8-background-reliability--permissions`](./PRODUCT_SPEC.md#fr8-background-reliability--permissions) (`FR8.2: Detect and request both Accessibility Service and Battery Optimization Exemption`)
  - **Details**: Add `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` and `WAKE_LOCK`. Add `MethodChannel` handler to prompt system battery exemption dialog and query status.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/settings/background_permission_service_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/settings/background_permission_service_test.dart)
      - Cases:
        1. `checkStatus()` returns true when both accessibility and battery optimization are granted.
        2. `checkStatus()` returns false when battery optimization is not ignored.
        3. `requestIgnoreBatteryOptimizations()` invokes native platform channel method.
        4. `isIgnoringBatteryOptimizations` queries PowerManager correctly.
    - **Widget Tests**:
      - N/A — Platform service logic.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/settings/background_permission_service_test.dart`

- [x] **TASK-009: Simultaneous Permission Flow & Educational Modal**
  - **Area**: `lib/features/settings/background_permission_service.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr8-background-reliability--permissions`](./PRODUCT_SPEC.md#fr8-background-reliability--permissions) (`FR8.2: Prompt for both permissions simultaneously through an educational modal`)
  - **Details**: Implement `showSimultaneousPermissionModal()` explaining both Accessibility and Battery Exemption requirements, allowing one-tap sequential grant.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/settings/background_permission_service_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/settings/background_permission_service_test.dart)
      - Cases:
        1. `requestSimultaneousPermissions()` dispatches platform channel request.
    - **Widget Tests**:
      - File: [`test/features/settings/background_permission_ui_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/settings/background_permission_ui_test.dart)
      - Cases:
        1. Modal renders title, explanation, and "Enable Both" action on standard viewports.
        2. Modal renders on 360dp narrow viewport with 0 `RenderFlex` overflows.
        3. List tiles inside modal have Material ancestor without framework assertions.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/settings/background_permission_ui_test.dart`

- [x] **TASK-010: Standardized Permission States & Ambient Home Banner**
  - **Area**: `lib/features/settings/settings_screen.dart`, `lib/features/home/home_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr8-background-reliability--permissions`](./PRODUCT_SPEC.md#fr8-background-reliability--permissions) (`FR8.3: Permission status indicators across settings and alerts must use standardized Enabled (Green) and Disabled (Amber) badges`)
  - **Details**: Standardize status labels to **Enabled** (Green) and **Disabled** (Amber). Add ambient warning banner on Home screen that auto-dismisses via `WidgetsBindingObserver` on app resume.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/settings/background_permission_service_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/settings/background_permission_service_test.dart)
      - Cases:
        1. Model copyWith updates permission states accurately.
    - **Widget Tests**:
      - File: [`test/features/settings/background_permission_ui_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/settings/background_permission_ui_test.dart)
      - Cases:
        1. SettingsScreen renders green "Enabled" chip when permissions are active.
        2. SettingsScreen renders amber "Disabled" chip when permissions are inactive.
        3. Verifies complete absence of ambiguous "Active" or "Granted" text.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/settings/background_permission_ui_test.dart`

---

## Milestone 3: Decoupled FIFO Queue & Zero-Latency Capture (In-Scope v1.0)

- [x] **TASK-011: Lightweight Non-Blocking Capture Dispatch**
  - **Area**: `lib/features/ai_processing/batch_pipeline_service.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr2-non-blocking-audio-capture`](./PRODUCT_SPEC.md#fr2-non-blocking-audio-capture) (`FR2: Non-Blocking Audio Capture (<5ms budget)`)
  - **Details**: Decouple audio capture from AI model loading. `startRecording()` initiates capture with 0ms delay. `stopRecordingAndProcess()` enqueues audio and returns in <5ms without awaiting inference.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/batch_pipeline_queue_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/batch_pipeline_queue_test.dart)
      - Cases:
        1. `startRecording()` starts audio capture without initiating model loading.
        2. `stopRecordingAndProcess()` enqueues audio file into `AudioQueueService` immediately.
        3. Null audio path from cancelled recording does not enqueue item.
    - **Widget Tests**:
      - N/A — Service layer logic.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/batch_pipeline_queue_test.dart`

- [x] **TASK-012: Persistent FIFO Audio Queue Service**
  - **Area**: `lib/features/ai_processing/audio_queue_service.dart`, `audio_queue_item.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr3-persistent-fifo-audio-queue`](./PRODUCT_SPEC.md#fr3-persistent-fifo-audio-queue) (`FR3.1: Enqueued audio files must be persisted to queue.json with ID, timestamp, and status pending`)
  - **Details**: Create disk-backed FIFO queue stored at `${appDocumentsDir}/queue/queue.json` tracking status: `pending` -> `transcribing` -> `categorizing` -> `completed` / `failed`.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/audio_queue_service_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/audio_queue_service_test.dart)
      - Cases:
        1. Initial queue state is empty with `pendingCount = 0` and `failedCount = 0`.
        2. `enqueue()` adds multiple items and persists items to storage JSON.
        3. Item serialization round-trip retains `id`, `audioFilePath`, `recordedAt`, and `status`.
    - **Widget Tests**:
      - N/A — Core queue service.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/audio_queue_service_test.dart`

- [x] **TASK-013: Synchronous Riverpod State Notifiers**
  - **Area**: `lib/features/ai_processing/audio_queue_service.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr3-persistent-fifo-audio-queue`](./PRODUCT_SPEC.md#fr3-persistent-fifo-audio-queue) (`FR3.3: Expose real-time synchronous counts via Riverpod NotifierProvider`)
  - **Details**: Replace broadcast stream with Riverpod 3 `NotifierProvider<PendingQueueCountNotifier, int>` and `NotifierProvider<FailedQueueCountNotifier, int>` to prevent dropped events.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/audio_queue_service_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/audio_queue_service_test.dart)
      - Cases:
        1. Enqueuing updates `PendingQueueCountNotifier` synchronously.
        2. Processing completion decrements `pendingCount` synchronously.
    - **Widget Tests**:
      - File: [`test/features/home/home_screen_trigger_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/home_screen_trigger_test.dart)
      - Cases:
        1. UI reacts immediately to count updates without needing full pump rebuilds.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/home_screen_trigger_test.dart`

- [x] **TASK-014: Sequential Background Queue Worker Loop**
  - **Area**: `lib/features/ai_processing/audio_queue_service.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr3-persistent-fifo-audio-queue`](./PRODUCT_SPEC.md#fr3-persistent-fifo-audio-queue) (`FR3.2: A background queue worker must process items sequentially one at a time`)
  - **Details**: Implement asynchronous queue loop that ensures models are loaded, transcribes via STT, categorizes via LLM, persists to Isar, cleans up temporary audio, and resets inactivity TTL.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/audio_queue_service_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/audio_queue_service_test.dart)
      - Cases:
        1. Worker invokes `ModelLifecycleManager.ensureModelsLoaded()` before transcribing.
        2. Worker passes audio to STT and transcript to LLM sequentially.
        3. Worker saves completed note to `NotesRepository`.
        4. Worker calls `_modelLifecycle.touch()` upon note completion.
    - **Widget Tests**:
      - N/A — Asynchronous worker loop.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/audio_queue_service_test.dart`

- [x] **TASK-015: Queue Failure Isolation & Retry Mechanism**
  - **Area**: `lib/features/ai_processing/audio_queue_service.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr3-persistent-fifo-audio-queue`](./PRODUCT_SPEC.md#fr3-persistent-fifo-audio-queue) (`FR3.4 & FR3.5: Failed items transition to failed status without blocking; retryFailed() resets failed items back to pending`)
  - **Details**: Isolate failed items (e.g. empty audio) to `failed` status without blocking the queue. Implement `retryFailed()` to reset failed items back to `pending`.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/audio_queue_service_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/audio_queue_service_test.dart)
      - Cases:
        1. Empty speech transcript marks item `failed` and does not throw uncaught error.
        2. Subsequent pending item in queue is processed successfully after prior failure.
        3. `retryFailed()` flips all failed items back to `pending` and triggers processing.
    - **Widget Tests**:
      - File: [`test/features/home/home_screen_trigger_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/home_screen_trigger_test.dart)
      - Cases:
        1. Failed item renders retry banner; tapping "Retry" calls `retryFailed()`.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/home_screen_trigger_test.dart`

---

## Milestone 4: On-Device AI Models & Memory Management (In-Scope v1.0)

- [x] **TASK-016: On-Device Speech Recognition (Sherpa-ONNX)**
  - **Area**: `lib/features/ai_processing/stt_service.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr4-on-device-speech-recognition-stt`](./PRODUCT_SPEC.md#fr4-on-device-speech-recognition-stt) (`FR4: On-Device Speech Recognition via Sherpa-ONNX Parakeet v3 with empty speech detection`)
  - **Details**: Integrate `sherpa_onnx` offline recognizer with Parakeet v3 CTC/Transducer models (~600MB). Return raw transcript.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/audio_queue_service_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/audio_queue_service_test.dart)
      - Cases:
        1. Uninitialized STT throws `Exception: STT Service not initialized`.
        2. Initialized STT transcribes WAV audio file and returns text.
        3. Empty speech returns empty transcript string.
    - **Widget Tests**:
      - N/A — Native model bridge.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/audio_queue_service_test.dart`

- [x] **TASK-017: Model Lifecycle State Machine**
  - **Area**: `lib/features/ai_processing/model_lifecycle_manager.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr6-model-lifecycle--memory-management`](./PRODUCT_SPEC.md#fr6-model-lifecycle--memory-management) (`FR6.1: Maintain three lifecycle states: unloaded, loading, and ready`)
  - **Details**: Implement `unloaded`, `loading`, and `ready` states. `ensureModelsLoaded()` provides idempotent, thread-safe future caching.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/model_lifecycle_manager_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/model_lifecycle_manager_test.dart)
      - Cases:
        1. Initial state is `unloaded`.
        2. State transitions to `loading` during initialization, then `ready` upon completion.
        3. Concurrent calls to `ensureModelsLoaded()` await the same Future without double-initialization.
    - **Widget Tests**:
      - N/A — Lifecycle controller.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/model_lifecycle_manager_test.dart`

- [x] **TASK-018: Sequential Model Loading (RAM Spike Prevention)**
  - **Area**: `lib/features/ai_processing/model_lifecycle_manager.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr6-model-lifecycle--memory-management`](./PRODUCT_SPEC.md#fr6-model-lifecycle--memory-management) (`FR6.2: Models must be loaded sequentially (STT first, LLM second) to prevent memory allocation spikes`)
  - **Details**: Sequence model initialization (Sherpa-ONNX first, Qwen GGUF second) to prevent simultaneous peak allocation spikes above Android LMK threshold.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/model_lifecycle_manager_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/model_lifecycle_manager_test.dart)
      - Cases:
        1. STT initialize completes before LLM initialize begins.
        2. Total memory footprint during sequential loading stays below concurrent load threshold.
    - **Widget Tests**:
      - N/A — Native model loading logic.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/model_lifecycle_manager_test.dart`

- [x] **TASK-019: Inactivity TTL Model Eviction (3-Minute Timer)**
  - **Area**: `lib/features/ai_processing/model_lifecycle_manager.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr6-model-lifecycle--memory-management`](./PRODUCT_SPEC.md#fr6-model-lifecycle--memory-management) (`FR6.3 & FR6.4: Unload both models from RAM after 3 minutes idle, resetting timer on activity`)
  - **Details**: Implement inactivity timer disposing native C++ handles for both STT and LLM after 3 minutes idle, returning baseline RAM footprint to <60 MB.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/model_lifecycle_manager_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/model_lifecycle_manager_test.dart)
      - Cases:
        1. Advancing time by 2 minutes preserves models in `ready` state.
        2. Advancing time past 3 minutes (180s) triggers `evictModels()`, transitioning state to `unloaded`.
        3. Calling `touch()` resets the 3-minute countdown.
        4. Calling `ensureModelsLoaded()` after eviction re-loads models cleanly.
    - **Widget Tests**:
      - N/A — Timer lifecycle controller.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/model_lifecycle_manager_test.dart`

- [x] **TASK-020: Language Correction & Two-Tier Processing Foundations**
  - **Area**: `lib/features/ai_processing/note_classifier.dart`, `llm_service.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr5-on-device-llm-pipeline-two-tier-post-processing`](./PRODUCT_SPEC.md#fr5-on-device-llm-pipeline-two-tier-post-processing) (`FR5.2: Grammar cleanup, filler-word removal, structured text cleanup`)
  - **Details**: Implement ChatML prompt for Qwen-2.5 1.5B GGUF with grammar cleanup, filler-word removal (*"um"*, *"like"*), capitalization, and punctuation correction.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/note_classifier_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/note_classifier_test.dart)
      - Cases:
        1. ChatML prompt formats system, user, and assistant tokens correctly.
        2. Filler words ("um", "uh", "you know") stripped from corrected text.
        3. Valid JSON parses cleanly into cleaned speech result.
    - **Widget Tests**:
      - N/A — Natural language processing logic.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/note_classifier_test.dart`

- [x] **TASK-021: Granular LLM Configuration & Stateless KV Cache Purging**
  - **Area**: `lib/features/ai_processing/llm_config.dart`, `llm_service.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr5-on-device-llm-pipeline-two-tier-post-processing`](./PRODUCT_SPEC.md#fr5-on-device-llm-pipeline-two-tier-post-processing) (`FR5.6: Purge KV cache after every turn (clearKvCacheEveryXTurns = 1)`)
  - **Details**: Create `LLMConfig` defining `kvCacheMaxSize` (2048), `inputTokenLimit` (1536), and `clearKvCacheEveryXTurns` (default 1). Purge KV slot via `_llama.disposeScope()` after each turn to avoid residual RAM consumption.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/llm_config_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/llm_config_test.dart)
      - Cases:
        1. Default `LLMConfig` parameters match specifications.
        2. Config assertions validate positive token limits and batch sizes.
      - File: [`test/features/ai_processing/llm_service_kv_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/llm_service_kv_test.dart)
      - Cases:
        1. `completedTurnsCount` increments with each `processText` call.
        2. `clearKvCache()` safely executes without error on empty or uninitialized context.
        3. Custom config parameters are retained across service calls.
    - **Widget Tests**:
      - N/A — LLM inference controller.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/llm_service_kv_test.dart`

- [x] **TASK-022: Heuristic Fallback Classifier**
  - **Area**: `lib/features/ai_processing/note_classifier.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr5-on-device-llm-pipeline-two-tier-post-processing`](./PRODUCT_SPEC.md#fr5-on-device-llm-pipeline-two-tier-post-processing) (`FR5.5: Fall back to heuristic classifier if LLM output fails to parse`)
  - **Details**: Implement keyword-based heuristic classifier used as a fallback if the LLM is uninitialized or JSON parsing fails.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/llm_service_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/llm_service_test.dart)
      - Cases:
        1. Uninitialized LLM routes text through heuristic classifier.
        2. Fallback handles empty or malformed strings gracefully.
    - **Widget Tests**:
      - N/A — Classification fallback logic.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/llm_service_test.dart`

---

## Milestone 5: Persistence, UI Observability & Diagnostics (In-Scope v1.0)

- [x] **TASK-023: Isar Embedded Database Note Persistence**
  - **Area**: `lib/features/notes/data/note_model.dart`, `notes_repository.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr7-local-persistence`](./PRODUCT_SPEC.md#fr7-local-persistence) (`FR7.1 & FR7.2: Processed thoughts saved to Isar database; query by recency`)
  - **Details**: Create Isar `Note` schema (`id`, `rawText`, `cleanedText`, `createdAt`, `originalAudioPath`) and repository with query methods.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/audio_queue_service_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/audio_queue_service_test.dart)
      - Cases:
        1. Notes repository saves note object with correct text and timestamp.
        2. Note can be retrieved by id.
    - **Widget Tests**:
      - N/A — Database repository layer.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/audio_queue_service_test.dart`

- [x] **TASK-024: Real-Time Queue Badge in AppBar**
  - **Area**: `lib/features/home/home_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr3-persistent-fifo-audio-queue`](./PRODUCT_SPEC.md#fr3-persistent-fifo-audio-queue) (`FR3.3: Expose real-time synchronous counts via Riverpod NotifierProvider`)
  - **Details**: Render a live `$count pending` chip with micro-spinner in the AppBar when `pendingCount > 0`. Hide when queue is empty.
  - **Verification**:
    - **Unit Tests**:
      - N/A — UI presentation layer.
    - **Widget Tests**:
      - File: [`test/features/home/home_screen_trigger_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/home_screen_trigger_test.dart)
      - Cases:
        1. AppBar badge renders "2 pending" when pending count is 2.
        2. AppBar badge renders circular progress indicator.
        3. AppBar badge is completely hidden when pending count is 0.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/home_screen_trigger_test.dart`

- [x] **TASK-025: In-Body Processing Card**
  - **Area**: `lib/features/home/home_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#6-user-experience-ux--four-stage-interaction-architecture`](./PRODUCT_SPEC.md#6-user-experience-ux--four-stage-interaction-architecture) (`Section 6: In-body processing card with live progress indicator`)
  - **Details**: Render card indicating `Processing voice thought ($pendingCount pending)...` with active progress indicator while worker is active.
  - **Verification**:
    - **Unit Tests**:
      - N/A — UI presentation layer.
    - **Widget Tests**:
      - File: [`test/features/home/home_screen_trigger_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/home_screen_trigger_test.dart)
      - Cases:
        1. Banner renders "Processing voice thought (2 pending)..." when items are queued.
        2. Banner renders progress indicator.
        3. Banner hides when pending count drops to 0.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/home_screen_trigger_test.dart`

- [x] **TASK-026: Failed Items Banner with Interactive Retry**
  - **Area**: `lib/features/home/home_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr3-persistent-fifo-audio-queue`](./PRODUCT_SPEC.md#fr3-persistent-fifo-audio-queue) (`FR3.4 & FR3.5: Failed items transition to failed status; retryFailed() resets back to pending`)
  - **Details**: Render warning banner when `failedCount > 0` with a **Retry** button invoking `ref.read(audioQueueServiceProvider).retryFailed()`.
  - **Verification**:
    - **Unit Tests**:
      - N/A — UI interaction layer.
    - **Widget Tests**:
      - File: [`test/features/home/home_screen_trigger_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/home_screen_trigger_test.dart)
      - Cases:
        1. Banner renders "1 thought(s) failed to process" when failed count is 1.
        2. Tapping "Retry" button invokes queue retry mechanism.
        3. Banner hides when failed count is 0.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/home_screen_trigger_test.dart`

- [x] **TASK-027: Layout Overflows & Material Ink Splash Contract Fixes**
  - **Area**: `lib/features/settings/background_permission_service.dart`
  - **Spec**: [`PRODUCT_SPEC.md#d-non-functional-requirements-nfr`](./PRODUCT_SPEC.md#d-non-functional-requirements-nfr) (`NFR: Reliability & Zero Framework UI Assertions`)
  - **Details**: Wrap text in `Expanded` to prevent 16px right overflow on 360dp screens. Replace `Container(decoration: ...)` with `Material(...)` around `ListTile` to fix framework assertions.
  - **Verification**:
    - **Unit Tests**:
      - N/A — Layout rendering verification.
    - **Widget Tests**:
      - File: [`test/features/settings/background_permission_ui_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/settings/background_permission_ui_test.dart)
      - Cases:
        1. Modal renders on 360dp narrow viewport with 0 `RenderFlex` overflows.
        2. `ListTile` widgets inside modal have Material ancestor without framework ink splash assertions.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/settings/background_permission_ui_test.dart`

- [x] **TASK-028: Rotating File Logger & In-App Telemetry Dump**
  - **Area**: `lib/core/logger/app_logger.dart`, `lib/features/settings/settings_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#5-scope--requirements`](./PRODUCT_SPEC.md#5-scope--requirements) (`Diagnostic logging system with 2MB rotating disk cap and in-app viewer`)
  - **Details**: Implement `AppLogger` writing triggers, transitions, and errors to `${appDocumentsDir}/logs/app_logs.txt` with a 2MB rotating cap. Add live log viewer and clipboard dump in Settings.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/core/logger/app_logger_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/core/logger/app_logger_test.dart)
      - Cases:
        1. Logger writes formatted log lines with ISO timestamps.
        2. `getLogs()` reads log file content accurately.
        3. `clearLogs()` purges log file on disk.
        4. Exceeding 2MB rotates file cleanly without unbounded growth.
    - **Widget Tests**:
      - N/A — Logger core logic.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/core/logger/app_logger_test.dart`

---

## Milestone 6: UI/UX Component Sandbox (Completed Prototyping)

## Milestone 6: UI/UX Component Sandbox & Four-Stage Interaction Mockups (Active & Priority)

- [x] **TASK-047: Four-Stage Screen Mockups & Interactive Preview Sandbox (Capture, Synthesis, Insights, Action, Settings & Pipeline HUD)**
  - **Area**: `previews/screens/capture_screen_preview.dart`, `previews/screens/synthesis_screen_preview.dart`, `previews/screens/insights_screen_preview.dart`, `previews/screens/action_screen_preview.dart`, `previews/screens/settings_preview.dart`, `previews/screens/style_rewriter_preview.dart`, `previews/screens/note_ejection_preview.dart`, `previews/mock_data.dart`, `previews/gallery_shell.dart`, `previews/main_preview.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr9-capture-screen-presentation-status-colors--dual-filters`](./PRODUCT_SPEC.md#fr9-capture-screen-presentation-status-colors--dual-filters), [`PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering`](./PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering), and [`UX.md`](./UX.md)
  - **Details**:
    1. Build isolated preview screens using typed mock data (`mock_data.dart`) with zero production boilerplate in `lib/`.
    2. Implement `gallery_shell.dart` navigation & mind pipeline HUD:
       - Top AI Pipeline Status Pill: `[ ⚡ X in Pipeline ▾ ]` / `[ 🌿 In Sync ▾ ]`. Tapping opens the interactive **Pipeline HUD Modal** breaking down machine work (Capture STT queue, Synthesis batch queue with `[ ⚡ Synthesize Now ]`, Insights daily refresh countdown, and Action extraction state).
       - Top Settings action button opening `settings_preview.dart`.
       - Stage tab bar displaying numbers strictly for **unconsumed human value** with zero-suppression (`Capture (2)`, `Synthesis (1)`, `Insights (1)`, `Action (3)`; omitting `(0)` when count is zero).
    3. Implement `capture_screen_preview.dart`:
       - Cognitive State Color Accents: Yellow for pending processing (`stateEnqueuedBg`), Blue for processed STT/cleaned entries (`stateProcessedBg`), Green for synthesis completed entries (`stateSynthesizedBg`), and Red for failed entries (`stateFailedBg`).
       - Compact Dual Dropdown Filters: Triage dropdown (`[ 👁️ All Triage ▾ ]` for `All`, `Unread`, `Read`) and Processing State dropdown (`[ ⚡ All Statuses ▾ ]` for `All`, `Processing`, `Processed`, `Synthesized`, `Failed`) preserving vertical space and matching Synthesis dropdown styling.
       - Daily sequence numbering (`#01` to `#06`...) with preserved gaps on deletion.
       - Header layout order: `[# Number]` $\rightarrow$ `[▶ Play]` $\rightarrow$ `[• Unread]` $\rightarrow$ `[🗑️ Delete]`.
       - Footer format: `DD/MM  HH:MM AM/PM`.
       - Action controls: Manual text edit (`[ ✎ Edit ]`). Style re-writing is removed from Capture and hosted under Synthesis.
       - Interactive Clickable Floating Capture Trigger: Floating capsule with prominent mic icon (`20sp`), visual `"/"` separator, and text: `[ 🎙️ / Press Vol Up + Down to Capture ]`. Clickable in-app to start recording; when active, morphs into an animated listening waveform / loader bar inside the button replacing the mic and text, and enqueues a new yellow pending card on stop with clean SnackBar feedback: `"Captured a new note [#0X]"` (free of internal debug filler).
    4. Implement `synthesis_screen_preview.dart`:
       - Dual compact dropdown filters: `[ 👁️ All Triage ▾ ]` (`All`, `Unread`, `Read`) and `[ 📁 All Folders ▾ ]` (`All Folders`, `Work`, `Ideas`, `Todos`, `Journal`, `Uncategorized`).
       - Unread indicator dot (`• Unread`) on newly clustered cards, cleared on user interaction.
       - Tri-color card states: Yellow (`stateEnqueuedBg` / re-synthesizing), Blue (`stateProcessedBg` / awaiting action extraction), Green (`stateSynthesizedBg` / action extraction pass completed).
       - Pending batch synthesis banner: `[ 🧩 X raw thoughts ready to cluster • [ ⚡ Synthesize Now ] ]`.
       - Clustered session notes (`#S-01`, `#S-02`), card folder badge with 1-tap reassignment dropdown (`[ 💡 Ideas ▾ ]`), synthesis narrative, session time span and duration.
       - AI Style Re-Writer: Each cluster card features `[ ✨ Style ▾ ]` button. Modal shows 6 preset context prompts, highlighting currently applied style with a checkmark (`Icons.check`). Changing style flags cluster as re-processing and turns card Yellow (`stateEnqueuedBg`).
       - Expandable origin raw notes count pill (`[ 🧩 3 Raw Notes ▾ ]`).
       - Single Note Ejection Guard: If cluster has only 1 note (`originNotes.length <= 1`), hide/disable the `[ ⤢ Move Out ]` button.
       - `note_ejection_preview.dart` modal offering "Move to another clubbed note" (with target cluster picker for `#S-01`, `#S-02`, etc.) vs "Make it an independent note", with clean copy free of recurring debug filler text. When moved, both source and target clubbed notes transition to Yellow for re-synthesis.
    5. Implement `settings_preview.dart`:
       - Background permissions (Accessibility Service, Battery Optimization).
       - Automatic Synthesis Trigger & Batching Settings: $X$ capture message threshold (1–10 notes, default 3), $Y$ minutes inactivity threshold (5–60 mins, default 15), and `[ ⚡ Synthesize Buffer Now ]` override.
       - Calendar Sync controls, RAM telemetry & manual model eviction, and rotating diagnostic log console.
    6. Implement `insights_screen_preview.dart`: segmented sub-view switcher across Emotional Climate Heatmap (-1.0 to +1.0 valence with 2-minute coherence breath button), Topic & Work Density matrix, and Recurrent Thought Patterns detected across sessions.
    7. Implement `action_screen_preview.dart`: commitments todo list with checkboxes, urgency badges, time anchors (`05/11  02:00 PM`), and origin session links; Calendar Time-Block Preview schedule; Calendar Sync status card with push button.
    8. Connect all 4 screens, Settings, and Pipeline HUD into `gallery_shell.dart` and `main_preview.dart` with a top stage switcher for interactive testing.
    9. **Human Alignment & Verification Gate**: Run `flutter run -t previews/main_preview.dart` and present for user interactive review and sign-off before promoting any widgets into `lib/`.
  - **Verification**:
    - **Unit Tests**:
      - File: `test/previews/preview_mock_data_test.dart`
      - Cases:
        1. Mock data supplies valid daily sequence numbers across multiple statuses (Yellow pending, Blue processed, Green synthesized, Red failed).
        2. Mock clusters contain valid origin raw note references, unread state, and tri-color maturation statuses.
        3. Style presets contain all 6 required prompts and labels.
        4. Settings mock configuration supplies valid synthesis batching thresholds ($X$ count, $Y$ minutes).
    - **Widget Tests**:
      - File: `test/previews/preview_screens_test.dart`
      - Cases:
        1. All preview screens render with zero framework assertions.
        2. Top bar AI pipeline pill is interactive and opens Pipeline HUD modal detailing stage status and `[ ⚡ Synthesize Now ]`.
        3. Stage tab bar displays zero-suppressed numbers for unconsumed human value (`Capture (2)`, `Synthesis (1)`, `Action (3)`).
        4. Capture screen compact dual dropdown filters (Triage and Processing status) filter items accurately without chip row clutter.
        5. Capture screen floating trigger renders with larger mic and `"/"` separator, is clickable to toggle active listening waveform state, and emits clean SnackBar copy (`Captured a new note [#0X]`).
        6. Capture card header ordering strictly renders `# Number` before `Play button` before `Unread dot` before `Delete`, and card footer has manual edit (zero style button).
        7. Synthesis screen renders dual dropdown filters (`[ 👁️ All Triage ▾ ]` and `[ 📁 All Folders ▾ ]`), unread dots, and tri-color card states (Yellow, Blue, Green).
        8. Synthesis screen cluster cards feature `[ ✨ Style ▾ ]` button; opening modal highlights active preset with checkmark, and selecting a new preset sets cluster to Yellow (`isReprocessing = true`).
        9. Synthesis screen hides `[ Move Out ]` button when cluster has only 1 note.
        10. Note ejection modal presents clean target selection without instructional filler messages, and sets both clusters to Yellow pending re-synthesis.
        11. Settings screen renders background permissions, synthesis batching thresholds slider/dropdowns, and calendar sync controls with 0 overflows.
        12. Layout adapts down to 360dp narrow viewport with 0 `RenderFlex` overflows.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/previews/preview_screens_test.dart`
      - `~/flutter/bin/flutter run -t previews/main_preview.dart -d macos`


---

## Milestone 7: Thought Lifecycle & Feed State Transparency (In-Scope v1.0)

- [x] **TASK-031: Persistent Queue Hydration & Cold-Start State Recovery**
  - **Area**: `lib/features/ai_processing/audio_queue_service.dart`, `lib/features/home/home_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr13-system-observability--telemetry-visualizers`](./PRODUCT_SPEC.md#fr13-system-observability--telemetry-visualizers) (`FR13.3: Queue service and UI state must hydrate synchronously from disk on cold restart within <50ms`)
  - **Details**: Ensure `AudioQueueService` reads existing `pending` items from `${appDocumentsDir}/queue/queue.json` on cold startup and exposes them synchronously to Riverpod providers, ensuring the AppBar pill and In-Body banner persist across app kills.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/queue_cold_start_hydration_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/queue_cold_start_hydration_test.dart)
      - Cases:
        1. Service initializes with pre-existing `queue.json` containing 3 items and sets `pendingCount` to 3.
        2. Worker resumes processing next pending item without losing queue sequence.
        3. Corrupt entries are quarantined without terminating hydration.
    - **Widget Tests**:
      - File: [`test/features/home/home_cold_start_queue_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/home_cold_start_queue_test.dart)
      - Cases:
        1. AppBar displays `3 pending` pill immediately on launch before worker loop starts.
        2. In-body processing card renders with active indicator on cold start.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/queue_cold_start_hydration_test.dart`

- [x] **TASK-032: Optimistic Capture Feed Item & Audio Playback Integration**
  - **Area**: `lib/features/notes/presentation/thought_card.dart`, `lib/features/notes/note_model.dart`, `lib/features/home/home_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr9-capture-screen-presentation--daily-numbering`](./PRODUCT_SPEC.md#fr9-capture-screen-presentation--daily-numbering) (`FR9: Immediate audio playback button adjacent to note number`)
  - **Details**: When a recording completes, immediately insert placeholder note row with current timestamp and animated shimmer text. Include an interactive `[ ▶ Play Audio ]` button allowing immediate playback of raw PCM/WAV audio while processing.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/notes/note_lifecycle_model_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/note_lifecycle_model_test.dart)
      - Cases:
        1. `Note` model instantiation supports `ThoughtState.enqueued` with `audioFilePath`.
        2. Audio player controller toggles play and pause on local file path.
    - **Widget Tests**:
      - File: [`test/features/home/feed_immediate_hydration_and_playback_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/feed_immediate_hydration_and_playback_test.dart)
      - Cases:
        1. Enqueued audio immediately renders card in feed with audio playback button without restart.
        2. Processing completion replaces enqueued placeholder with cleaned note without restart.
        3. Tapping play audio button triggers audio playback controller.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/feed_immediate_hydration_and_playback_test.dart`

- [x] **TASK-033: Processed Blue & Failed Red Card States with Failure Handling**
  - **Area**: `lib/features/notes/presentation/thought_card.dart`, `lib/features/home/home_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr3-persistent-fifo-audio-queue`](./PRODUCT_SPEC.md#fr3-persistent-fifo-audio-queue) (`FR3.4: Failed item failure handling, retry trigger, preserve playable audio`)
  - **Details**: Implement dynamic card transition upon completion. If inference fails, display explicit error reason directly in the entry, preserve raw audio playback, and provide a 1-tap `Retry` button.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/notes/note_state_transition_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/note_state_transition_test.dart)
      - Cases:
        1. State updates from `enqueued` to `processed` upon worker completion.
        2. State updates to `failed` with error description when worker throws.
        3. Retrying failed item resets status to `pending`.
    - **Widget Tests**:
      - File: [`test/features/home/feed_immediate_hydration_and_playback_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/feed_immediate_hydration_and_playback_test.dart)
      - Cases:
        1. Processed thought card displays cleaned text without restart.
        2. Failed thought card displays `Retry` button inside card with no top banner.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/feed_immediate_hydration_and_playback_test.dart`

- [x] **TASK-034: Inline Text Editing & Manual Card Updates**
  - **Area**: `lib/features/notes/presentation/thought_card.dart`, `lib/features/notes/notes_repository.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr9-capture-screen-presentation--daily-numbering`](./PRODUCT_SPEC.md#fr9-capture-screen-presentation--daily-numbering) (`FR9.6: Manual text editing on capture cards`)
  - **Details**: Add an inline editing mode or quick-sheet on thought cards allowing direct text edits saved to Isar database.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/notes/notes_repository_edit_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/notes_repository_edit_test.dart)
      - Cases:
        1. `updateNoteText(id, newText)` persists updated text to database.
    - **Widget Tests**:
      - File: [`test/features/home/thought_card_interaction_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/thought_card_interaction_test.dart)
      - Cases:
        1. Tapping edit icon toggles inline text editor and saves changes on submit.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/thought_card_interaction_test.dart`

- [x] **TASK-035: Unread / Viewed Thought Status Tracking & Indicator Dot**
  - **Area**: `lib/features/notes/note_model.dart`, `lib/features/home/home_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr9-capture-screen-presentation--daily-numbering`](./PRODUCT_SPEC.md#fr9-capture-screen-presentation--daily-numbering) (`FR9.4: Header layout ordering with electric blue unread dot`)
  - **Details**: Add `isRead` boolean field to Note model (default: false). Render a subtle electric blue indicator dot (`•`) following the play button on unreviewed cards. Tapping card marks as read.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/notes/note_read_status_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/note_read_status_test.dart)
      - Cases:
        1. New notes are created with `isRead = false`.
        2. `markAsRead(id)` updates note in database.
    - **Widget Tests**:
      - File: [`test/features/home/unread_triage_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/unread_triage_test.dart)
      - Cases:
        1. Unread cards display electric blue dot.
        2. Tapping unread card clears indicator dot.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/unread_triage_test.dart`

- [x] **TASK-036: Hardware-Accelerated 60/120fps Smooth Progress Indicator**
  - **Area**: `lib/features/home/presentation/smooth_processing_indicator.dart`, `lib/features/home/home_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#d-non-functional-requirements-nfr`](./PRODUCT_SPEC.md#d-non-functional-requirements-nfr) (`NFR: UI Render Fluidity locked 60/120fps during active inference`)
  - **Details**: Implement a lightweight, GPU-accelerated custom painter progress indicator widget that runs independently of Dart isolate event loops, ensuring butter-smooth animation even when background STT/LLM inference is executing at peak CPU.
  - **Verification**:
    - **Unit Tests**:
      - N/A — Pure visual rendering component.
    - **Widget Tests**:
      - File: [`test/features/home/smooth_processing_indicator_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/smooth_processing_indicator_test.dart)
      - Cases:
        1. Indicator renders without throwing framework layout assertions.
        2. Ticking animation controller drives painter sweep angle continuously.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/smooth_processing_indicator_test.dart`

---

