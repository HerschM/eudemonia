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
  - `MainActivity.kt`: Flutter activity establishing the `com.eudemonia/hardware_buttons` `MethodChannel`.
- **Mechanics**:
  1. `ButtonInterceptorService` intercepts `KEYCODE_VOLUME_UP` and `KEYCODE_VOLUME_DOWN`.
  2. If only one button is pressed or held, `VolumeButtonCoordinator` dispatches `audioManager.adjustSuggestedStreamVolume(..., FLAG_SHOW_UI)`, transparently preserving system volume changes with smooth repetition (`repeatIntervalMs = 110L`, `initialRepeatDelayMs = 300L`).
  3. When both buttons are depressed within a 50ms window (`dualPressWindowMs = 50L`):
     - An instant native haptic pulse is triggered directly via `Vibrator` / `VibratorManager`: single crisp pulse for start recording (`createOneShot(45)`), and distinct double-pulse completion buzz for stop recording (`createWaveform(longArrayOf(0, 30, 50, 30), -1)`).
     - An explicit broadcast (`com.eudemonia.eudemonia.HARDWARE_TRIGGER`) is sent with the current device lock state (`isLocked`).
  4. Both `MainActivity` and `EudemoniaForegroundService` listen for the trigger broadcast, pass it through `TriggerDebouncer.shared.tryTrigger()` (cooldown 500ms), and invoke the Flutter method `onHardwareTrigger`.

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
  3. **UI Coordination**:
     - `BackgroundPermissionService` queries both permissions simultaneously via `MethodChannel`.
     - `showSimultaneousPermissionModal()` provides an educational bottom sheet guiding the user to grant both requirements in one flow.
     - Standardized status badges: **Enabled** (Green) and **Disabled** (Amber).
  4. **Permanent Lock Screen Notification Banner & Capture Controller (FR10)**:
     - `EudemoniaForegroundService` maintains dynamic interactive notification action buttons:
       - Idle: Displays `[ 🎙️ Record Thought ]` (`ACTION_START_CAPTURE`).
       - Recording: Updates title to `Recording Thought...` and displays `[ ⏹ Stop & Save ]` (`ACTION_STOP_CAPTURE`).
     - `ForegroundServiceCoordinator` coordinates lock screen intents and dispatches triggers via `deliverTrigger(isLocked = true)` without requiring phone unlock.
     - Synchronized bidirectionally with Flutter via `MethodChannel("setRecordingState")` whenever recording starts or stops.

### C. Zero-Latency Audio Queue & Dispatch (FIFO Queue & Non-Blocking Worker)
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

### D. AI Model Lifecycle & Memory Management (Sequential Loading, Inactivity Eviction & <60MB Baseline)
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

### E. Speech-to-Text & LLM Classification Pipeline (Sherpa-ONNX STT & Qwen 2.5 ChatML)
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

### F. Local Storage & Isar Persistence (Collections, Schemas & Note Lifecycle)
- **Files**:
  - `lib/features/notes/data/note_model.dart`
  - `lib/features/notes/data/notes_repository.dart`
  - `lib/features/notes/note_model.dart`
- **Mechanics**:
  - Managed with Isar database.
  - `Note` schema includes `id`, `rawText`, `correctedText`, indexed `folder`, `createdAt`, `originalAudioPath`, `isRead`, `state`, and `failureReason`.
  - **Thought Lifecycle States**: The `ThoughtState` enum (`enqueued`, `processed`, `failed`, `synthesized`) represents the lifecycle progression of captured thoughts, persisted using `@Enumerated(EnumType.name)` in Isar.
  - **Durable Persistence Across Cold Starts**: `isRead`, `state`, and `failureReason` are fully persisted properties within `note_model.g.dart`. Calling `markAsRead(id)` or `saveNote(note)` updates the Isar database directly in a write transaction, guaranteeing that unread/read state and processing metadata survive process kills and phone reboots.
  - **Repository Operations**: `NotesRepository` supports `saveNote`, `getNoteById`, `deleteNote`, `getAllNotes`, `getNotesByFolder`, `searchNotes`, `updateNoteText`, `updateNoteFolder`, `markAsRead`, and `getUnreadNotes`, with transparent fallback to in-memory storage during isolated unit and widget tests.

### G. Production User Interface & State Management (`lib/features/home/`)
- **Files**:
  - [`lib/features/home/home_screen.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/home/home_screen.dart)
  - [`lib/features/notes/presentation/thought_card.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/notes/presentation/thought_card.dart)
  - [`lib/features/notes/audio_playback_controller.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/notes/audio_playback_controller.dart)
  - [`lib/features/home/presentation/smooth_processing_indicator.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/home/presentation/smooth_processing_indicator.dart)
  - [`lib/features/settings/settings_screen.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/settings/settings_screen.dart)
- **Mechanics**:
  - **Unified Reactive Feed**: `HomeScreen` synthesizes the `allThoughts` feed by watching both `recentNotesProvider` (persisted notes) and `queueItemsProvider` (in-flight & failed queue items). Newly captured audio enqueues immediately (<5ms) with `ThoughtState.enqueued` (pastel yellow, shimmer, date/time, audio play button), transitioning seamlessly to `ThoughtState.processed` (pastel blue) upon worker completion without requiring an app restart.
  - **ThoughtCard Lifecycle Rendering**:
    - *Enqueued*: Light pastel yellow background (`#FEF3C7`), animated shimmer subtext, and active spinner.
    - *Processed*: Soft blue background (`#DBEAFE`), category badge with 1-tap dropdown reassignment, inline text editor, and raw audio playback.
    - *Failed*: Soft red background (`#FEE2E2`), explicit failure message, 1-tap `Retry` button, and audio playback.
    - *Synthesized*: Soft mint background (`#DCFCE7`) for clubbed or synthesized thoughts.
  - **Dedicated Audio Playback Controller**: Powered by Riverpod 3 `NotifierProvider<AudioPlaybackController, AudioPlaybackState>` over `MethodChannel('com.eudemonia/audio_playback')`. In Kotlin, `MediaPlayer` reads private audio files via `FileInputStream(file).use { fis -> player.setDataSource(fis.fd) }`, ensuring robust audio playback without sandbox permission failures.
  - **Hardware-Accelerated Smooth Progress Indicator**: `SmoothProcessingIndicator` uses a GPU-accelerated `CustomPainter` with an internal `RepaintBoundary` and ticking `AnimationController`, guaranteeing locked 60/120fps sweep fluidity even during heavy CPU-bound background inference.
  - **Unread Thought Status & In-Card Triage**: Unreviewed processed cards feature a subtle electric blue indicator dot (`•`). Tapping the card marks it as read and clears the indicator. A horizontally scrollable chip row (`All`, `Unread (X)`, `Failed (X)`) above the feed allows instantaneous triage without `RenderFlex` overflows on narrow screens.
  - **AppBar Queue Pill**: Displays real-time `X pending` pill with `SmoothProcessingIndicator` whenever thoughts are in queue (`pendingCount > 0`).
  - **In-Card Failure Presentation**: Failed thoughts render directly as cards with `ThoughtState.failed` (soft red, failure reason, audio playback, 1-tap `[ Retry ]`), eliminating intrusive full-screen error banners.
  - **Ambient Permissions Alert**: Automatically warns the user if Accessibility or Battery Exemption permissions are missing, auto-dismissing via `WidgetsBindingObserver` when granted.

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
  - **Four-Stage Tab Bar & Zero-Suppression**:
    - `Capture (X)`: Zero-suppressed unconsumed thought count ($X = \text{unread} + \text{in-flight queue}$).
    - `Synthesis (Y)`: Zero-suppressed unconsumed session count ($Y = \text{unread clusters}$).
    - `Insights` & `Action`: Visually greyed out (`Opacity(0.38)`) and tap-intercepted to remain unclickable placeholders with friendly explanatory empty states until backend stages are activated.

### J. Production Synthesis Subsystem & Session Clustering (`lib/features/synthesis/`)
- **Files**:
  - [`lib/features/synthesis/domain/synthesis_cluster.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/synthesis/domain/synthesis_cluster.dart)
  - [`lib/features/synthesis/data/synthesis_repository.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/synthesis/data/synthesis_repository.dart)
  - [`lib/features/synthesis/presentation/synthesis_screen.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/synthesis/presentation/synthesis_screen.dart)
  - [`lib/features/synthesis/presentation/style_rewriter_sheet.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/synthesis/presentation/style_rewriter_sheet.dart)
  - [`lib/features/synthesis/presentation/note_ejection_sheet.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/synthesis/presentation/note_ejection_sheet.dart)
  - [`lib/features/synthesis/presentation/note_merge_sheet.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/synthesis/presentation/note_merge_sheet.dart)
- **Mechanics**:
  - **State Architecture**: `SynthesisRepository` extends Riverpod 3 `Notifier<List<SynthesisCluster>>` exposed via `synthesisRepositoryProvider`.
  - **Cluster Cards**:
    - Header shows sequence badge (e.g., `#S-01`), folder tag with dropdown reassignment, and unread indicator dot (`•`).
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
  - **On-Device AI Memory & Thermal Telemetry**: Live thermal headroom display, model footprint monitor, and an instant `[ Evict Models Now (<60 MB) ]` memory reclamation button.
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
