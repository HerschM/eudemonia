# PRODUCT_SPEC.md — Eudemonia Product Requirements & Specification

> **Status**: Approved / Active (v1.1.0)  
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
6. [User Experience (UX) & Four-Stage Interaction Architecture](#6-user-experience-ux--four-stage-interaction-architecture)
7. [System Architecture & Data Flow](#7-system-architecture--data-flow)
8. [Edge Cases, Error Handling & Recovery](#8-edge-cases-error-handling--recovery)
9. [Future Roadmap (v1.5 & v2.0)](#9-future-roadmap-v15--v20)
10. [Success Metrics & Quality Gates](#10-success-metrics--quality-gates)

---

## 1. Executive Summary

**Eudemonia** is an on-device, zero-friction, voice-first thought capture and cognitive maturation system for Android. It enables thinkers, creators, and professionals to record fleeting ideas instantaneously using physical hardware triggers (simultaneous volume buttons), requiring zero screen interaction.

Unlike traditional voice memos or cloud-tethered note applications, Eudemonia captures audio in **<5ms**, queues recordings without blocking the user, transcribes speech entirely on-device, cleans conversational disfluencies, and guides captured thoughts through a four-stage cognitive transformation pipeline:

$$\mathbf{Capture} \longrightarrow \mathbf{Synthesis} \longrightarrow \mathbf{Insights} \longrightarrow \mathbf{Action}$$

By eliminating UI latency, network dependencies, cloud privacy liabilities, and open-ended tag sprawl, Eudemonia ensures that fleeting thoughts are captured cleanly, synthesized into disciplined folders (`Work`, `Ideas`, `Todos`, `Journal`), and converted into actionable momentum.

---

## 2. Problem Statement & Market Context

### The Fleeting Thought Problem
Human working memory retains fleeting thoughts for only **15 to 30 seconds** before cognitive distraction causes degradation. When inspiration strikes while walking, driving, or working, conventional capture workflows introduce fatal friction:
1. Reaching for the phone.
2. Unlocking via fingerprint or PIN.
3. Locating and launching a note-taking or voice-memo app.
4. Tapping a software "Record" button and waiting for the UI to initialize.
5. Manually typing tags, titles, and folders.

By the time this sequence finishes, the original nuance of the thought is diluted or lost.

### The Cloud Privacy & Tag Sprawl Dilemma
Existing AI note apps (e.g., Otter, Notion AI, Whisper APIs) require uploading personal voice recordings to third-party cloud servers and frequently rely on unconstrained AI-generated tags that explode into redundant naming conventions (*"app-ideas"*, *"app_idea"*, *"mobile-dev"*). This presents severe challenges:
- **Privacy Exposure**: Users hesitate to record intimate personal reflections, sensitive business ideas, or confidential discussions.
- **Network Brittleness**: Capturing ideas in elevators, subways, airplanes, or rural zones fails or lags unpredictably.
- **Taxonomy Chaos**: Uncontrolled tag generation leads to cluttered, fragmented feeds that resist coherent review.
- **System Memory & Battery Bloat**: Unmanaged background listening or monolithic local models cause Android Low Memory Killer (LMK) terminations and screen blackouts.

---

## 3. Target Personas & User Scenarios

### Personas

| Persona | Description | Primary Needs |
| :--- | :--- | :--- |
| **The High-Velocity Thinker / Founder** | Generates 20+ raw ideas daily while commuting, in meetings, or between tasks. | Instant physical trigger without looking at the screen; automated clustering and synthesis of walk ideas into cohesive notes categorized into `Ideas` or `Work`. |
| **The Privacy-Conscious Journaler** | Uses voice for stream-of-consciousness personal journaling and reflection. | 100% offline, zero cloud leakage; automated cleanup of verbal disfluencies (*"um"*, *"like"*); long-term emotional climate tracking under `Journal`. |
| **The Rapid Task Capturer** | Captures urgent action items and errands on the go. | Fast capture that converts speech into clean, actionable commitments and calendar time-blocks with zero manual sorting under `Todos`. |

### Key User Scenarios

#### Scenario 1: Screen-Off / Pocket Capture
- **Context**: User is walking outdoors with phone locked in pocket. A breakthrough thought occurs.
- **Action**: User presses both volume buttons simultaneously through their pocket fabric.
- **Feedback**: A sharp dual-pulse native haptic confirms recording has started. User speaks naturally for 15 seconds.
- **Completion**: User presses both volume buttons again. A single haptic pulse confirms stop.
- **Outcome**: The audio is saved to the local queue in <5ms. The phone stays in the user's pocket. The background worker loads the on-device models, performs STT + grammar cleanup, assigns daily sequence `#01`, and renders in the **Capture** stream without premature classification.

#### Scenario 2: Active Interruption Inside Another App
- **Context**: User is reading a document or navigating in Google Maps when an unrelated task comes to mind.
- **Action**: User triggers dual volume buttons.
- **Outcome**: Capture starts instantly without launching Eudemonia over the active navigation screen or interrupting foreground tasks. When stopped, normal volume buttons immediately resume transparent audio level control.

#### Scenario 3: Four-Stage Cognitive Maturation Review
- **Context**: User opens Eudemonia after a morning walk where they captured 4 disjointed ideas about app architecture and 1 grocery errand.
- **Outcome**:
  - In **Capture**: All 5 raw thoughts appear in chronological order with daily sequence numbers (`#01` to `#05`), immediate audio playback buttons, unread dots, and date-time (`05/11  07:15 AM`).
  - In **Synthesis**: The 4 architecture thoughts are automatically clustered into a single synthesized note (`#S-01`) classified under the **`Ideas`** folder, while the errand is synthesized into a note under **`Todos`**. The user uses the **Folder Filter Dropdown** in the header (`All Folders`, `Work`, `Ideas`, `Todos`, `Journal`) to filter sessions by folder, inspects included raw notes via the expandable count drawer, and can eject or reassign notes as needed.
  - In **Insights**: The user reviews the weekly emotional valence heatmap and topic density matrix.
  - In **Action**: The grocery errand and any architecture commitments appear in the todo list with 1-tap calendar time-blocking.

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
│ 4. Four-Stage Maturation &   │ Capture -> Synthesis ->      │
│    Single-Folder Discipline  │ Insights -> Action pipeline  │
├──────────────────────────────┼──────────────────────────────┤
│ 5. Resource Consciousness    │ Inactivity model eviction;   │
│                              │ <60MB idle memory footprint  │
└──────────────────────────────┴──────────────────────────────┘
```

1. **Zero-Latency Capture (<5ms Budget)**: Stopping audio capture must feel instantaneous. Heavy AI models must never block user interactions or hold recording gestures hostage.
2. **Physical-First Accessibility**: Physical volume keys provide tactile muscle memory that works in dark rooms, pockets, or without glancing at the screen.
3. **Absolute Privacy & Local Autonomy**: No telemetry, audio data, or text embeddings ever leave the physical handset. All STT (Sherpa-ONNX) and LLM (Qwen-2.5 1.5B GGUF) run directly on device hardware.
4. **Four-Stage Maturation with Single-Folder Discipline**: Instead of forcing raw thoughts prematurely into folders or allowing open-ended tag sprawl, thoughts mature through four stages:
   - **Capture**: Unadulterated, unclassified speech cleanup with immediate playback.
   - **Synthesis**: Multi-thought clustering by temporal proximity and semantic similarity. Notes are classified strictly into predefined folders (`Work`, `Ideas`, `Todos`, `Journal`, fallback `Uncategorized`) with a compact folder filter dropdown. Open-ended auto-tagging is strictly avoided to prevent taxonomy explosion.
   - **Insights**: Higher-order emotional climate, topic load, and recurrent pattern dashboards.
   - **Action**: Commitments extraction and calendar time-blocking.
5. **Mobile Resource Respect**: Mobile operating systems aggressively kill memory-heavy apps. Models must load sequentially and be evicted after 3 minutes of idle time to prevent phone slowdowns and Android Low Memory Killer (LMK) kills.

---

## 5. Scope & Requirements

### A. In-Scope (v1.0 MVP & Active Extensions)
- Android physical dual-volume key trigger detection via an Accessibility Service.
- Native haptic feedback delivered directly in Android native code (<20ms).
- Volume button transparent pass-through (single clicks and holds adjust media volume normally without runaway loops).
- Decoupled FIFO audio processing queue with disk persistence and cold-start state hydration.
- On-device speech recognition via Sherpa-ONNX Parakeet v3.
- On-device language correction and styling via quantized Qwen-2.5 1.5B GGUF.
- Local note persistence via Isar embedded database.
- Persistent background keep-alive foreground service with interactive lock screen capture action.
- **Capture Screen**: Neutral cards (strictly zero categorization/color-coding), daily sequence numbering resetting at midnight, delete with gap preservation, `[# Number]` $\rightarrow$ `[▶ Play]` $\rightarrow$ `[• Unread]` $\rightarrow$ `[🗑️ Delete]` heading layout, `DD/MM  HH:MM AM/PM` timestamps, manual edit, AI style re-writer with preset context prompts.
- **Synthesis Screen**: Semantic and session-proximity clustering, `#S-01` session identifiers, compact Folder Filter Dropdown (`[ 📁 All Folders ▾ ]`), predefined folder badge with 1-tap reassignment dropdown, consolidated synthesis narrative, session duration and time span, expandable raw notes count drawer, raw note ejection (move to another cluster or make independent synthesized note).
- **Insights Screen**: Multi-view dashboard spanning thematic synthesis, emotional climate heatmap (-1.0 to +1.0 valence), topic density distribution, and recurrent pattern/habit loop detection.
- **Action Screen**: Action commitments todo list with urgency tags and origin session links, calendar time-blocking view, calendar synchronization status, and 1-tap calendar push (with account config in Settings).
- Thermal and low-memory adaptive queue gating to prevent device overheating.
- System transparency telemetry graphs (24h battery impact & memory lifecycle curve) in Settings.
- Hardware-accelerated 60/120fps progress indicator decoupled from inference load.
- Diagnostic logging system with 2MB rotating disk cap and in-app viewer.

### B. Out-of-Scope (Explicit Non-Goals for v1.0)
- Multi-tag many-to-many graph tagging (reserved for v1.5; v1.0 organizes via 4-stage pipeline and predefined single-folder synthesis).
- Cloud synchronization (Dropbox, Google Drive, iCloud) or cross-device sync.
- Real-time streaming transcription while speaking (batch transcription post-capture is chosen for battery efficiency).
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

#### FR5: On-Device LLM Pipeline (Two-Tier Post-Processing)
- **FR5.1**: The system must run an on-device quantized LLM (Qwen-2.5 1.5B GGUF) via `llama_cpp_dart`.
- **FR5.2 (Tier 1 — Capture Cleanup)**: For each raw capture, the model performs grammar and language correction (capitalization, punctuation, filler word removal) ONLY. Strictly NO folder classification, style transformation, or color tinting is applied at this stage.
- **FR5.3 (AI Style Re-Writer on Synthesized Notes)**: Users can re-write any synthesized note on-demand using preset style prompts (*Concise & Direct*, *Bullet Points*, *Professional*, *Journal/Reflective*, *Actionable*, *Casual*). The active style is indicated with a checkmark; changing styles transitions the note to Yellow (`pending re-processing`) for local LLM re-synthesis.
- **FR5.4 (Tier 2 — Synthesis & Single-Folder Classification)**: When notes are clustered, the LLM analyzes semantic similarity, assigns exactly one predefined folder (`Work`, `Ideas`, `Todos`, `Journal`, or fallback `Uncategorized`), and synthesizes fragments into a cohesive note. Arbitrary tag generation is strictly prohibited.
- **FR5.5**: Output must be parsed from structured JSON format. If parsing fails, the system must fall back to a heuristic keyword classifier.
- **FR5.6**: The system must purge the KV cache (`_llama.disposeScope()`) after every turn (`clearKvCacheEveryXTurns = 1`) to eliminate lingering RAM consumption.

#### FR6: Model Lifecycle & Memory Management
- **FR6.1**: The system must maintain three lifecycle states: `unloaded`, `loading`, and `ready`.
- **FR6.2**: Models must be loaded **sequentially** (STT first, LLM second) to prevent simultaneous memory allocation spikes above Android Low Memory Killer thresholds.
- **FR6.3**: When idle for 3 minutes (`modelInactivityTtl`), the system must automatically unload both models from RAM, reclaiming ~1.6 GB and restoring baseline footprint to <60 MB.
- **FR6.4**: Completing an item or interacting with the queue must touch the lifecycle manager, resetting the 3-minute eviction timer.

#### FR7: Local Persistence
- **FR7.1**: Raw and synthesized thoughts must be saved to an embedded local database (Isar) containing `id`, `sequenceNumber`, `rawText`, `cleanedText`, `synthesizedContent`, `clusterId`, `folder`, `createdAt`, and `originalAudioPath`.
- **FR7.2**: The notes repository must support retrieval sorted by recency and filtered by stage (`capture`, `synthesis`) and by folder (`Work`, `Ideas`, `Todos`, `Journal`).

#### FR8: Background Reliability & Permissions
- **FR8.1**: The app must provide an Android Foreground Service (`EudemoniaForegroundService`) with an ongoing low-priority notification to protect the process from OS termination.
- **FR8.2**: The app must detect and request both Accessibility Service and Battery Optimization Exemption (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) simultaneously through an educational modal.
- **FR8.3**: Permission status indicators across settings and alerts must use standardized **Enabled** (Green) and **Disabled** (Amber) badges.

#### FR9: Capture Screen Presentation, Status Colors & Dual Filters
- **FR9.1 (Processing State Color Accents)**: Captures appear in the **Capture** stream with visual state color indicators (no folder category tags):
  - **Yellow (`stateEnqueuedBg` / Amber)**: Pending audio queue processing / STT transcription.
  - **Blue (`stateProcessedBg` / Electric Blue)**: Post-STT and language cleanup completed; awaiting session synthesis.
  - **Green (`stateSynthesizedBg` / Emerald)**: Synthesis completed (clubbed into a synthesized session).
  - **Red (`stateFailedBg` / Rose)**: Processing failed (with retry action).
- **FR9.2 (Compact Dual Dropdown Filters)**:
  - **Triage Filter Dropdown**: Dropdown filter situated above feed for `All`, `Unread`, and `Read`.
  - **Status Filter Dropdown**: Dropdown filter situated above feed for `All Statuses`, `Processing`, `Processed`, `Synthesized`, and `Failed`.
  - Dropdown controls preserve vertical space and ensure visual alignment with the Synthesis screen's controls.
- **FR9.3 (Interactive Floating Capture Trigger)**:
  - The Capture screen features an elevated floating capsule: `[ 🎙️ / Press Vol Up + Down to Capture ]` with a prominent mic icon (`20sp`) and `"/"` separator.
  - The trigger is directly clickable in-app to start recording without physical volume buttons.
  - While recording, the pill transforms to show an active listening loader bar / pulsating audio waveform inside the button itself with elapsed time. Tapping again stops recording, enqueuing a Yellow pending note immediately with clean SnackBar feedback: `"Captured a new note [#0X]"` (free of internal implementation or debug filler text).
- **FR9.4**: Every capture note receives a daily sequence number (`#01`, `#02`, `#03`...). The counter resets to `#01` every day at midnight.
- **FR9.5**: Deleting a note leaves the numbering of subsequent notes intact (e.g., deleting `#02` preserves `#01`, `#03`, `#04`; gaps are explicitly allowed).
- **FR9.6**: The card heading layout must adhere to the strict order: `[# Number]` $\rightarrow$ `[▶ Play Audio]` $\rightarrow$ `[• Unread Dot]` $\rightarrow$ `[🗑️ Delete]`. This guarantees visual horizontal alignment across read and unread notes.
- **FR9.7**: Timestamps at the card footer must strictly display date then time: `DD/MM  HH:MM AM/PM` (e.g. `05/11  09:42 AM`).
- **FR9.8**: Tapping `[ ✎ Edit ]` allows manual text editing. (High-level AI Style Re-Writing is located in the Synthesis screen where final consolidated text is formed).

#### FR10: Lock Screen & Notification Center Capture Trigger
- **FR10.1**: The persistent foreground service notification must host an interactive action button: `[ 🎙️ Record Thought ]`.
- **FR10.2**: Toggling the notification button must trigger start and stop of thought recording directly from the lock screen or notification shade without requiring device unlock.
- **FR10.3**: While recording is active, the notification must update dynamically to display an elapsed timer (`Recording 00:06...`) and a `[ ⏹ Stop & Save ]` action.

#### FR11: Synthesis, Predefined Folders & Session Clustering
- **FR11.1**: The system must automatically cluster disjointed raw notes captured within an active temporal window (e.g. 15–45 minutes) that share contextual continuity or topical affinity into a unified synthesized note.
- **FR11.2 (Compact Folder Filter Dropdown)**: The horizontal folder carousel is removed. The Synthesis view provides a compact folder filter dropdown (`[ 📁 Filter: All Folders ▾ ]`) situated in the section sub-header, allowing users to filter synthesized notes by predefined folder without taking up vertical screen real estate.
- **FR11.3 (Single-Folder Badge & 1-Tap Card Reassignment)**: Each synthesized note displays its assigned folder badge (`[ 💡 Ideas ▾ ]`, `[ 💼 Work ▾ ]`). Tapping opens a quick-picker dropdown to reassign the note among the predefined folders.
- **FR11.4**: Synthesized notes receive a sequential identifier (`#S-01`, `#S-02`), consolidated synthesis narrative, session time span (`05/11  07:10 AM - 07:45 AM`), session duration (`⏱️ 35m session`), and an expandable raw notes count pill (`[ 🧩 3 Raw Notes ▾ ]`).
- **FR11.5 (Raw Note Ejection & Re-Synthesis Guard)**:
  - If a synthesized cluster contains only 1 note (`originNotes.length <= 1`), the `[ ⤢ Move Out ]` button is hidden/disabled.
  - For clusters with $\ge 2$ notes, users can eject any raw note via `[ ⤢ Move Out ]` through a clean sheet (free of debug filler instructions):
    1. *Move to another clubbed note*: Shows a selector of available existing clubbed notes (`#S-01`, `#S-02`, etc.). Upon confirmation, **both** the source and target clubbed notes transition to Yellow (`pending re-processing`) so their synthesized text is automatically regenerated.
    2. *Make it an independent note*: Detaches the note and creates a standalone synthesized note; the source clubbed note turns Yellow to re-synthesize without the detached thought.
- **FR11.6 (Manual Multi-Select)**: Users can select multiple raw notes to manually trigger a synthesis turn across selected items.
- **FR11.7 (AI Style Re-Writer)**: Synthesized notes feature an interactive `[ ✨ Style ▾ ]` action button. Tapping opens the preset style picker (*Concise & Direct*, *Bullet Points*, *Professional*, *Journal/Reflective*, *Actionable*, *Casual*), highlighting the currently active preset with a checkmark (`Icons.check`). Selecting a new preset flags the cluster as re-processing, transitioning its card color to Yellow (`stateEnqueuedBg`) while local LLM re-synthesis takes place.
- **FR11.8 (Configurable Synthesis Trigger & Batching Safeguards)**: To prevent continuous on-device LLM inference from draining mobile battery and spiking device thermals, synthesis clustering runs in adaptive batches:
  1. *Note Accumulation Threshold*: Automatically triggers synthesis when $X$ unprocessed capture notes accumulate (configurable in settings: 1–10 notes, default 3).
  2. *Session Inactivity Window*: Automatically triggers synthesis when $Y$ minutes elapse without new captures while unprocessed thoughts exist in the queue (configurable in settings: 5–60 minutes, default 15 minutes).
  3. *Manual Override*: Users can bypass automatic thresholds and trigger immediate on-demand synthesis at any time via `[ ⚡ Synthesize Now ]` in the Pipeline HUD and Synthesis feed.
- **FR11.9 (Synthesis Tri-Color Maturation & Action Extraction Pass)**: Synthesis cluster cards visually signal lifecycle maturation:
  - **Yellow (`stateEnqueuedBg`)**: Re-synthesizing in progress.
  - **Blue (`stateProcessedBg`)**: Synthesized narrative ready; awaiting action-item extraction pass.
  - **Green (`stateSynthesizedBg`)**: Action extraction pass completed (closed and promoted to Action tab). Note: Reflective or journal notes with 0 action items turn Green upon extraction pass completion, confirming the thought is fully processed.
- **FR11.10 (Synthesis Triage & Unread Tracking)**:
  - Synthesis cluster cards display an electric blue unread indicator dot (`• Unread`) when newly clustered.
  - The Synthesis screen sub-header provides an `[ 👁️ All Triage ▾ ]` dropdown (`All`, `Unread`, `Read`) alongside `[ 📁 All Folders ▾ ]` to filter new vs reviewed synthesized sessions.
- **FR11.11 (Active Session Horizon & 2D Domain-Bounded Clustering)**:
  - **2D Clustering Matrix (`Time Window ∩ Target Folder`)**: Thoughts captured within the temporal session window are strictly grouped by **target folder/domain**. If a user captures a technical work thought and a personal journal thought within the same 45-minute window, the system routes them into separate domain-specific active clusters (`#S-01` for Work, `#S-02` for Journal), preventing cross-domain narrative contamination.
  - **Sliding Inactivity Window ($Y=45$m)**: An active cluster remains open and receptive to incoming notes until 45 minutes elapse without new captures in that folder domain.
  - **Hard Session Ceiling ($T_{max}=2$ hours)**: To prevent runaway all-day monolithic clusters when capturing notes periodically throughout an 8-hour workday, an active cluster automatically finalizes at the 2-hour mark from its first note (`09:00 AM – 11:00 AM • ⏱️ 2h session`). Subsequent notes start a fresh cluster.
  - **Delta Synthesis**: When new notes arrive for an active cluster, the LLM executes an additive integration pass combining existing summary with new text, consuming $<300$ input tokens instead of re-running the full cluster from scratch.
- **FR11.12 (Delta Action Extraction & Task State Immutability)**:
  - **Action Immutability**: Existing action items stored in the database (`Isar`) possess immutable IDs, creation timestamps, and completion states (`isCompleted = true`). They are never deleted or modified when a cluster receives new notes.
  - **Additive Delta Extraction**: When new notes merge into an already synthesized cluster, the action extractor prompt receives the list of currently existing tasks and the new incoming thoughts, extracting strictly *new* or *modified* action items. No duplicate tasks are generated, and completed tasks remain checked.
- **FR11.13 (Explicit Synthesis Note Merging)**:
  - Synthesis cluster cards feature an interactive `[ 🔗 Merge ]` action button.
  - Tapping opens a merge sheet listing all other available synthesis sessions. Selecting a target session transfers all origin notes of the source cluster into the target cluster, deletes the source cluster, and marks the target cluster as Yellow (`stateEnqueuedBg` / `isReprocessing = true`) for consolidated re-synthesis with clean SnackBar feedback: `"Merged #S-02 into #S-01"`.
- **FR11.14 (Semantic Folder Manifestos & Custom Folder Management)**:
  - **Semantic Folder Manifesto Model**: Each folder maintains a persistent manifesto: `id`, `name`, `description` (project domain, active apps, key concepts), `autoGeneratedSummary` (AI-maintained digest of recently filed keywords and themes), and `lastUpdated`.
  - **Custom Folder Management in Settings**: Users can create, view, and edit custom folders (e.g., `Eudemonia`, `Personal Health`, `Client CRM`) in a dedicated Settings section.
  - **Asynchronous Living Manifesto Evolution**: After every 5 notes filed into a folder, a low-priority background task refreshes `autoGeneratedSummary` with dominant keywords and entities.
  - **Enriched Classification Prompting**: Stage 1 language cleanup and Stage 2 clustering inject folder manifestos into prompts, allowing the local LLM to accurately categorize abrupt, context-dependent voice notes (e.g., *"Need to finish UI/UX"* matches `Eudemonia` because UI/UX is explicitly in its manifesto).

#### FR12: Thermal & Resource-Aware Adaptive Queue Gating
- **FR12.1**: The queue service must query Android native thermal status (`PowerManager.getThermalHeadroom()` and `OnThermalStatusChangedListener`).
- **FR12.2**: Audio capture and lightweight STT must never be throttled or blocked.
- **FR12.3**: If device thermal state reaches `THERMAL_STATUS_SEVERE` or `THERMAL_STATUS_CRITICAL`, or if available system RAM drops below 300MB, the system must defer on-device LLM post-processing into an adaptive backoff queue.
- **FR12.4**: As soon as device thermal headroom returns to safe levels (`THERMAL_STATUS_MODERATE` or lower), the queue worker must automatically resume deferred LLM inference.

#### FR13: System Observability & Telemetry Visualizers
- **FR13.1**: The Settings screen must render an interactive 24-hour battery consumption curve showing Eudemonia's background energy draw relative to device drain.
- **FR13.2**: The Settings screen must render a memory lifecycle timeline graph illustrating baseline idle RAM (<60MB), sequential load spikes during inference (~1.6GB), and the sharp reclamation curve following the 3-minute inactivity eviction.
- **FR13.3**: The queue service and UI state must hydrate synchronously from disk (`queue.json`) on cold app restart within <50ms.

#### FR14: The Action Engine (Tasks & Calendar Time-Blocking)
- **FR14.1**: During synthesis, the LLM extracts actionable commitments, producing structured action items with description, temporal anchor (`05/11  02:00 PM`), urgency level, and origin note link.
- **FR14.2**: The **Action** screen organizes commitments with interactive checkboxes, calendar time-block previews, and 1-tap `[ 📅 Push to Calendar ]` dispatch.
- **FR14.3**: Calendar account and sync configuration is managed in Settings; connection status is reflected live in the Action screen.

#### FR15: Insights Hub (Cognitive Climate & Recurrent Patterns)
- **FR15.1**: Evaluates reflective notes for psychological valence (-1.0 to +1.0) and cognitive energy (Low/High).
- **FR15.2**: The **Insights** screen visualizes a weekly/monthly emotional valence heatmap, topic cognitive density matrix, and surfaces recurrent thought patterns detected across sessions over time.

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

## 6. User Experience (UX) & Four-Stage Interaction Architecture

> [!NOTE]
> **Complete UX Blueprint, Component Sandbox & Declarative Widget Code**:
> For the exhaustive design token dictionary, component sandbox architecture (`previews/`), ASCII wireframes, and component contracts for every screen, refer to [`UX.md`](file:///Users/harshmavani/Documents/Eudemonia/UX.md).

### A. The 4-Stage Navigation Shell
The app shell separates machine pipeline tasks from human consumption:
- **Global Header**: Features the interactive AI Pipeline Status Pill (`[ ⚡ X in Pipeline ▾ ]` or `[ 🌿 In Sync ▾ ]`), opening the Pipeline HUD with stage breakdowns and `[ ⚡ Synthesize Now ]` manual override.
- **Segmented Bar**: Stage tabs display numbers strictly for **unconsumed human value** with zero-suppression (`Capture (2)`, `Synthesis (1)`, `Insights (1)`, `Action (3)`).
1. **Capture**: Unfiltered, state-coded stream of voice captures with daily numbering, audio playback, unread dots, manual editing, and compact dual dropdown filters.
2. **Synthesis**: Clustered session notes with dual dropdown filters (`[ 👁️ All Triage ▾ ]` and `[ 📁 All Folders ▾ ]`), tri-color card states (Yellow, Blue, Green), unread dots, on-demand AI style re-writing, and configurable batching settings ($X$ notes / $Y$ minutes).
3. **Insights**: Macro-level cognitive intelligence: emotional valence heatmap, topic cognitive density treemap, and recurrent behavioral patterns.
4. **Action**: Execution hub featuring extracted commitment checkboxes, calendar time-blocking, and external calendar sync status.

### B. Isolated Component Sandbox (`previews/`)
All visual prototypes and UI design iterations are built in `previews/screens/` and verified with mock datasets before promotion into `lib/features/`:
- `capture_screen_preview.dart` (Screen 1)
- `synthesis_screen_preview.dart` (Screen 2: with Dual Dropdown Filters & Tri-Color Cards)
- `insights_screen_preview.dart` (Screen 3)
- `action_screen_preview.dart` (Screen 4)
- `settings_preview.dart` (Screen 6: Hardware permissions, Synthesis batching thresholds, Calendar sync, Diagnostics)
- `capture_hud_preview.dart` (Instant Audio Capture HUD <5ms)
- `style_rewriter_preview.dart` (AI Style Re-Writer Context Prompts)
- `note_ejection_preview.dart` (Disaggregate & Eject Raw Note Modal)
- `settings_preview.dart` (Settings, Calendar Sync & Diagnostics)
- `permissions_modal_preview.dart` (Dual Background Onboarding Sheet)

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
[ Capture Layer: CaptureScreen.dart & AudioRecordingService.dart ]
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
              │
              ├──► NoteClassifier.cleanupLanguage(rawTranscript) -> cleanedText
              │       └── Stage 1: Capture Card populated (Daily #, Playback, Date-Time)
              │
              ├──► NoteClusteringService.clusterSessions()
              │       └── Stage 2: Synthesis Note (#S-01, Predefined Folder Pill, Origin Drawer)
              │
              ├──► ActionExtractor.extractCommitments() -> Stage 4 Action Items
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
| **Note Deleted from Capture Feed** | Subsequent notes retain their assigned daily numbers (`#01`, `#03`); numbering gaps are permitted and expected. |
| **Audio Key Normal Usage** | If the user adjusts volume with single clicks or holds, `VolumeButtonCoordinator` passes events directly to Android `AudioManager`, preserving normal volume adjustments. |

---

## 9. Future Roadmap & Explicit V1 Non-Goals

### A. Deferred Features & Roadmap (v1.5 & v2.0)
- **AI-Assisted Topical Merge Suggestions (v1.5)**: Deterministic, zero-LLM entity and keyword set-intersection matching across the last 48 hours to display proactive suggestion pills (`[ 🔗 Similar to #S-01 (Marcus deliverables) • Merge? ]`).
- **Many-to-Many Secondary Tagging (v1.5)**: Maintain a single primary folder while allowing secondary tags (e.g. `#client-x`, `#project-apollo`) linked dynamically in note metadata.
- **Local Embedding Vector Search (v2.0)**: Generate local vector embeddings using an on-device embedding model (e.g. `all-MiniLM-L6-v2`) stored in Isar vector indices for natural language search (*"What was that thought I had about database caching last Tuesday?"*).
- **Wearable / Earbud Triggers (v2.0)**: Bluetooth media button listener allowing triggers from headphone play/pause double-taps or smartwatch buttons.
- **Local Encrypted Sync (v2.0)**: Optional peer-to-peer sync (via Syncthing or local Wi-Fi) exportable to Markdown vaults (Obsidian, Logseq).

### B. Explicit Non-Goals & Out-of-Scope Architecture for V1.0
- **Cloud Synchronization & External LLMs**: Eudemonia remains 100% on-device, private, and local-first.
- **Raw System Prompt Editing & User Persona Box**: Exposing editable system prompts or free-form persona text boxes in Settings is explicitly non-goal for V1. Locking down internal prompts ensures 100% deterministic JSON schemas, prevents mobile token/KV-cache overflow, and eliminates parser regression bugs.
- **Streaming Live Transcription**: Speech is recorded to local audio files and transcribed after capture confirmation.
- **iOS & Cross-Platform Native Keys**: Native accessibility service key hooks are strictly targeted at Android.

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
