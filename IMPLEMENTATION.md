# IMPLEMENTATION.md — Eudemonia Deep Technical Reference & Evolution History

> [!NOTE]
> **LIVING BLUEPRINT NOTICE**: This document represents a point-in-time snapshot of the system architecture and its current implementation mechanics. It is **NOT** an immutable dogma or absolute truth set in stone.
>
> **Agent Operating Directive**:
> - Treat this document as a current blueprint, not an unchangeable constraint.
> - When touching any subsystem, **always question it, audit it, and seek to improve it** rather than blindly conforming to past patterns.
> - Whenever you modify, refactor, or evolve a subsystem to meet new requirements, **you must update this document** to ensure the blueprint accurately reflects the latest codebase.

---
qqq
## Table of Contents
1. [Subsystem Architecture & Current Implementation](#1-subsystem-architecture--current-implementation)
   - [A. Hardware Trigger & Native Android Layer](#a-hardware-trigger--native-android-layer)
   - [B. Background Persistence & Permissions](#b-background-persistence--permissions)
   - [C. Zero-Latency Audio Queue & Dispatch](#c-zero-latency-audio-queue--dispatch)
   - [D. AI Model Lifecycle & Memory Management](#d-ai-model-lifecycle--memory-management)
   - [E. Speech-to-Text & LLM Classification Pipeline](#e-speech-to-text--llm-classification-pipeline)
   - [F. Local Storage & Isar Persistence](#f-local-storage--isar-persistence)
   - [G. User Interface & State Management](#g-user-interface--state-management)
   - [H. Diagnostic Telemetry & Rotating Logging](#h-diagnostic-telemetry--rotating-logging)
2. [Chronicle of Issues, Root Causes & Fixes](#2-chronicle-of-issues-root-causes--fixes)
   - [1. Volume Button Runaway & Unhandled Repeats](#1-volume-button-runaway--unhandled-repeats)
   - [2. Multi-Folder Tagging & Language Correction](#2-multi-folder-tagging--language-correction)
   - [3. Background Process Hibernation & Simultaneous Permissions](#3-background-process-hibernation--simultaneous-permissions)
   - [4. UI Layout Overflows & Material Ink Splash Contract Violations](#4-ui-layout-overflows--material-ink-splash-contract-violations)
   - [5. Device Screen Blackouts, OOM Kills & Haptic Latency](#5-device-screen-blackouts-oom-kills--haptic-latency)
   - [6. Rogue Background Activity Launches](#6-rogue-background-activity-launches)
   - [7. Worker Failure: STT Service Not Initialized & Test Double False Positives](#7-worker-failure-stt-service-not-initialized--test-double-false-positives)
   - [8. Disappearing Pending Counts & Broadcast Stream Loss](#8-disappearing-pending-counts--broadcast-stream-loss)

---

## 1. Subsystem Architecture & Current Implementation

### A. Hardware Trigger & Native Android Layer
- **Location**: `android/app/src/main/kotlin/com/eudemonia/eudemonia/`
- **Files**:
  - `ButtonInterceptorService.kt`: Android `AccessibilityService` running in an isolated process (`:interceptor`).
  - `VolumeButtonCoordinator.kt`: State machine managing key events, dual-press windows, and repeating volume steps.
  - `TriggerDebouncer.kt`: Shared thread-safe 500ms cooldown debouncer.
  - `MainActivity.kt`: Flutter activity establishing the `com.eudemonia/hardware_buttons` `MethodChannel`.
- **Mechanics**:
  1. `ButtonInterceptorService` intercepts `KEYCODE_VOLUME_UP` and `KEYCODE_VOLUME_DOWN`.
  2. If only one button is pressed or held, `VolumeButtonCoordinator` dispatches `audioManager.adjustSuggestedStreamVolume(..., FLAG_SHOW_UI)`, transparently preserving system volume changes with smooth repetition (`repeatIntervalMs = 110L`, `initialRepeatDelayMs = 300L`).
  3. When both buttons are depressed within a 50ms window (`dualPressWindowMs = 50L`):
     - An instant native haptic pulse is triggered directly via `Vibrator` / `VibratorManager` (`VibrationEffect.createWaveform(longArrayOf(0, 40, 60, 40), -1)`).
     - An explicit broadcast (`com.eudemonia.eudemonia.HARDWARE_TRIGGER`) is sent with the current device lock state (`isLocked`).
  4. Both `MainActivity` and `EudemoniaForegroundService` listen for the trigger broadcast, pass it through `TriggerDebouncer.shared.tryTrigger()` (cooldown 500ms), and invoke the Flutter method `onHardwareTrigger`.

### B. Background Persistence & Permissions
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
  3. **UI Coordination**:
     - `BackgroundPermissionService` queries both permissions simultaneously via `MethodChannel`.
     - `showSimultaneousPermissionModal()` provides an educational bottom sheet guiding the user to grant both requirements in one flow.
     - Standardized status badges: **Enabled** (Green) and **Disabled** (Amber).

### C. Zero-Latency Audio Queue & Dispatch
- **Files**:
  - `lib/features/ai_processing/batch_pipeline_service.dart`
  - `lib/features/ai_processing/audio_queue_service.dart`
  - `lib/features/ai_processing/audio_queue_item.dart`
- **Mechanics**:
  1. **Decoupled Recording Capture**:
     - `BatchPipelineService.startRecording()` starts microphone capture with 0ms delay.
     - `BatchPipelineService.stopRecordingAndProcess()` stops audio capture and immediately dispatches the recorded WAV path to `AudioQueueService.enqueue()`. The call completes in **<5ms**, immediately returning control to the UI.
  2. **FIFO Disk Persistence**:
     - Enqueued items are serialized to `${appDocumentsDir}/queue/queue.json` as `AudioQueueItem` objects.
     - Status progression: `pending` -> `transcribing` -> `categorizing` -> `completed` (or `failed`).
  3. **Reactive UI State Management**:
     - Count tracking is managed via Riverpod 3 `NotifierProvider<PendingQueueCountNotifier, int>` and `NotifierProvider<FailedQueueCountNotifier, int>`.
     - `onQueueChanged` callbacks update synchronous state notifiers immediately, avoiding dropped stream events.
  4. **Failure Recovery**:
     - If transcription or categorization fails, the item is marked `failed` with an `errorMessage`.
     - `retryFailed()` resets all failed items back to `pending` and restarts processing without blocking incoming thoughts.

### D. AI Model Lifecycle & Memory Management
- **Files**:
  - `lib/features/ai_processing/model_lifecycle_manager.dart`
  - `lib/features/ai_processing/llm_config.dart`
- **Mechanics**:
  1. **Lifecycle State Machine**:
     - Three discrete states: `unloaded` (<60 MB RAM), `loading`, and `ready` (~1.6 GB RAM).
  2. **Sequential Model Loading**:
     - To prevent RAM allocation spikes above physical memory thresholds, `ensureModelsLoaded()` loads models sequentially:
       - Step 1: Sherpa-ONNX Parakeet v3 STT model (~600 MB).
       - Step 2: Qwen-2.5 1.5B GGUF LLM model (~1.0 GB).
     - Concurrent callers share an active `Completer<void>`, ensuring thread-safe idempotency.
  3. **Inactivity TTL Eviction**:
     - Default TTL: 3 minutes (`modelInactivityTtl`).
     - Every completed queue item calls `touch()`, restarting the 3-minute timer.
     - Upon expiry, `evictModels()` disposes the native C++ handles for both STT and LLM, freeing ~1.6 GB of RAM and restoring baseline memory footprint to <60 MB.
  4. **Proactive Pre-Warming**:
     - `warmupOnRecordingStart()` begins loading models in the background the moment the user starts recording, ensuring models are ready by the time audio is captured.

### E. Speech-to-Text & LLM Classification Pipeline
- **Files**:
  - `lib/features/ai_processing/stt_service.dart`
  - `lib/features/ai_processing/llm_service.dart`
  - `lib/features/ai_processing/note_classifier.dart`
- **Mechanics**:
  1. **STT Transcription**:
     - Powered by `sherpa_onnx` using an offline recognizer configured with Parakeet CTC/Transducer models.
  2. **Prompt Engineering & Single-Folder Classification**:
     - ChatML prompt instructs Qwen 2.5 Instruct to perform:
       1. *Language Correction*: Grammar, capitalization, punctuation, and removal of conversational filler words (*"um"*, *"uh"*, *"like"*).
       2. *Classification*: Categorize into exactly **one** allowed folder (`Work`, `Ideas`, `Todos`, `Journal`, or `Uncategorized`).
       3. *JSON Schema Enforcement*: Output strictly structured JSON containing `corrected_text`, `folder`, `confidence_scores`, and `reasoning`.
  3. **Stateless Turn Execution & KV Cache Hygiene**:
     - `LLMConfig` defines `kvCacheMaxSize` (2048), `inputTokenLimit` (1536), `maxOutputTokens` (256), and `clearKvCacheEveryXTurns` (default `1`).
     - After every inference turn, `LLMService.clearKvCache()` invokes `_llama.disposeScope()` to release native KV tensor allocations.
  4. **Heuristic Fallback Classifier**:
     - If the LLM is uninitialized or in rapid unit-test environments, `NoteClassifier.classifyWithHeuristic()` evaluates keyword dictionaries to assign confidence scores and folder tags.

### F. Local Storage & Isar Persistence
- **Files**:
  - `lib/features/notes/data/note_model.dart`
  - `lib/features/notes/data/notes_repository.dart`
- **Mechanics**:
  - Managed with Isar database.
  - `Note` schema includes `id`, `rawText`, `correctedText`, indexed `folder`, `createdAt`, and `originalAudioPath`.
  - Notes are saved upon successful categorization; temporary audio files can be preserved or cleaned up.

### G. User Interface & State Management
- **Files**:
  - `lib/features/home/home_screen.dart`
- **Mechanics**:
  - **AppBar Queue Pill**: Displays real-time `X pending` pill with a mini-spinner whenever thoughts are in queue.
  - **In-Body Processing Banner**: Prominent card above the Folders section displaying `"Processing voice thought..."` with circular progress.
  - **In-Body Failed Banner**: Warning banner displaying `"X thought(s) failed to process"` with a `"Retry"` button invoking `retryFailed()`.
  - **Ambient Permissions Alert**: Automatically warns the user if Accessibility or Battery Exemption permissions are missing, auto-dismissing via `WidgetsBindingObserver` when granted.

### H. Diagnostic Telemetry & Rotating Logging
- **Files**:
  - `lib/core/logger/app_logger.dart`
  - `lib/features/settings/settings_screen.dart`
- **Mechanics**:
  - `AppLogger` logs hardware triggers, state transitions, audio queue steps, and exceptions to disk at `${appDocumentsDir}/logs/app_logs.txt`.
  - Enforces a 2MB rotating file cap to prevent unbounded storage consumption.
  - `SettingsScreen` includes interactive actions to view system logs in a live modal, copy a full diagnostic dump to clipboard, or clear logs.

---

## 2. Chronicle of Issues, Root Causes & Fixes

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
