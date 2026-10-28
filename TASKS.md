# TASKS.md — Eudemonia SDLC Task Tracker & Execution Backlog

> **Purpose**: This document bridges the gap between [`PRODUCT_SPEC.md`](file:///Users/harshmavani/Documents/Eudemonia/PRODUCT_SPEC.md) (the *What* & *Why*) and [`IMPLEMENTATION.md`](file:///Users/harshmavani/Documents/Eudemonia/IMPLEMENTATION.md) (the *How* & *Architecture*). It decomposes all product requirements into atomic, verifiable engineering tasks for AI agents and human developers.
>
> **Task Creation & Execution Standards**:
> 1. **Strict Spec Alignment**: The `Spec` link **must** point directly to the relevant requirement heading in [`PRODUCT_SPEC.md`](file:///Users/harshmavani/Documents/Eudemonia/PRODUCT_SPEC.md) using stable semantic heading anchors (e.g., `[PRODUCT_SPEC.md#fr1-hardware-key-trigger--volume-safety](./PRODUCT_SPEC.md#fr1-hardware-key-trigger--volume-safety)`). Avoid brittle line numbers (`#L...`), which break whenever the specification document is edited. Never invent requirements not grounded in the specification.
> 2. **No Out-of-Scope Tasks**: Never create tasks for features defined as out-of-scope in [`PRODUCT_SPEC.md#b-out-of-scope-explicit-non-goals-for-v10`](./PRODUCT_SPEC.md#b-out-of-scope-explicit-non-goals-for-v10) (e.g., multi-tag graphs, cloud sync, real-time streaming STT, waveform visualizers, iOS).
> 3. **Structured Verification Breakdown**: Every task **must** include dedicated sub-sections for:
>    - **Unit Tests**: Test file path and specific bulleted cases covered.
>    - **Widget Tests**: Test file path and specific interaction/rendering cases covered (or `N/A - Non-UI component`).
>    - **Integration / Command Tests**: Prescribed CLI verification command.
> 4. **TDD Workflow**: Pick the next pending task (`[ ]` or `[/]`), write failing unit/widget tests first, implement the minimal solution, verify passing, and check off `[x]`.

---

## Task Status Legend
- `[x]` **Completed**: Implemented, verified with unit/widget tests, and passing all quality gates.
- `[/]` **In Progress**: Active development or test coverage underway.
- `[ ]` **Pending**: Ready for pickup within the active milestone.

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

- [x] **TASK-020: Language Correction & Single-Folder Classification**
  - **Area**: `lib/features/ai_processing/note_classifier.dart`, `llm_service.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr5-on-device-llm-post-processing--categorization`](./PRODUCT_SPEC.md#fr5-on-device-llm-post-processing--categorization) (`FR5.2 & FR5.3: Grammar cleanup, filler-word removal, strict single-folder assignment, confidence score parsing`)
  - **Details**: Implement ChatML prompt for Qwen-2.5 1.5B GGUF with grammar cleanup, filler-word removal (*"um"*, *"like"*), strict single-folder assignment (`Work`, `Ideas`, `Todos`, `Journal`, or `Uncategorized`), and confidence score parsing.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/note_classifier_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/note_classifier_test.dart)
      - Cases:
        1. ChatML prompt formats system, user, and assistant tokens correctly.
        2. Filler words ("um", "uh", "you know") stripped from corrected text.
        3. Valid JSON with single folder parses into `NoteClassificationResult`.
        4. Confidence scores parse into normalized percentages (0.0 to 1.0).
        5. Invalid or multi-folder slash string defaults to single best folder or `Uncategorized`.
    - **Widget Tests**:
      - N/A — Natural language classification logic.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/note_classifier_test.dart`

- [x] **TASK-021: Granular LLM Configuration & Stateless KV Cache Purging**
  - **Area**: `lib/features/ai_processing/llm_config.dart`, `llm_service.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr5-on-device-llm-post-processing--categorization`](./PRODUCT_SPEC.md#fr5-on-device-llm-post-processing--categorization) (`FR5.4: Purge KV cache after every turn (clearKvCacheEveryXTurns = 1)`)
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
  - **Spec**: [`PRODUCT_SPEC.md#fr5-on-device-llm-post-processing--categorization`](./PRODUCT_SPEC.md#fr5-on-device-llm-post-processing--categorization) (`FR5.3: If parsing fails or LLM is uninitialized, fall back to heuristic keyword classifier`)
  - **Details**: Implement keyword-based heuristic classifier used as a fallback if the LLM is uninitialized or JSON parsing fails.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/llm_service_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/llm_service_test.dart)
      - Cases:
        1. Uninitialized LLM routes text through heuristic classifier.
        2. Meeting/project keywords classify into `Work`.
        3. Brainstorming keywords classify into `Ideas`.
        4. Unknown input without keywords classifies into `Uncategorized`.
    - **Widget Tests**:
      - N/A — Classification fallback logic.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/llm_service_test.dart`

---

## Milestone 5: Persistence, UI Observability & Diagnostics (In-Scope v1.0)

- [x] **TASK-023: Isar Embedded Database Note Persistence**
  - **Area**: `lib/features/notes/data/note_model.dart`, `notes_repository.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr7-local-persistence`](./PRODUCT_SPEC.md#fr7-local-persistence) (`FR7.1 & FR7.2: Processed thoughts saved to Isar database; query by recency and folder`)
  - **Details**: Create Isar `Note` schema (`id`, `rawText`, `correctedText`, indexed `folder`, `createdAt`, `originalAudioPath`) and repository with query methods.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/audio_queue_service_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/audio_queue_service_test.dart)
      - Cases:
        1. Notes repository saves note object with correct text, folder, and timestamp.
        2. Note can be retrieved by id and by folder.
    - **Widget Tests**:
      - N/A — Database repository layer.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/audio_queue_service_test.dart`

- [x] **TASK-024: Real-Time Queue Badge in AppBar**
  - **Area**: `lib/features/home/home_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#b-core-ui-component-specifications--states`](./PRODUCT_SPEC.md#b-core-ui-component-specifications--states) (`Section 6: Pending Queue Pill (AppBar) displays X pending when count > 0; hidden when count == 0`)
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
  - **Spec**: [`PRODUCT_SPEC.md#b-core-ui-component-specifications--states`](./PRODUCT_SPEC.md#b-core-ui-component-specifications--states) (`Section 6: In-Body Processing Banner displays Processing voice thought with active spinner above Folders`)
  - **Details**: Render card above Folders indicating `Processing voice thought ($pendingCount pending)...` with active progress indicator while worker is active.
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
  - **Spec**: [`PRODUCT_SPEC.md#b-core-ui-component-specifications--states`](./PRODUCT_SPEC.md#b-core-ui-component-specifications--states) (`Section 6: Failed Items Retry Banner displays warning with Retry button when failedCount > 0`)
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
  - **Spec**: [`PRODUCT_SPEC.md#b-core-ui-component-specifications--states`](./PRODUCT_SPEC.md#b-core-ui-component-specifications--states) (`Section 6: Diagnostic tools: View System Logs, Copy Diagnostic Log Dump, and Clear Logs`)
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

## Milestone 6: In-Scope Polish & Folder Filtering (In-Scope v1.0 Pending)

- [ ] **TASK-029: Folder-Filtered Notes Screen & Navigation**
  - **Area**: `lib/features/home/home_screen.dart`, `lib/features/notes/`
  - **Spec**: [`PRODUCT_SPEC.md#fr7-local-persistence`](./PRODUCT_SPEC.md#fr7-local-persistence) (`FR7.2: The notes repository must support retrieval sorted by recency and filtered by folder`) & [`PRODUCT_SPEC.md#scenario-3-feed-review--real-time-queue-observability`](./PRODUCT_SPEC.md#scenario-3-feed-review--real-time-queue-observability) (`Scenario 3: Recent thoughts appear organized with folder pills Work, Ideas, Todos, Journal`)
  - **Details**: Implement navigation when tapping on any of the folder cards (`Ideas`, `Work`, `Journal`, `Todos`) in `HomeScreen` to display notes filtered by that selected folder, calling `notesRepository.getNotesByFolder(folder)`.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/notes/notes_repository_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/notes_repository_test.dart)
      - Cases:
        1. `getNotesByFolder('Ideas')` returns only notes with folder equal to 'Ideas'.
        2. `getNotesByFolder` returns empty list if no notes exist for folder.
    - **Widget Tests**:
      - File: [`test/features/home/folder_navigation_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/folder_navigation_test.dart)
      - Cases:
        1. Tapping 'Ideas' folder card navigates to filtered screen showing 'Ideas' header.
        2. Filtered screen displays only notes matching 'Ideas'.
        3. Back button returns to `HomeScreen`.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/folder_navigation_test.dart`

- [ ] **TASK-030: Automated Capture Latency (<5ms Budget) Benchmark Verification**
  - **Area**: `test/benchmark/capture_latency_benchmark_test.dart`, `lib/features/ai_processing/batch_pipeline_service.dart`
  - **Spec**: [`PRODUCT_SPEC.md#d-non-functional-requirements-nfr`](./PRODUCT_SPEC.md#d-non-functional-requirements-nfr) (`NFR Latency: Audio Capture Dispatch < 5ms from trigger release to queue handoff`)
  - **Details**: Implement automated benchmark test measuring elapsed duration from `stopRecordingAndProcess()` trigger call to queue handoff completion, asserting execution completes in under 5ms.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/benchmark/capture_latency_benchmark_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/benchmark/capture_latency_benchmark_test.dart)
      - Cases:
        1. Measures 100 iterations of `stopRecordingAndProcess()`.
        2. Computes P95 and asserts P95 duration is strictly < 5 milliseconds.
    - **Widget Tests**:
      - N/A — Benchmark execution test.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/benchmark/capture_latency_benchmark_test.dart`

---

## Milestone 7: Thought Lifecycle & Feed State Transparency (In-Scope Pending)

- [ ] **TASK-031: Persistent Queue Hydration & Cold-Start State Recovery**
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

- [ ] **TASK-032: Optimistic Capture Feed Item & Audio Playback Integration**
  - **Area**: `lib/features/notes/presentation/thought_card.dart`, `lib/features/notes/note_model.dart`, `lib/features/home/home_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr9-thought-lifecycle-states--feed-presentation`](./PRODUCT_SPEC.md#fr9-thought-lifecycle-states--feed-presentation) (`FR9.1: Optimistically insert entry with pastel yellow background, FR9.2: Leading audio playback button`)
  - **Details**: When a recording completes, immediately insert a placeholder note row with current timestamp, pastel yellow background (`#FEF3C7` / `#78350F`), and animated shimmer text. Replace the 3-line icon on the left with an interactive `[ ▶ Play Audio ]` button allowing immediate playback of raw PCM/WAV audio while processing.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/notes/note_lifecycle_model_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/note_lifecycle_model_test.dart)
      - Cases:
        1. `Note` model instantiation supports `ThoughtState.enqueued` with `audioFilePath`.
        2. Audio player controller toggles play and pause on local file path.
    - **Widget Tests**:
      - File: [`test/features/home/optimistic_thought_card_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/optimistic_thought_card_test.dart)
      - Cases:
        1. Renders pastel yellow background for enqueued thoughts.
        2. Tapping play icon toggles playback state without navigating away.
        3. Shimmer sub-text renders while state is enqueued.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/optimistic_thought_card_test.dart`

- [ ] **TASK-033: Processed Blue & Failed Red Card States with Failure Handling**
  - **Area**: `lib/features/notes/presentation/thought_card.dart`, `lib/features/notes/presentation/failed_retry_card.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr9-thought-lifecycle-states--feed-presentation`](./PRODUCT_SPEC.md#fr9-thought-lifecycle-states--feed-presentation) (`FR9.3: Transition to soft blue upon completion, FR9.6: Failed red state with playable audio and 1-tap retry`)
  - **Details**: Implement dynamic card transition from Yellow to Soft Blue (`#DBEAFE` / `#1E3A8A`) upon successful STT and categorization. If inference fails, transition to Soft Red (`#FEE2E2` / `#7F1D1D`), display explicit error reason, preserve raw audio playback, and provide a 1-tap `Retry` button that resets queue status.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/notes/note_state_transition_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/note_state_transition_test.dart)
      - Cases:
        1. State updates from `enqueued` to `processed` upon worker completion.
        2. State updates to `failed` with error description when worker throws.
        3. Retrying failed item resets status to `pending`.
    - **Widget Tests**:
      - File: [`test/features/home/thought_card_states_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/thought_card_states_test.dart)
      - Cases:
        1. Processed thought card displays soft blue background and folder badge.
        2. Failed thought card displays soft red background and `Retry` button.
        3. Tapping `Retry` fires retry callback.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/thought_card_states_test.dart`

- [ ] **TASK-034: Inline Text Editing & 1-Tap Category Dropdown Reassignment**
  - **Area**: `lib/features/notes/presentation/thought_card.dart`, `lib/features/notes/notes_repository.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr9-thought-lifecycle-states--feed-presentation`](./PRODUCT_SPEC.md#fr9-thought-lifecycle-states--feed-presentation) (`FR9.4: Category dropdown reassignment, FR9.5: Inline text editing`)
  - **Details**: Add an inline editing mode or quick-sheet on thought cards allowing direct text edits saved to Isar database. Add a dropdown/picker to the category badge (`[ 💼 Work ▾ ]`) to reassign the folder in 1 tap.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/notes/notes_repository_edit_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/notes_repository_edit_test.dart)
      - Cases:
        1. `updateNoteText(id, newText)` persists updated text to database.
        2. `updateNoteFolder(id, newFolder)` persists updated folder to database.
    - **Widget Tests**:
      - File: [`test/features/home/thought_card_interaction_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/thought_card_interaction_test.dart)
      - Cases:
        1. Tapping edit icon toggles inline text editor and saves changes on submit.
        2. Tapping category badge opens category dropdown picker.
        3. Selecting new category invokes update callback and updates pill label.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/thought_card_interaction_test.dart`

- [ ] **TASK-035: Unread / Viewed Thought Status Tracking & Triage Filter**
  - **Area**: `lib/features/notes/note_model.dart`, `lib/features/home/home_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr9-thought-lifecycle-states--feed-presentation`](./PRODUCT_SPEC.md#fr9-thought-lifecycle-states--feed-presentation) (`FR9.7: isRead/isViewed flag, electric blue unread dot, unread filter chip`)
  - **Details**: Add `isRead` boolean field to Note model (default: false). Render a subtle electric blue indicator dot (`•`) on unreviewed cards. Add an `Unread (X)` filter chip to the top carousel that isolates unread items. Tapping a card marks it as read.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/notes/note_read_status_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/note_read_status_test.dart)
      - Cases:
        1. New notes are created with `isRead = false`.
        2. `markAsRead(id)` updates note in database.
        3. `getUnreadNotes()` queries only notes where `isRead == false`.
    - **Widget Tests**:
      - File: [`test/features/home/unread_triage_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/unread_triage_test.dart)
      - Cases:
        1. Unread cards display electric blue dot beside timestamp.
        2. Tapping unread card clears indicator dot.
        3. Selecting `Unread` filter chip shows only unread notes.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/unread_triage_test.dart`

- [ ] **TASK-036: Hardware-Accelerated 60/120fps Smooth Progress Indicator**
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

## Milestone 8: Lock Screen Capture & Thermal-Aware Scheduling (In-Scope Pending)

- [ ] **TASK-037: Persistent Lock Screen Notification Voice Record Action**
  - **Area**: `android/app/src/main/kotlin/com/eudemonia/eudemonia/EudemoniaForegroundService.kt`
  - **Spec**: [`PRODUCT_SPEC.md#fr10-lock-screen--notification-center-capture-trigger`](./PRODUCT_SPEC.md#fr10-lock-screen--notification-center-capture-trigger) (`FR10.1: Action button Record Thought, FR10.2: Toggle without screen unlock, FR10.3: Live timer and stop action`)
  - **Details**: Add `NotificationCompat.Action` with a `[ 🎙️ Record Thought ]` button to the ongoing foreground service notification. Tapping it starts audio recording directly from lock screen, updates notification to active recording mode with timer, and exposes `[ ⏹ Stop & Save ]` action.
  - **Verification**:
    - **Unit Tests**:
      - File: [`android/app/src/test/kotlin/com/eudemonia/eudemonia/NotificationCaptureActionTest.kt`](file:///Users/harshmavani/Documents/Eudemonia/android/app/src/test/kotlin/com/eudemonia/eudemonia/NotificationCaptureActionTest.kt)
      - Cases:
        1. Foreground notification builder includes `ACTION_START_CAPTURE` action.
        2. Receiving start action triggers `AudioRecordingService` and updates notification with stop action.
        3. Receiving stop action stops recording and hands off to queue.
    - **Widget Tests**:
      - N/A — Native Android foreground notification component.
    - **Integration / Command Tests**:
      - `cd android && ./gradlew :app:testDebugUnitTest`

- [ ] **TASK-038: Thermal & Low-Memory Headroom Gating for LLM Inference**
  - **Area**: `android/app/src/main/kotlin/com/eudemonia/eudemonia/ThermalStatusPlugin.kt`, `lib/features/ai_processing/adaptive_queue_coordinator.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr12-thermal--resource-aware-adaptive-queue-gating`](./PRODUCT_SPEC.md#fr12-thermal--resource-aware-adaptive-queue-gating) (`FR12.1-FR12.4: Thermal status query, defer LLM on severe thermal, auto-resume`)
  - **Details**: Implement platform channel querying Android `PowerManager.getThermalHeadroom()` and `OnThermalStatusChangedListener`. In `AudioQueueService`, never block STT; defer heavy LLM classification into an adaptive backoff queue when device is hot (`THERMAL_STATUS_SEVERE`) or RAM <300MB, auto-resuming when cool.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/thermal_gated_queue_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/thermal_gated_queue_test.dart)
      - Cases:
        1. Queue executes STT transcription regardless of thermal status.
        2. Severe thermal status pauses LLM classification step and marks item cooling.
        3. Thermal recovery to normal resumes deferred LLM turn.
    - **Widget Tests**:
      - N/A — Queue coordination logic.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/thermal_gated_queue_test.dart`

- [ ] **TASK-039: Settings 24-Hour Battery Impact & Memory Lifecycle Graphs**
  - **Area**: `lib/features/settings/presentation/battery_memory_telemetry_chart.dart`, `lib/features/settings/settings_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr13-system-observability--telemetry-visualizers`](./PRODUCT_SPEC.md#fr13-system-observability--telemetry-visualizers) (`FR13.1: 24h battery consumption curve, FR13.2: Memory lifecycle timeline graph`)
  - **Details**: Render animated sparkline charts in Settings showing real 24-hour battery consumption attributed to Eudemonia (<2.5% benchmark) and RAM lifecycle timeline showing baseline (<60MB), sequential load spikes (~1.6GB), and eviction drops.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/settings/telemetry_data_source_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/settings/telemetry_data_source_test.dart)
      - Cases:
        1. Telemetry repository records timestamped memory samples.
        2. Computes 24h battery usage percentage from power manager stats.
    - **Widget Tests**:
      - File: [`test/features/settings/telemetry_charts_ui_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/settings/telemetry_charts_ui_test.dart)
      - Cases:
        1. Battery sparkline renders within container bounds on 360dp screens.
        2. Memory lifecycle curve displays baseline and peak annotations.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/settings/telemetry_charts_ui_test.dart`

---

## Milestone 9: Thought Synthesis & Clustering Engine (In-Scope Pending)

- [ ] **TASK-040: Recency & Context-Aware Auto-Clubbing Pipeline**
  - **Area**: `lib/features/ai_processing/note_clustering_service.dart`, `lib/features/ai_processing/batch_pipeline_service.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr11-thought-synthesis--clustering-clubbing`](./PRODUCT_SPEC.md#fr11-thought-synthesis--clustering-clubbing) (`FR11.1: Auto-clubbing of consecutive disjoint recordings within temporal window`)
  - **Details**: Implement clustering service that checks recent thoughts within 45 minutes for semantic continuity. If topic affinity is confirmed by on-device LLM, synthesizes a consolidated note while preserving origin sub-note IDs.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/note_clustering_service_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/note_clustering_service_test.dart)
      - Cases:
        1. Notes outside temporal window (>45m) are not auto-clubbed.
        2. Two notes with high contextual overlap are clustered into a synthesized note.
        3. Two unrelated notes within window remain separate.
    - **Widget Tests**:
      - N/A — AI clustering pipeline.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/note_clustering_service_test.dart`

- [ ] **TASK-041: Multi-Select Mode & Manual "Club Thoughts" Action**
  - **Area**: `lib/features/home/home_screen.dart`, `lib/features/notes/presentation/multi_select_action_bar.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr11-thought-synthesis--clustering-clubbing`](./PRODUCT_SPEC.md#fr11-thought-synthesis--clustering-clubbing) (`FR11.4: Manual multi-select mode with floating Club Thoughts action`)
  - **Details**: Implement long-press selection mode on thought cards. Display circular selection checkboxes and bottom floating bar: `[ X Selected ] [ 🧩 Club Thoughts ]`. Tapping button invokes LLM synthesis turn across selected thoughts.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/notes/multi_select_coordinator_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/multi_select_coordinator_test.dart)
      - Cases:
        1. Toggling note selection adds/removes ID from active selection set.
        2. Clearing selection exits selection mode.
    - **Widget Tests**:
      - File: [`test/features/home/multi_select_action_bar_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/multi_select_action_bar_test.dart)
      - Cases:
        1. Long pressing thought card renders selection checkboxes.
        2. Floating bar displays count of selected items.
        3. Tapping "Club Thoughts" invokes clubbing callback with selected IDs.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/multi_select_action_bar_test.dart`

- [ ] **TASK-042: Sage Green Synthesized Thought Card & Origin Audit View**
  - **Area**: `lib/features/notes/presentation/synthesized_thought_card.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr11-thought-synthesis--clustering-clubbing`](./PRODUCT_SPEC.md#fr11-thought-synthesis--clustering-clubbing) (`FR11.2: Sage green card, FR11.3: Origin audit view preserving sub-notes and audio`)
  - **Details**: Build presentational widget for clubbed thoughts using sage green token (`#DCFCE7` / `#14532D`). Include expandable accordion displaying all origin raw thoughts, their individual timestamps, and audio playback buttons.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/notes/synthesized_note_model_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/synthesized_note_model_test.dart)
      - Cases:
        1. Synthesized note holds references to list of child note IDs.
        2. Origin child notes retain original audio paths and timestamps.
    - **Widget Tests**:
      - File: [`test/features/notes/synthesized_thought_card_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/synthesized_thought_card_test.dart)
      - Cases:
        1. Renders sage green background and `[ 🧩 Clubbed Note ]` badge.
        2. Tapping origin accordion expands list of constituent thoughts.
        3. Sub-thought audio buttons trigger respective audio playback.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/notes/synthesized_thought_card_test.dart`

---

## Milestone 10: The Action Engine & Emotional Climate (In-Scope Pending)

- [ ] **TASK-043: Action Item & Commitment Extraction Pipeline**
  - **Area**: `lib/features/ai_processing/note_classifier.dart`, `lib/features/notes/action_item_model.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr14-the-action-engine-tasks--commitments`](./PRODUCT_SPEC.md#fr14-the-action-engine-tasks--commitments) (`FR14.1: Extract action items, due dates, urgency`)
  - **Details**: Enhance LLM prompt schema to extract actionable commitments, detecting task description, temporal anchors (due date/time), and urgency level (Normal, High). Store extracted tasks in Isar database linked to origin note.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/action_item_extraction_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/action_item_extraction_test.dart)
      - Cases:
        1. Parses structured JSON response extracting task description and temporal anchor.
        2. Classifies urgent tasks with High urgency flag.
        3. Returns empty action item list for non-actionable journal thoughts.
    - **Widget Tests**:
      - N/A — LLM parsing logic.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/action_item_extraction_test.dart`

- [ ] **TASK-044: Action Center UI & Local Reminder Dispatch**
  - **Area**: `lib/features/notes/presentation/action_center_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr14-the-action-engine-tasks--commitments`](./PRODUCT_SPEC.md#fr14-the-action-engine-tasks--commitments) (`FR14.2: Action center with checkboxes and local calendar/reminder intent`)
  - **Details**: Implement Action Center screen displaying pending commitments with checkboxes, urgency tags, and origin thought links. Include 1-tap dispatch to Android system calendar/reminders via local intent.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/notes/action_repository_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/action_repository_test.dart)
      - Cases:
        1. Toggling checkbox updates `isCompleted` in local database.
        2. Filters pending versus completed actions.
    - **Widget Tests**:
      - File: [`test/features/notes/action_center_ui_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/action_center_ui_test.dart)
      - Cases:
        1. Renders pending task cards with date tags and urgency chips.
        2. Tapping checkbox marks task completed with strikethrough styling.
        3. Tapping calendar icon fires intent dispatch callback.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/notes/action_center_ui_test.dart`

- [ ] **TASK-045: Journal Emotional Valence & Cognitive Energy Scoring**
  - **Area**: `lib/features/ai_processing/note_classifier.dart`, `lib/features/notes/mind_climate_model.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr15-the-emotional-climate--mind-heatmap`](./PRODUCT_SPEC.md#fr15-the-emotional-climate--mind-heatmap) (`FR15.1: Valence -1.0 to +1.0 and cognitive energy scoring for Journal entries`)
  - **Details**: In `NoteClassifier`, evaluate thoughts assigned to `Journal` category for psychological valence (-1.0 to +1.0) and cognitive energy (Low/High). Store scoring in note metadata.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/valence_scoring_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/valence_scoring_test.dart)
      - Cases:
        1. Extracts valence float between -1.0 and +1.0 from structured output.
        2. Assigns `CognitiveEnergy.high` for creative breakthroughs or energized speech.
        3. Clamps out-of-range valence scores safely to [-1.0, 1.0].
    - **Widget Tests**:
      - N/A — AI classification metadata logic.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/valence_scoring_test.dart`

- [ ] **TASK-046: Mind Climate Heatmap Visualizer**
  - **Area**: `lib/features/notes/presentation/mind_climate_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr15-the-emotional-climate--mind-heatmap`](./PRODUCT_SPEC.md#fr15-the-emotional-climate--mind-heatmap) (`FR15.2: Weekly/monthly emotional transition heatmap`)
  - **Details**: Build Mind Climate screen rendering a weekly/monthly calendar heatmap color-coded by daily emotional valence (Green = Constructive/Joy, Yellow = Neutral, Violet = Depleted/Frustrated). Include daily energy breakdown and 1-tap 2-minute Coherence Breathing button.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/notes/mind_climate_calculator_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/mind_climate_calculator_test.dart)
      - Cases:
        1. Aggregates daily thought valence into average daily score.
        2. Identifies dominant weekly cognitive climate.
    - **Widget Tests**:
      - File: [`test/features/notes/mind_climate_screen_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/mind_climate_screen_test.dart)
      - Cases:
        1. Renders 7-day calendar row with color-coded valence chips.
        2. Tapping a day chip displays thoughts captured on that day.
        3. Tapping Coherence Breath button triggers breathing session callback.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/notes/mind_climate_screen_test.dart`
