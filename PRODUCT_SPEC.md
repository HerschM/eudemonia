# PRODUCT_SPEC.md — Eudemonia Product Requirements & Specification

> **Status**: Approved / Active (v1.0.0)  
> **Target Platform**: Android (API 26+, optimized for modern Android 14/15/16)  
> **Classification**: Core Product Requirements Document (PRD) & Specification  
> **Authors**: Eudemonia Core Team  

---

## Table of Contents
1. [Executive Summary](#1-executive-summary)
2. [Problem Statement & Market Context](#2-problem-statement--market-context)
3. [Target Personas & User Scenarios](#3-target-personas--user-scenarios)
4. [Product Principles & Core Value Propositions](#4-product-principles--core-value-propositions)
5. [Scope & Requirements](#5-scope--requirements)
   - [A. In-Scope (v1.0 MVP & Active Extensions)](#a-in-scope-v10-mvp--active-extensions)
   - [B. Out-of-Scope (Explicit Non-Goals for v1.0)](#b-out-of-scope-explicit-non-goals-for-v10)
   - [C. Functional Requirements (FR)](#c-functional-requirements-fr)
   - [D. Non-Functional Requirements (NFR)](#d-non-functional-requirements-nfr)
6. [User Experience (UX) & Interaction Specifications](#6-user-experience-ux--interaction-specifications)
7. [System Architecture & Data Flow](#7-system-architecture--data-flow)
8. [Edge Cases, Error Handling & Recovery](#8-edge-cases-error-handling--recovery)
9. [Future Roadmap (v1.5 & v2.0)](#9-future-roadmap-v15--v20)
10. [Success Metrics & Quality Gates](#10-success-metrics--quality-gates)

---

## 1. Executive Summary

**Eudemonia** is an on-device, zero-friction, voice-first thought capture system for Android. It enables thinkers, creators, and professionals to record fleeting ideas instantaneously using physical hardware triggers (simultaneous volume buttons), requiring zero screen interaction. 

Unlike traditional voice memos or cloud-tethered note applications, Eudemonia captures audio in **<5ms**, queues recordings without blocking the user, transcribes speech entirely on-device, corrects conversational filler words, and categorizes thoughts into folders using local AI models. 

By eliminating UI latency, network dependencies, and cloud privacy liabilities, Eudemonia ensures that fleeting thoughts are preserved with 100% privacy, reliability, and zero cognitive overhead.

---

## 2. Problem Statement & Market Context

### The Fleeting Thought Problem
Human working memory retains fleeting thoughts for only **15 to 30 seconds** before cognitive distraction causes degradation. When an inspiration strikes while walking, driving, or working, the conventional capture workflow introduces fatal friction:
1. Reaching for the phone.
2. Unlocking via fingerprint or PIN.
3. Locating and launching a note-taking or voice-memo app.
4. Tapping a software "Record" button and waiting for the UI to initialize.
5. Manually typing tags, titles, and folders.

By the time this sequence finishes, the original nuance of the thought is diluted or lost.

### The Cloud Privacy & Latency Dilemma
Existing AI note apps (e.g., Otter, Notion AI, Whisper APIs) require uploading personal voice recordings to third-party cloud servers. This presents severe challenges:
- **Privacy Exposure**: Users hesitate to record intimate personal reflections, sensitive business ideas, or confidential discussions.
- **Network Brittleness**: Capturing ideas in elevators, subways, airplanes, or rural zones fails or lags unpredictably.
- **System Memory & Battery Bloat**: Unmanaged background listening or monolithic local models cause Android Low Memory Killer (LMK) terminations, system stutters, and screen blackouts.

---

## 3. Target Personas & User Scenarios

### Personas

| Persona | Description | Primary Needs |
| :--- | :--- | :--- |
| **The High-Velocity Thinker / Founder** | Generates 20+ raw ideas daily while commuting, in meetings, or between tasks. | Instant physical trigger without looking at the screen; automatic classification into `Work` vs `Ideas`. |
| **The Privacy-Conscious Journaler** | Uses voice for stream-of-consciousness personal journaling and reflection. | 100% offline, zero cloud leakage; automated cleanup of verbal disfluencies (*"um"*, *"like"*). |
| **The Rapid Task Capturer** | Captures urgent action items and errands on the go. | Fast capture that converts speech into clean, actionable `Todos` with zero sorting overhead. |

### Key User Scenarios

#### Scenario 1: Screen-Off / Pocket Capture
- **Context**: User is walking outdoors with phone locked in pocket. A breakthrough thought occurs.
- **Action**: User presses both volume buttons simultaneously through their pocket fabric.
- **Feedback**: A sharp dual-pulse native haptic confirms recording has started. User speaks naturally for 15 seconds.
- **Completion**: User presses both volume buttons again. A single haptic pulse confirms stop.
- **Outcome**: The audio is saved to the local queue in <5ms. The phone stays in the user's pocket. The background worker loads the on-device models, transcribes, categorizes into `Ideas`, and saves to the local database.

#### Scenario 2: Active Interruption Inside Another App
- **Context**: User is reading a document or navigating in Google Maps when an unrelated task comes to mind.
- **Action**: User triggers dual volume buttons.
- **Outcome**: Capture starts instantly without launching Eudemonia over the active navigation screen or interrupting foreground tasks. When stopped, normal volume buttons immediately resume transparent audio level control.

#### Scenario 3: Feed Review & Real-Time Queue Observability
- **Context**: User opens Eudemonia after a day of voice captures.
- **Outcome**: The AppBar displays pending processing badges (`2 pending`) if inferences are underway. Recent thoughts appear organized with folder pills (`Work`, `Ideas`, `Todos`, `Journal`). Language-corrected transcripts are displayed with clean typography, while raw audio remains accessible.

---

## 4. Product Principles & Core Value Propositions

```
┌─────────────────────────────────────────────────────────────┐
│                    EUDEMONIA PRINCIPLES                     │
├──────────────────────────────┬──────────────────────────────┤
│ 1. Zero-Latency Capture      │ Audio enqueues in <5ms;      │
│                              │ UI never blocks on AI        │
├──────────────────────────────┼──────────────────────────────┤
│ 2. Physical First            │ Hardware button trigger with │
│                              │ instant native haptics       │
├──────────────────────────────┼──────────────────────────────┤
│ 3. 100% Local & Private      │ Zero cloud dependencies;     │
│                              │ on-device STT & LLM runtimes │
├──────────────────────────────┼──────────────────────────────┤
│ 4. Single-Folder Discipline  │ Deterministic folder home;   │
│                              │ no messy multi-folder tags   │
├──────────────────────────────┼──────────────────────────────┤
│ 5. Resource Consciousness    │ Inactivity model eviction;   │
│                              │ <60MB idle memory footprint  │
└──────────────────────────────┴──────────────────────────────┘
```

1. **Zero-Latency Capture (<5ms Budget)**: Stopping audio capture must feel instantaneous. Heavy AI models must never block user interactions or hold recording gestures hostage.
2. **Physical-First Accessibility**: Physical volume keys provide tactile muscle memory that works in dark rooms, pockets, or without glancing at the screen.
3. **Absolute Privacy & Local Autonomy**: No telemetry, audio data, or text embeddings ever leave the physical handset. All STT (Sherpa-ONNX) and LLM (Qwen-2.5 1.5B GGUF) run directly on device hardware.
4. **Deterministic Single-Folder Categorization**: Every captured thought must be resolved into exactly **one** primary home (`Ideas`, `Work`, `Journal`, `Todos`, or fallback `Uncategorized`).
5. **Mobile Resource Respect**: Mobile operating systems aggressively kill memory-heavy apps. Models must load sequentially and be evicted after 3 minutes of idle time to prevent phone slowdowns and Android Low Memory Killer (LMK) kills.

---

## 5. Scope & Requirements

### A. In-Scope (v1.0 MVP & Active Extensions)
- Android physical dual-volume key trigger detection via an Accessibility Service.
- Native haptic feedback delivered directly in Android native code (<20ms).
- Volume button transparent pass-through (single clicks and holds adjust media volume normally without runaway loops).
- Decoupled FIFO audio processing queue with disk persistence and cold-start state hydration.
- On-device speech recognition via Sherpa-ONNX Parakeet v3.
- On-device language correction and single-folder categorization via quantized Qwen-2.5 1.5B GGUF.
- Local note persistence via Isar embedded database.
- Persistent background keep-alive foreground service with interactive lock screen capture action.
- Multi-state thought lifecycle feed cards (Enqueued Pastel Yellow with instant audio playback, Processed Soft Blue, Failed Soft Red, and Synthesized Sage Green).
- Interactive category reassignment dropdown and inline text editing.
- Unread / viewed thought triage tracking and filter chip.
- Thought synthesis and clustering (recency/context auto-clubbing and manual multi-select clubbing) preserving origin thoughts and audio clips.
- Thermal and low-memory adaptive queue gating to prevent device overheating.
- System transparency telemetry graphs (24h battery impact & memory lifecycle curve) in Settings.
- Hardware-accelerated 60/120fps progress indicator decoupled from inference load.
- The Action Engine: on-device action item and commitment extraction with local reminder support.
- The Emotional Climate: on-device valence/energy scoring for reflections and emotional transition heatmap.
- Simultaneous permission coordination flow (Accessibility + Battery Optimization Exemption).
- Real-time queue observability in UI (AppBar badge, in-body processing banner, failed item retry).
- Diagnostic logging system with 2MB rotating disk cap and in-app viewer.

### B. Out-of-Scope (Explicit Non-Goals for v1.0)
- Multi-tag many-to-many graph tagging (reserved for v1.5; v1.0 requires single-folder discipline with synthesis clustering).
- Cloud synchronization (Dropbox, Google Drive, iCloud) or cross-device sync.
- Real-time streaming transcription while speaking (streaming adds high memory and CPU competition during recording; batch transcription post-capture is chosen for battery efficiency).
- Multi-track audio waveform visualizer / complex DAW editing tools (direct audio playback scrubber is supported).
- iOS platform support (iOS restricts background hardware button interception).

---

### C. Functional Requirements (FR)

#### FR1: Hardware Key Trigger & Volume Safety
- **FR1.1**: The system must intercept `VOLUME_UP` and `VOLUME_DOWN` key events via an Android `AccessibilityService`.
- **FR1.2**: If both volume keys are pressed within a 50ms window (`dualPressWindowMs`), the system must trigger the thought recording toggle (start or stop).
- **FR1.3**: When a dual-press trigger is detected, the system must trigger a native vibration pattern immediately in native code without deferring to the Flutter engine.
- **FR1.4**: If only one volume button is pressed or held, the system must delegate transparently to `AudioManager.adjustSuggestedStreamVolume(..., FLAG_SHOW_UI)`, supporting initial repeat delay (300ms) and continuous repeats (110ms) without runaway loops.
- **FR1.5**: The system must enforce a 500ms cooldown (`TriggerDebouncer`) to prevent duplicate trigger cascades across receivers.

#### FR2: Non-Blocking Audio Capture
- **FR2.1**: Toggling trigger ON must begin recording uncompressed PCM/WAV audio to a temporary file immediately (<5ms).
- **FR2.2**: Toggling trigger OFF must immediately stop recording, hand off the file path to the audio queue, and dismiss the listening UI indicator within 5ms.
- **FR2.3**: Audio capture must never await model loading, network calls, or database initialization.

#### FR3: Persistent FIFO Audio Queue
- **FR3.1**: Enqueued audio files must be persisted to `${appDocumentsDir}/queue/queue.json` with unique ID, timestamp, and initial status `pending`.
- **FR3.2**: A background queue worker must process items sequentially one at a time.
- **FR3.3**: The queue service must expose real-time synchronous counts (`pendingCount` and `failedCount`) via Riverpod `NotifierProvider`.
- **FR3.4**: If a single item fails (e.g. empty audio), the worker must mark that item `failed` with an error message and proceed to process subsequent items.
- **FR3.5**: The system must provide a `retryFailed()` capability to reset all failed items back to `pending`.

#### FR4: On-Device Speech Recognition (STT)
- **FR4.1**: The queue worker must transcribe audio files using an on-device Sherpa-ONNX offline recognizer (Parakeet v3 model).
- **FR4.2**: If the audio contains no detectable speech, the system must fail gracefully with an explicit error (`No speech detected in audio recording`).

#### FR5: On-Device LLM Post-Processing & Categorization
- **FR5.1**: The system must run an on-device quantized LLM (Qwen-2.5 1.5B GGUF) via `llama_cpp_dart`.
- **FR5.2**: The prompt must perform:
  1. *Grammar & Language Correction*: Fix capitalization and punctuation, and remove conversational filler words (*"um"*, *"uh"*, *"like"*, *"you know"*).
  2. *Single-Folder Classification*: Categorize into exactly one allowed folder (`Work`, `Ideas`, `Todos`, `Journal`, or `Uncategorized`).
  3. *Confidence Scores*: Generate normalized confidence scores across all candidate folders.
- **FR5.3**: Output must be parsed from structured JSON format. If parsing fails, the system must fall back to a heuristic keyword classifier.
- **FR5.4**: The system must purge the KV cache (`_llama.disposeScope()`) after every turn (`clearKvCacheEveryXTurns = 1`) to eliminate lingering RAM consumption.

#### FR6: Model Lifecycle & Memory Management
- **FR6.1**: The system must maintain three lifecycle states: `unloaded`, `loading`, and `ready`.
- **FR6.2**: Models must be loaded **sequentially** (STT first, LLM second) to prevent simultaneous memory allocation spikes above Android Low Memory Killer thresholds.
- **FR6.3**: When idle for 3 minutes (`modelInactivityTtl`), the system must automatically unload both models from RAM, reclaiming ~1.6 GB and restoring baseline footprint to <60 MB.
- **FR6.4**: Completing an item or interacting with the queue must touch the lifecycle manager, resetting the 3-minute eviction timer.

#### FR7: Local Persistence
- **FR7.1**: Processed thoughts must be saved to an embedded local database (Isar) containing `id`, `rawText`, `correctedText`, `folder`, `createdAt`, and `originalAudioPath`.
- **FR7.2**: The notes repository must support retrieval sorted by recency and filtered by folder.

#### FR8: Background Reliability & Permissions
- **FR8.1**: The app must provide an Android Foreground Service (`EudemoniaForegroundService`) with an ongoing low-priority notification to protect the process from OS termination.
- **FR8.2**: The app must detect and request both Accessibility Service and Battery Optimization Exemption (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) simultaneously through an educational modal.
- **FR8.3**: Permission status indicators across settings and alerts must use standardized **Enabled** (Green) and **Disabled** (Amber) badges.

#### FR9: Thought Lifecycle States & Feed Presentation
- **FR9.1**: As soon as a voice recording completes and is validated as non-empty (>0.5s audio), the system must optimistically insert an entry into the feed within 5ms. The entry must display current date and time, a pastel yellow background (`#FEF3C7` / `#78350F`), and an animated shimmer sub-text (*"Transcribing & organizing..."*).
- **FR9.2**: The leading icon of the thought card must feature an interactive **Audio Playback Button** (`[ ▶ ]` / `[ ⏸ ]`), enabling the user to immediately listen to their raw captured audio even while inference is pending or failed.
- **FR9.3**: Once STT transcription, grammar correction, and categorization complete, the card must dynamically transition its background to soft blue (`#DBEAFE` / `#1E3A8A`), populating corrected text and folder tags.
- **FR9.4**: Tapping the category badge must present a quick-select dropdown or bottom sheet, allowing the user to override and reassign the folder in 1 tap.
- **FR9.5**: Users must be able to edit the corrected thought text inline or via a quick edit sheet, saving changes locally to the database.
- **FR9.6**: If transcription or post-processing fails, the card background must transition to soft red (`#FEE2E2` / `#7F1D1D`), display the failure reason directly inside the entry, keep original audio playable, and provide an explicit 1-tap **Retry** action. There must be no global top error banner; failed items must be triaged directly in the feed and filterable via a dedicated **Failed** filter chip alongside **All** and **Unread**.
- **FR9.7**: The system must track an `isRead` / `isViewed` boolean flag for each thought. Unviewed items must display a subtle electric blue unread indicator dot (`•`), and the feed must support filtering by unread thoughts.

#### FR10: Lock Screen & Notification Center Capture Trigger
- **FR10.1**: The persistent foreground service notification must host an interactive action button: `[ 🎙️ Record Thought ]`.
- **FR10.2**: Toggling the notification button must trigger start and stop of thought recording directly from the lock screen or notification shade without requiring device unlock.
- **FR10.3**: While recording is active, the notification must update dynamically to display an elapsed timer (`Recording 00:06...`) and a `[ ⏹ Stop & Save ]` action.

#### FR11: Thought Synthesis & Clustering (Clubbing)
- **FR11.1**: The system must provide an on-device long-processing auto-clubbing capability. When consecutive thoughts are recorded within a temporal window (default: 45 minutes) that share contextual continuity or topical affinity, the LLM must automatically cluster them into a single synthesized note.
- **FR11.2**: Synthesized thoughts must render with a sage green background (`#DCFCE7` / `#14532D`) and a distinct synthesis badge (`[ 🧩 Clubbed Note ]`).
- **FR11.3**: Auto-clubbing must never destroy raw thought data. A synthesized green note must provide an expandable origin audit view displaying the constituent sub-thoughts, their individual timestamps, and original audio playback buttons.
- **FR11.4**: The system must provide a manual multi-select mode in the feed. Selecting two or more notes presents a floating **"Club Thoughts"** action that forces an LLM synthesis turn across the selected items.

#### FR12: Thermal & Resource-Aware Adaptive Queue Gating
- **FR12.1**: The queue service must query Android native thermal status (`PowerManager.getThermalHeadroom()` and `OnThermalStatusChangedListener`).
- **FR12.2**: Audio capture and lightweight STT must never be throttled or blocked.
- **FR12.3**: If device thermal state reaches `THERMAL_STATUS_SEVERE` or `THERMAL_STATUS_CRITICAL`, or if available system RAM drops below 300MB, the system must defer on-device LLM post-processing into an adaptive backoff queue.
- **FR12.4**: As soon as device thermal headroom returns to safe levels (`THERMAL_STATUS_MODERATE` or lower), the queue worker must automatically resume deferred LLM inference.

#### FR13: System Observability & Telemetry Visualizers
- **FR13.1**: The Settings screen must render an interactive 24-hour battery consumption curve showing Eudemonia's background energy draw relative to device drain.
- **FR13.2**: The Settings screen must render a memory lifecycle timeline graph illustrating baseline idle RAM (<60MB), sequential load spikes during inference (~1.6GB), and the sharp reclamation curve following the 3-minute inactivity eviction.
- **FR13.3**: The queue service and UI state must hydrate synchronously from disk (`queue.json`) on cold app restart within <50ms, ensuring pending and processing items never vanish prematurely.

#### FR14: The Action Engine (Tasks & Commitments)
- **FR14.1**: During LLM post-processing, the model must extract any actionable commitments, errands, or tasks stated in the thought, producing structured action items with description, detected due date/time anchor, and urgency level.
- **FR14.2**: Extracted action items must be organized within an interactive Action Center view, supporting checkbox completion, item editing, and local Android calendar/reminder intent dispatch without external cloud services.

#### FR15: The Emotional Climate & Mind Heatmap
- **FR15.1**: For thoughts classified under the `Journal` category, the on-device LLM must evaluate emotional valence (-1.0 to +1.0) and cognitive energy (Low/High).
- **FR15.2**: The system must visualize emotional transitions over days and weeks in an on-device "Mind Climate" heatmap, allowing users to observe cognitive clarity patterns without telemetry or cloud exposure.

---

### D. Non-Functional Requirements (NFR)

| Category | Requirement | Target Metric / Benchmark |
| :--- | :--- | :--- |
| **Latency** | Audio Capture Dispatch | **< 5ms** from trigger release to queue handoff |
| **Latency** | Native Hardware Haptics | **< 20ms** from dual-key press to vibration pulse |
| **Latency** | On-Device STT Inference | **< 2.5s** per 10 seconds of recorded speech (Pixel 7a) |
| **Latency** | On-Device LLM Classification | **< 1.8s** for language correction and tagging |
| **Memory** | Baseline Idle RAM Footprint | **< 60 MB** when models are unloaded |
| **Memory** | Active Inference RAM Footprint | **< 1.6 GB** peak (STT ~600MB, LLM ~1.0GB) |
| **Memory** | Inactivity Eviction Timeout | Models evicted after **180 seconds (3 min)** of zero activity |
| **Battery** | 24-Hour Background Standby | **< 2.5%** total battery consumption in foreground listening mode |
| **Reliability** | Queue Failure Isolation | **100%**: A corrupt or silent audio file must never block the queue |
| **Reliability** | Queue Cold-Start Hydration | **< 50ms** hydration from disk on app restart |
| **Reliability** | UI Render Fluidity | **Locked 60/120fps** animation on processing indicators during active inference |
| **Reliability** | Thermal Safeguard | LLM deferred when thermal status >= `THERMAL_STATUS_SEVERE` |
| **Reliability** | App Crash-Free Rate | **> 99.9%** across background trigger cycles |
| **Privacy** | Network Transmission | **0 bytes**: Absolute zero outbound traffic for audio, text, or metrics |

---

## 6. User Experience (UX) & Interaction Specifications

> [!NOTE]
> **Complete UX Blueprint, Component Sandbox & Declarative Widget Code**:
> For the exhaustive design token dictionary, component sandbox architecture (`previews/`), production-ready Flutter widget snippets, and AI prompt recipes for every screen, refer to [`UX.md`](file:///Users/harshmavani/Documents/Eudemonia/UX.md).

### A. Design Tooling Architecture: Flutter Code-as-Design (Isolated `previews/` Sandbox)
Eudemonia adopts **Flutter Code-as-Design** as its official UI/UX design and iteration system. Rather than relying on external design tools with translation drift, screens are designed and iterated directly in Flutter using an isolated Component Sandbox (`previews/`).

- **Isolated Preview Sandbox (`previews/`)**:
  Design mockups, interactive states, and theme experiments live strictly in `previews/` (running via `flutter run -t previews/main_preview.dart`). This isolates UI design from backend functioning (Sherpa-ONNX STT, Qwen LLM, Isar database, and Accessibility Services) with zero prototype boilerplate in production (`lib/`).
- **Conversational AI Modification Loop**:
  Developers and AI agents (Antigravity) iterate on designs purely by discussing requirements in natural language. Antigravity modifies the sandboxed Flutter widgets in `previews/`, providing instant visual feedback via Flutter Hot Reload (<500ms).
- **Controlled Promotion to Production**:
  Approved presentational widgets are promoted into `lib/features/` as pure components and wired to Riverpod providers. Full component specifications and prompt recipes are detailed in [`UX.md`](file:///Users/harshmavani/Documents/Eudemonia/UX.md).

### B. Core UI Component Specifications & States

1. **Active Recording State & Instant Capture HUD**:
   - Toggling the dual-hardware button begins audio capture and displays a translucent glassmorphic HUD with an animated emerald/cyan soundwave and recording indicator.
   - Dismisses immediately (<5ms) upon trigger release without blocking the UI thread.
2. **Pending Queue Pill (AppBar)**:
   - When `pendingCount > 0`: Displays a pill in the top-right AppBar with a micro-spinner and text: `X pending`.
   - When `pendingCount == 0`: Automatically hidden.
3. **In-Body Processing Banner**:
   - Positioned prominently above Folders. Displays `Processing voice thought...` or `Processing voice thought (X pending)...` with an active spinner while the queue worker is actively transcribing or categorizing.
4. **Failed Items Retry Banner**:
   - Displays in amber/red if `failedCount > 0`: `X thought(s) failed to process` accompanied by a distinct **`Retry`** button.
5. **Settings & Diagnostics Screen**:
   - Status chips for **Accessibility Service** and **Background Execution (Battery Exemption)** using standardized **Enabled** (Green) and **Disabled** (Amber) badges.
   - Switch toggle for **"Keep App Alive in Background"** (controls `EudemoniaForegroundService`).
   - Telemetry gauge showing active AI Model Lifecycle state (`Ready`, `Loading`, or `Unloaded`) and RAM consumption (<60 MB idle, ~1.6 GB peak).
   - Interactive 24-hour battery consumption curve and memory lifecycle timeline graphs.
   - Diagnostic tools: **View System Logs**, **Copy Diagnostic Log Dump**, and **Clear Logs**.
6. **Ambient Permissions Alert**:
   - An ambient status card rendered at the top of the Home feed whenever Accessibility or Battery Exemption is missing. Automatically dismisses via lifecycle observer the moment both are granted.
7. **4-Color Thought Lifecycle Feed Cards & Audio Note Integration**:
   - Immediate **Pastel Yellow** card on non-empty audio recording completion, hosting direct **Audio Playback** (`[ ▶ ]`), timestamp, and processing shimmer.
   - Transitions to **Soft Blue** upon successful STT and classification, showing corrected text, 1-tap category dropdown pill, inline edit action, and subtle unread indicator dot (`•`).
   - Transitions to **Soft Red** on failure, keeping original audio playable and offering a 1-tap **Retry** button.
   - Transitions to **Sage Green** for auto- or manually-clubbed thoughts, featuring an expandable audit trail of original sub-thoughts and audio notes.
8. **Lock Screen Persistent Notification Controller**:
   - Ongoing Android foreground service notification with an interactive `[ 🎙️ Record Thought ]` action button and live recording timer.
9. **Action Center (The Action Engine)**:
   - Extracted commitments, tasks, and errands organized with interactive checkboxes and local system calendar/reminder dispatch.
10. **The Emotional Climate & Mind Heatmap**:
    - Daily and weekly visual heatmap plotting emotional valence and cognitive energy derived locally from `Journal` thoughts.

---

## 7. System Architecture & Data Flow

```
[ Hardware Layer: Physical Volume Up + Volume Down Keys ]
                           │
                           ▼
[ ButtonInterceptorService.kt (Accessibility Service) ]
   ├── Single click/hold ──► AudioManager.adjustSuggestedStreamVolume(..., FLAG_SHOW_UI)
   └── Dual-press ─────────► Native Haptic (Vibrator)
                           │ Explicit Intent: 'com.eudemonia.eudemonia.HARDWARE_TRIGGER'
                           ▼
[ Broadcast Receivers: MainActivity.kt & EudemoniaForegroundService.kt ]
   ├── TriggerDebouncer.kt (500ms cooldown)
   └── MethodChannel: 'com.eudemonia/hardware_buttons' -> onHardwareTrigger
                           │
                           ▼
[ Flutter Home Layer: HomeScreen.dart & BatchPipelineService.dart ]
   ├── Toggle Start: AudioRecordingService.startRecording()
   └── Toggle Stop:  AudioRecordingService.stopRecording() (<5ms)
                           │
                           ▼
[ FIFO Audio Queue: AudioQueueService.dart ]
   ├── Persists to '${appDir}/queue/queue.json'
   ├── Synchronous Riverpod State: pendingQueueCountProvider & failedQueueCountProvider
   └── Sequential Worker Loop
              │
              ├──► ModelLifecycleManager.ensureModelsLoaded()
              │       ├── Step 1: Sherpa-ONNX STT (~600MB)
              │       └── Step 2: Qwen-2.5 1.5B GGUF (~1.0GB)
              │
              ├──► STTService.transcribe(audioPath) -> rawTranscript
              ├──► NoteClassifier.processText(rawTranscript) -> LLMResponse
              │       ├── Language Correction (clean fillers & grammar)
              │       ├── Single-Folder Classification (Work/Ideas/Journal/Todos)
              │       └── LLMService.clearKvCache() (Purge KV slot)
              │
              ├──► NotesRepository.saveNote(Note) -> Isar Database
              └──► ModelLifecycleManager.touch() (Reset 3m inactivity timer)
```

---

## 8. Edge Cases, Error Handling & Recovery

| Edge Case / Condition | Behavior / Recovery Strategy |
| :--- | :--- |
| **Rapid Key Spamming** | `TriggerDebouncer` enforces a 500ms cooldown in native code, discarding spurious key bounces. |
| **Empty / Silent Recording** | `STTService` returns empty string; worker sets status to `failed` with `'No speech detected'` without crashing or blocking subsequent queue items. |
| **LLM Output Formatting Failure** | If the LLM generates non-compliant JSON, `NoteClassifier` catches the parse error and routes text through a keyword-based heuristic fallback classifier. |
| **Phone Reboots with Items in Queue** | Queue is backed by `${appDir}/queue/queue.json`; upon app launch or foreground service restart, uncompleted items are read and processed sequentially. |
| **Device Running Extremely Low on Memory** | `ModelLifecycleManager` loads models sequentially to minimize peak RAM spikes. If the OS terminates models, the manager re-initializes them on the next queue pass. |
| **Audio Key Normal Usage** | If the user adjusts volume with single clicks or holds, `VolumeButtonCoordinator` passes events directly to Android `AudioManager`, preserving normal volume adjustments. |

---

## 9. Future Roadmap (v1.5 & v2.0)

### Version 1.5: Multi-Tag Graph & Enhanced Taxonomy
- **Many-to-Many Tagging**: Maintain a single primary folder "home" while allowing secondary tags (e.g. `#client-x`, `#project-apollo`, `#urgent`) linked dynamically in note metadata.
- **Custom Folders & Taxonomies**: Allow users to define custom folders beyond the default four (`Work`, `Ideas`, `Todos`, `Journal`) with customizable system prompts.

### Version 2.0: On-Device Semantic Search & Wearables
- **Local Embedding Vector Search**: Generate local vector embeddings using an on-device embedding model (e.g. `all-MiniLM-L6-v2`) stored in Isar vector indices for natural language search (*"What was that thought I had about database caching last Tuesday?"*).
- **Wearable / Earbud Triggers**: Bluetooth media button listener allowing triggers from headphone play/pause double-taps or smartwatch buttons.
- **Local Encrypted Sync**: Optional peer-to-peer sync (via Syncthing or local Wi-Fi) exportable to Markdown vaults (Obsidian, Logseq).

---

## 10. Success Metrics & Quality Gates

### Quantitative KPIs
1. **Time-to-Capture Latency**: P95 < 5ms (from hardware button release to capture UI dismissal).
2. **Haptic Confirmation Latency**: P95 < 25ms from physical dual press.
3. **Queue Processing Success Rate**: > 98% of valid speech recordings successfully processed into notes.
4. **Classification Precision**: > 90% accuracy in folder assignment without human manual re-sorting.
5. **Background Process Retention**: Zero background OS kills over 48 hours of normal phone operation with Foreground Service enabled.

### Quality & Engineering Gates
- **Static Analysis Gate**: `flutter analyze` must maintain **0 errors** and **0 warnings**.
- **Automated Test Coverage**: 100% passing test suite across Flutter tests (`flutter test`) and native Android unit tests (`./gradlew :app:testDebugUnitTest`).
- **Contract-Enforcing Test Fakes**: All test doubles for lifecycle-managed services must enforce initialization state checks.
