# IMPLEMENTATION.md — Eudemonia Deep Technical Reference & Evolution History

> [!NOTE]
> **LIVING BLUEPRINT NOTICE**: This document represents a point-in-time snapshot of the system architecture and its current implementation mechanics. It is **NOT** an immutable dogma or absolute truth set in stone.
>
> **Agent Operating Directive**:
> - Treat this document as a current blueprint, not an unchangeable constraint.
> - When touching any subsystem, **always question it, audit it, and seek to improve it** rather than blindly conforming to past patterns.
> - Whenever you modify, refactor, or evolve a subsystem to meet new requirements, **you must update this document** to ensure the blueprint accurately reflects the latest codebase.

---

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
   - [9. Concurrent Queue Execution Race Condition & Retry Completer](#9-concurrent-queue-execution-race-condition--retry-completer)
   - [10. Mobile Memory Safety & Persistent Cold-Start Hydration](#10-mobile-memory-safety--persistent-cold-start-hydration)

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
  - `lib/features/notes/note_model.dart`
- **Mechanics**:
  - Managed with Isar database.
  - `Note` schema includes `id`, `rawText`, `correctedText`, indexed `folder`, `createdAt`, and `originalAudioPath`.
  - **Thought Lifecycle States**: The `ThoughtState` enum (`enqueued`, `processed`, `failed`, `synthesized`) represents the lifecycle progression of captured thoughts.
  - **Zero-Migration Schema Compatibility**: Fields `state`, `isRead`, and `failureReason` use the `@ignore` annotation, providing rich feed presentation and state handling without invalidating existing database schemas or requiring complex migration scripts.
  - **Repository Operations**: `NotesRepository` supports `saveNote`, `getNoteById`, `getAllNotes`, `getNotesByFolder`, `searchNotes`, `updateNoteText`, `updateNoteFolder`, `markAsRead`, and `getUnreadNotes`, with transparent fallback to in-memory storage during isolated unit and widget tests.

### G. User Interface & State Management
- **Files**:
  - [`lib/features/home/home_screen.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/home/home_screen.dart)
  - [`lib/features/notes/presentation/thought_card.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/notes/presentation/thought_card.dart)
  - [`lib/features/notes/audio_playback_controller.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/notes/audio_playback_controller.dart)
  - [`lib/features/home/presentation/smooth_processing_indicator.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/home/presentation/smooth_processing_indicator.dart)
  - [`lib/features/settings/settings_screen.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/settings/settings_screen.dart)
  - [`UX.md`](file:///Users/harshmavani/Documents/Eudemonia/UX.md) (Exhaustive design tokens, component sandbox specs & widget snippets)
- **Mechanics**:
  - **Flutter Code-as-Design (Component Sandbox)**: UI/UX prototyping and conversational modifications with AI agents occur in the isolated [`previews/`](file:///Users/harshmavani/Documents/Eudemonia/previews) sandbox (`flutter run -t previews/main_preview.dart`), leaving production `lib/` 100% free of prototype boilerplate while guaranteeing zero translation loss.
  - **ThoughtCard Lifecycle Rendering**:
    - *Enqueued*: Light pastel yellow background (`#FEF3C7`), animated shimmer subtext, and active spinner.
    - *Processed*: Soft blue background (`#DBEAFE`), category badge with 1-tap dropdown reassignment, inline text editor, and raw audio playback.
    - *Failed*: Soft red background (`#FEE2E2`), explicit failure message, 1-tap `Retry` button, and audio playback.
    - *Synthesized*: Soft mint background (`#DCFCE7`) for clubbed or synthesized thoughts.
  - **Raw Audio Playback Controller**: Powered by Riverpod 3 `NotifierProvider<AudioPlaybackController, AudioPlaybackState>`, managing play/pause state for raw WAV audio files without navigating away from the feed.
  - **Hardware-Accelerated Smooth Progress Indicator**: `SmoothProcessingIndicator` uses a GPU-accelerated `CustomPainter` with an internal `RepaintBoundary` and ticking `AnimationController`, guaranteeing locked 60/120fps sweep fluidity even during heavy CPU-bound background inference.
  - **Unread Thought Status & Triage Filter**: Unreviewed processed cards feature a subtle electric blue indicator dot (`•`). Tapping the card marks it as read and clears the indicator. Filter chips (`All`, `Unread (X)`) above the feed allow instantaneous triage.
  - **AppBar Queue Pill**: Displays real-time `X pending` pill with `SmoothProcessingIndicator` whenever thoughts are in queue (`pendingCount > 0`).
  - **In-Body Processing Banner**: Prominent card above the Folders section displaying `"Processing voice thought..."` with `SmoothProcessingIndicator`.
  - **In-Body Failed Banner**: Warning banner displaying `"X thought(s) failed to process"` with a `"Retry"` button invoking `retryFailed()`.
  - **Ambient Permissions Alert**: Automatically warns the user if Accessibility or Battery Exemption permissions are missing, auto-dismissing via `WidgetsBindingObserver` when granted.
  - **Instant Capture HUD**: Ultra-low-latency (<5ms) bottom indicator with pulsating glow ring and soundwave visualization.

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

### 9. Concurrent Queue Execution Race Condition & Retry Completer
- **Symptom**: When retrying failed items or enqueuing rapid successive recordings, `AudioQueueService.processPending()` was triggered concurrently, causing duplicate processing loops and race conditions where item statuses jumped unpredictably.
- **Root Cause**: `AudioQueueService.processPending()` lacked an active processing completer or mutex lock. Multiple asynchronous invocations executed parallel while-loops over the same in-memory list.
- **Solution**:
  1. Implemented `Completer<void>? _processingCompleter` in `AudioQueueService`.
  2. If a processing loop is already active, subsequent calls to `processPending()` or `retryFailed()` simply await `_processingCompleter!.future`, ensuring sequential single-threaded worker passes without duplicative model invocations.

### 11. Feed Optimistic Hydration, Dedicated Audio Playback Architecture & In-Card Triage
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

