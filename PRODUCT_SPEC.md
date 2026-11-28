# PRODUCT_SPEC.md — Eudemonia Product Requirements & Specification

> **Status**: Approved / Active (v1.1.0)  
> **Target Platform**: Android (API 26+, optimized for modern Android 14/15/16)  
> **Classification**: Core Product Requirements Document (PRD) & Specification  
> **Authors**: Eudemonia Core Team  

---

## 1. Executive Summary

**Eudemonia** is an on-device, zero-friction, voice-first thought capture and cognitive maturation system for Android. It enables thinkers, creators, and professionals to record fleeting ideas instantaneously using physical hardware triggers (simultaneous volume buttons), requiring zero screen interaction.

Unlike traditional voice memos or cloud-tethered note applications, Eudemonia captures audio in **<5ms**, queues recordings without blocking the user, transcribes speech entirely on-device, cleans conversational disfluencies, and guides captured thoughts through a four-stage cognitive transformation pipeline:

$$\mathbf{Capture} \longrightarrow \mathbf{Synthesis} \longrightarrow \mathbf{Insights} \longrightarrow \mathbf{Action}$$

By eliminating UI latency, network dependencies, cloud privacy liabilities, and open-ended tag sprawl, Eudemonia ensures that fleeting thoughts are captured cleanly, synthesized into disciplined folders (`Work`, `Personal`, `Journal`, `Uncategorized`), and converted into actionable momentum.

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
| **The High-Velocity Thinker / Founder** | Generates 20+ raw ideas daily while commuting, in meetings, or between tasks. | Instant physical trigger without looking at the screen; automated clustering and synthesis of walk ideas into cohesive notes categorized into `Work` or `Personal`. |
| **The Privacy-Conscious Journaler** | Uses voice for stream-of-consciousness personal journaling and reflection. | 100% offline, zero cloud leakage; automated cleanup of verbal disfluencies (*"um"*, *"like"*); long-term emotional climate tracking under `Journal`. |
| **The Rapid Task Capturer** | Captures urgent action items and errands on the go. | Fast capture that converts speech into clean, actionable commitments and calendar time-blocks with zero manual sorting under `Personal`. |

### Key User Scenarios

#### Scenario 1: Screen-Off / Pocket Capture
> **R1 (2026-11-26)**: with FR1 deferred, the locked-phone capture is one tap on `Record Thought` in the lock-screen notification and one tap on `Stop & Save`; the pocket (no-look) variant below returns with the volume trigger.

- **Context**: User is walking outdoors with phone locked in pocket. A breakthrough thought occurs.
- **Action**: User presses both volume buttons simultaneously through their pocket fabric.
- **Feedback**: A sharp dual-pulse native haptic confirms recording has started. User speaks naturally for 15 seconds.
- **Completion**: User presses both volume buttons again. A single haptic pulse confirms stop.
- **Outcome**: The audio is saved to the local queue in <5ms. The phone stays in the user's pocket. The background worker loads the on-device models, performs STT (the transcript is shown as spoken), assigns daily sequence `#01`, and renders in the **Capture** stream without premature classification.

#### Scenario 2: Active Interruption Inside Another App
> **R1 (2026-11-26)**: the trigger is the Record button in the notification shade (or the widget from the home screen); the outcome below is unchanged — Eudemonia never comes to the front (FR10.5).

- **Context**: User is reading a document or navigating in Google Maps when an unrelated task comes to mind.
- **Action**: User triggers dual volume buttons.
- **Outcome**: Capture starts instantly without launching Eudemonia over the active navigation screen or interrupting foreground tasks. When stopped, normal volume buttons immediately resume transparent audio level control.

#### Scenario 3: Four-Stage Cognitive Maturation Review
- **Context**: User opens Eudemonia after a morning walk where they captured 4 disjointed ideas about app architecture and 1 grocery errand.
- **Outcome**:
  - In **Capture**: All 5 raw thoughts appear in chronological order with daily sequence numbers (`#01` to `#05`), immediate audio playback buttons, unread dots, and date-time (`05/11  07:15 AM`).
  - In **Synthesis**: The 4 architecture thoughts are automatically clustered into a single synthesized note (`#S-01`) classified under the **`Work`** folder, while the errand is synthesized into a note under **`Personal`**. The user uses the **Folder Filter Dropdown** in the header (`All Folders`, `Work`, `Personal`, `Journal`, `Uncategorized`) to filter sessions by folder, inspects included raw notes via the expandable count drawer, and can eject or reassign notes as needed.
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
   - **Synthesis**: Multi-thought clustering by temporal proximity and semantic similarity. Notes are classified strictly into predefined folders (`Work`, `Personal`, `Journal`, `Uncategorized`, fallback `Uncategorized`) with a compact folder filter dropdown. Open-ended auto-tagging is strictly avoided to prevent taxonomy explosion.
   - **Insights**: Higher-order emotional climate, topic load, and recurrent pattern dashboards.
   - **Action**: Commitments extraction and calendar time-blocking.
5. **Mobile Resource Respect**: Mobile operating systems aggressively kill memory-heavy apps. Models must load sequentially and be evicted after 2 minutes of idle time to prevent phone slowdowns and Android Low Memory Killer (LMK) kills.

---

## 5. Scope, Functional Requirements (FR) & Non-Functional Requirements (NFR)

### R1. First Public Release Scope (Capture & Synthesis Only; Notification, Widget & In-App Capture; Decided by the User 2026-11-26)

> [!IMPORTANT]
> This block governs what is built and enabled in the **first public release (R1)**. Requirements below that R1 defers stay valid as written and return after launch; they are not to be built, shown or declared to Google Play in R1.

- **Ships in R1**:
  - **Two stages only**: Capture and Synthesis. The Insights and Action tabs are removed from the navigation shell (no greyed-out placeholders).
  - **Three ways to capture** (FR9.3, FR10): the Record button on the persistent notification (usable on the lock screen without unlocking), a home-screen widget, and the capture capsule inside the app. The notification and the widget are the primary mechanism.
  - Recording is done by native Android code, so a thought is saved without the app being open and without the app coming to the front (FR10.5).
  - On-device speech recognition and Synthesis as specified (FR4, FR5, FR11); synthesized notes are displayed as formatted text, not with literal Markdown markers (FR11.15).
  - **Models are downloaded inside the app** and the user chooses a language model that fits the phone (FR16).
  - **No payment flow**: Synthesis is free in R1.
- **Deferred until after R1** (in the order the user wants them taken up, where stated):
  - **FR1 dual-volume-button trigger and the Accessibility Service**: Google Play's Accessibility declaration takes long to approve and the trigger needs testing across many phones before it can feel reliable. The last working code is parked, not compiled and not in the manifest (`android/app/src/parked/hardware_trigger/`).
  - **FR14 Action and FR15 Insights**: need a long period of ironing out; user feedback on Capture and Synthesis comes first.
  - **Payment flow and the lock that leads to payment**: work starts after R1 is live (see `business/STRATEGY.md`); requirements to be written then.
  - **Wording trials for the synthesized note** (prompt changes only) — after the cosmetic issues are fixed and the Google verification video is recorded.
  - **FR12 thermal and battery guard** (TASK-072) and other functional tuning — after everything needed for launch and verification.
  - **Export of notes as Markdown files** (FR11.15, roadmap).
- **Order of work for R1 (user, 2026-11-26)**: everything needed for launch and Google's app verification first (capture mechanism, scope cut, cosmetic and smoothness fixes, the verification video), then note wording, then functional issues such as heat.

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

> **Folder names (confirmed by the user 2026-11-26)**: the active folders are `Work`, `Personal`, `Journal` and `Uncategorized`. `Ideas` and `Todos` were removed earlier because they described a kind of note rather than an area of life and clashed with the other folders. Users can add, describe, rename and remove folders of their own (FR11.14, FR17.1); `Uncategorized` always exists.

### B. Out-of-Scope (Explicit Non-Goals for v1.0)
- Multi-tag many-to-many graph tagging (reserved for v1.5; v1.0 organizes via 4-stage pipeline and predefined single-folder synthesis).
- Cloud synchronization (Dropbox, Google Drive, iCloud) or cross-device sync.
- Real-time streaming transcription while speaking (batch transcription post-capture is chosen for battery efficiency).
- Multi-track audio waveform visualizer / complex DAW editing tools (direct audio playback scrubber is supported).
- iOS platform support (iOS restricts background hardware button interception).

---

### C. Functional Requirements (FR)

#### FR1: Hardware Key Trigger & Volume Safety
> **Deferred until after the first public release (2026-11-26, see R1 above).** Not built into or declared by R1; the code is parked in `android/app/src/parked/hardware_trigger/`. The requirements below are kept for its return.

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
- **FR4.3 (Long Recordings in Segments, 2026-11-27)**: a recording longer than 40 seconds is transcribed in consecutive segments cut at the quietest moment, so memory does not grow with the length of the recording and the end of the recording is never lost; a recording of 40 seconds or less is transcribed exactly as before. Measured reason: one 5-minute call took 4.1 GB on the test phone.

#### FR5: On-Device LLM Pipeline (Two-Tier Post-Processing)
- **FR5.1**: The system must run an on-device quantized LLM (Qwen-2.5 1.5B GGUF) via `llama_cpp_dart`.
- **FR5.2 (Tier 1 — Capture Shows the Transcript As Spoken, No LLM)**: A raw capture is saved and displayed as the speech recognizer's transcript (with the recognizer's own punctuation and capitalization), including filler words and misspoken or self-corrected words. No LLM runs at capture time. Strictly NO grammar rewriting, filler removal, folder classification, style transformation, or color tinting is applied at this stage: the Capture stream is the user's fact check that everything spoken was heard. All cleanup, correction-resolving, condensing and filing belongs to Synthesis (FR5.4). *(Decided 2026-11-21; previously the LLM performed grammar and filler cleanup per capture.)*
- **FR5.3 (AI Style Re-Writer on Synthesized Notes)**: Users can re-write any synthesized note on-demand using preset style prompts (*Concise & Direct*, *Bullet Points*, *Professional*, *Journal/Reflective*, *Actionable*, *Casual*). The active style is indicated with a checkmark; changing styles transitions the note to Yellow (`pending re-processing`) for local LLM re-synthesis.
- **FR5.4 (Tier 2 — Synthesis & Single-Folder Classification)**: When notes are clustered, the LLM analyzes semantic similarity, assigns exactly one predefined folder (`Work`, `Personal`, `Journal`, `Uncategorized`, or fallback `Uncategorized`), and synthesizes fragments into a cohesive note. Arbitrary tag generation is strictly prohibited.
- **FR5.5 (No Fallback)**: Every LLM reply is validated (the organise turn must give each thought exactly one valid folder). An invalid or missing reply is retried a bounded number of times; until both the organise and the write turn have succeeded no session is created and the thoughts stay untouched in Capture (an existing session being rewritten keeps its previous note). There is no heuristic or keyword substitute for an LLM result. *(Decided 2026-11-21; previously a keyword classifier was the fallback.)*
- **FR5.6**: The system must purge the KV cache (`_llama.disposeScope()`) after every turn (`clearKvCacheEveryXTurns = 1`) to eliminate lingering RAM consumption.

#### FR6: Model Lifecycle & Memory Management
- **FR6.1**: The system must maintain three lifecycle states: `unloaded`, `loading`, and `ready`.
- **FR6.2**: Models must be loaded **sequentially** (STT first, LLM second) to prevent simultaneous memory allocation spikes above Android Low Memory Killer thresholds.
- **FR6.3**: When idle for 2 minutes (`modelInactivityTtl`; shortened from 3 minutes by the user on 2026-11-26), the system must automatically unload both models from RAM, reclaiming ~1.6 GB and restoring baseline footprint to <60 MB. A Synthesis run that is due does not wait for this timer: it unloads the idle speech model itself.
- **FR6.4**: Completing an item or interacting with the queue must touch the lifecycle manager, resetting the eviction timer.

#### FR7: Local Persistence
- **FR7.1**: Raw and synthesized thoughts must be saved to an embedded local database (Isar) containing `id`, `sequenceNumber`, `rawText`, `cleanedText`, `synthesizedContent`, `clusterId`, `folder`, `createdAt`, and `originalAudioPath`.
- **FR7.2**: The notes repository must support retrieval sorted by recency and filtered by stage (`capture`, `synthesis`) and by folder (`Work`, `Personal`, `Journal`, `Uncategorized`).

#### FR8: Background Reliability & Permissions
- **FR8.1**: The app must provide an Android Foreground Service (`EudemoniaForegroundService`) with an ongoing low-priority notification to protect the process from OS termination.
- **FR8.2**: The app must detect and request both Accessibility Service and Battery Optimization Exemption (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) simultaneously through an educational modal. **R1 (2026-11-26)**: the Accessibility Service is not requested (FR1 deferred) and the dual modal is removed; the permissions capture depends on in R1 are the microphone and notifications, each surfaced by a banner on the Capture screen with a one-tap fix when missing. **R1 does not request the battery exemption** (user decision 2026-11-26: Google Play restricts that permission and lists no voice-recording use); the foreground service and a bounded wake lock carry background processing.
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
  - The Capture screen features an elevated floating capsule: `[ 🎙️ / Press Vol Up + Down to Capture ]` with a prominent mic icon (`20sp`) and `"/"` separator. **R1**: the label reads `[ 🎙️ / Tap to capture ]` while FR1 is deferred.
  - The trigger is directly clickable in-app to start recording without physical volume buttons.
  - While recording, the pill transforms to show an active listening loader bar / pulsating audio waveform inside the button itself with elapsed time. Tapping again stops recording, enqueuing a Yellow pending note immediately with clean SnackBar feedback: `"Captured a new note [#0X]"` (free of internal implementation or debug filler text).
- **FR9.4**: Every capture note receives a daily sequence number (`#01`, `#02`, `#03`...). The counter resets to `#01` every day at midnight.
- **FR9.5**: Deleting a note leaves the numbering of subsequent notes intact (e.g., deleting `#02` preserves `#01`, `#03`, `#04`; gaps are explicitly allowed).
- **FR9.6**: The card heading layout must adhere to the strict order: `[# Number]` $\rightarrow$ `[▶ Play Audio]` $\rightarrow$ `[• Unread Dot]` $\rightarrow$ `[🗑️ Delete]`. This guarantees visual horizontal alignment across read and unread notes.
- **FR9.7**: Timestamps at the card footer must strictly display date then time: `DD/MM  HH:MM AM/PM` (e.g. `05/11  09:42 AM`).
- **FR9.8**: Tapping `[ ✎ Edit ]` allows manual text editing. (High-level AI Style Re-Writing is located in the Synthesis screen where final consolidated text is formed).
- **FR9.9 (Link to the Synthesized Note, user 2026-11-26)**: a thought that has been synthesized shows the number of its note; tapping it opens the Synthesis screen at that note.
- **FR9.10 (Unread Is About Reading, user 2026-11-26)**: a thought stays unread until the user has actually seen it (tap, or a few seconds in view, FR11.10). Being synthesized does not mark a thought as read.
- **FR9.11 (A Silent Recording Is Not a Failure, 2026-11-26)**: a recording in which nothing was heard is shown as a calm card (`Nothing was heard in this recording.`) with Play and Delete, not as a failed item.
- **FR9.12 (Filtered Views Hold Still, user 2026-11-27)**: on Capture and on Synthesis, an item listed under the Unread or Read filter stays listed while the user remains in that view even after it is marked read; it leaves only when the user picks a filter again or leaves the view.
- **FR9.13 (Delete Always Asks, user 2026-11-27)**: every delete asks for confirmation first and names what else changes: the note that will be deleted or rewritten with a thought, or what happens to the thoughts of a deleted note.
- **FR9.14 (Copy, user 2026-11-27)**: thoughts and notes have a Copy control, and a long press copies the text to the clipboard (notes as plain readable text).

#### FR10: Lock Screen & Notification Center Capture Trigger
- **FR10.1**: The persistent foreground service notification must host an interactive action button: `[ 🎙️ Record Thought ]`.
- **FR10.2**: Toggling the notification button must trigger start and stop of thought recording directly from the lock screen or notification shade without requiring device unlock.
- **FR10.3**: While recording is active, the notification must update dynamically to display an elapsed timer (`Recording 00:06...`) and a `[ ⏹ Stop & Save ]` action.
- **FR10.4 (Home-Screen Capture Widget, added 2026-11-26)**: The app provides a home-screen widget with one tap target: `Record thought` when idle; while recording it shows the running elapsed time and `Stop & save`. Settings offers `Add capture widget to home screen`.
- **FR10.5 (Capture Without the App, added 2026-11-26)**: Starting or stopping a recording from the notification or the widget must never open the app or bring it in front of what the user is doing, and must work when the app's screen has been closed. The recording is saved on the device at once; it is transcribed in the background while the app's process is alive, otherwise the next time the app is opened. The start and stop haptics (FR1.3 patterns) are given natively for every way of capturing.
- **FR10.6 (Nothing Shown Over the Lock Screen, added 2026-11-26)**: The app's screens and the user's notes are never displayed over the lock screen; only the notification with its timer and buttons is.
- **FR10.7 (Quick Settings Tile, user 2026-11-27; label shortened to `Record` on 2026-11-27 because the longer label scrolled)**: a `Record` tile in Quick Settings starts and stops a recording with one swipe and one tap, also from the locked phone, without opening the app. Settings offers to add the tile.
- **FR10.8 (Other Sound Pauses While Recording, user 2026-11-27)**: when a recording starts, the app asks other apps to pause their sound so that music playing on the phone is not recorded with the voice; playback resumes when the recording ends. No additional permission is involved.
- **FR10.9 (No Media-Player Style Lock-Screen Card, user 2026-11-27)**: rejected as redundant — a recording is stopped where it was started. A corner shortcut on the lock screen like Google Home's is not available to third-party apps on Pixel phones; the capture widget is marked as usable on the lock-screen widget page of recent Android versions.
- **FR10.10 (Recording Length Limit, user 2026-11-27)**: a recording is limited to 5 minutes ("for now"); the timer shows elapsed time and the limit (`1:30 / 5:00`); at the limit the recording stops and is saved exactly like a user stop. The limit is enforced natively and works with no app screen open.
- **FR10.11 (Record Button Everywhere, user 2026-11-27)**: the in-app record button is shown on Capture and on Synthesis and is never covered by a message. The app opens on Synthesis when at least one note exists, otherwise on Capture.

#### FR11: Synthesis, Predefined Folders & Session Clustering
- **FR11.1**: The system must automatically cluster disjointed raw notes captured within an active temporal window (e.g. 15–45 minutes) that share contextual continuity or topical affinity into a unified synthesized note.
- **FR11.2 (Compact Folder Filter Dropdown)**: The horizontal folder carousel is removed. The Synthesis view provides a compact folder filter dropdown (`[ 📁 Filter: All Folders ▾ ]`) situated in the section sub-header, allowing users to filter synthesized notes by predefined folder without taking up vertical screen real estate.
- **FR11.3 (Single-Folder Badge & 1-Tap Card Reassignment)**: Each synthesized note displays its assigned folder badge (`[ 💼 Work ▾ ]`, `[ 🏠 Personal ▾ ]`). Tapping opens a quick-picker dropdown to reassign the note among the predefined folders.
- **FR11.4**: Synthesized notes receive a sequential identifier (`#S-01`, `#S-02`), consolidated synthesis narrative, session time span (`05/11  07:10 AM - 07:45 AM`), session duration (`⏱️ 35m session`), and an expandable raw notes count pill (`[ 🧩 3 Raw Notes ▾ ]`). **Numbering (user, 2026-11-26)**: the counter restarts every calendar day, exactly like Capture's `#NN`; a session is identified by its day and its number, the number is given once when the session is created and never changes, and gaps left by deleted sessions are allowed. Where a session is referred to from another day, the day is shown with it (`#S-02 · 23/11`).
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
  - **Becoming read (user, 2026-11-26)**: a note is marked read by tapping it, or by itself once it has stayed in view for a few seconds; the unread dot then fades out with a small, noticeable dissolve. The same rule applies to thoughts on the Capture screen (FR9.10).
  - Synthesis cluster cards display an electric blue unread indicator dot (`• Unread`) when newly clustered.
  - The Synthesis screen sub-header provides an `[ 👁️ All Triage ▾ ]` dropdown (`All`, `Unread`, `Read`) alongside `[ 📁 All Folders ▾ ]` to filter new vs reviewed synthesized sessions.
- **FR11.11 (Active Session Horizon & 2D Domain-Bounded Clustering)**:
  - **2D Clustering Matrix (`Time Window ∩ Target Folder`)**: Thoughts captured within the temporal session window are strictly grouped by **target folder/domain**. If a user captures a technical work thought and a personal journal thought within the same 45-minute window, the system routes them into separate domain-specific active clusters (`#S-01` for Work, `#S-02` for Journal), preventing cross-domain narrative contamination.
  - **Sliding Inactivity Window ($Y=45$m)**: An active cluster remains open and receptive to incoming notes until 45 minutes elapse without new captures in that folder domain.
  - **Hard Session Ceiling ($T_{max}=2$ hours)**: To prevent runaway all-day monolithic clusters when capturing notes periodically throughout an 8-hour workday, an active cluster automatically finalizes at the 2-hour mark from its first note (`09:00 AM – 11:00 AM • ⏱️ 2h session`). Subsequent notes start a fresh cluster.
  - **Session Definition**: A session is temporal and belongs to one subject; one folder is one subject (single-level folders). It starts at the capture time of the first thought filed to that folder.
  - **Context-Aware Folder Assignment**: Folders are assigned by the LLM in one turn that sees all new thoughts together with the folder and current note of each open session. Thoughts carry no folder before this turn.
  - **Adding Thoughts to an Open Session**: While the session's raw thoughts fit the model's context window, the note is rewritten from the raw thoughts. Once they no longer fit, the LLM receives the existing note plus the new thoughts and must keep everything the new thoughts do not change. An open session is a live draft and is marked unread when its note changes; a closed session's note changes only on an explicit user action. *(Decided 2026-11-21; replaces the earlier delta-synthesis rule and its token figure.)*
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
  - **Default Note Style per Folder (proposed by the user 2026-11-22, decision pending)**: Settings may let the user choose, for each folder, the style in which its notes are written by default (for example bullets under headings for `Work`, flowing paragraphs for `Personal` or `Journal`). Not decided and not built; until then every folder uses the same structured style.
  - **Default Note Style per Folder — DECIDED (user 2026-11-27)**: every folder has an editable default style in Settings. A new note takes its folder's default style; moving a note to another folder rewrites it in that folder's default style; a style picked by hand on a note stays when later thoughts join it; changing a folder's default affects new notes only.
  - **Fidelity Before Brevity (user requirement 2026-11-22)**: whatever the style, a synthesized note must not lose details that were spoken — who, what, when, how many, and whether something has already happened or is only planned. A shorter note is never worth a missing or altered fact.
- **FR11.15 (Synthesized Notes Are Markdown, Shown Formatted — decided by the user 2026-11-26)**: the model's note is stored exactly as written, as Markdown (a title, short headings, `- ` bullets, `**bold**`). Every screen that shows a synthesized note renders it formatted: the title and headings in bold, bullets with a hanging indent, no literal `*` or `#` markers. The user's own spoken thoughts are plain text and are never interpreted as Markdown. Keeping notes as `.md` files for easy export is the stated direction (roadmap); only the display is required in R1.
- **FR11.16 (A Run Is Visible, user 2026-11-26)**: while Synthesis is running, every `Synthesize Now` control is disabled and shows a "thinking" indicator, and the pipeline pill says so. Starting a run never looks like nothing happened.
- **FR11.17 (Restyling a Note Works and Finishes, user 2026-11-26)**: choosing a style rewrites the note from its raw thoughts at once, with the card showing that it is being rewritten; the chosen style is kept when later thoughts join the note. If the model's answer is not valid, the note stays as it was and the user is told (no fallback text, FR5.5). The style `Actionable next steps` produces a checklist whose boxes the user can tick; ticks are stored in the note's Markdown (`- [x]`).
- **FR11.18 (Deleting or Editing a Thought Updates Its Note, user 2026-11-26)**: when a synthesized thought is deleted or its text edited, it is removed from (or updated in) the note's raw thoughts and the note is rewritten without waiting for a new thought; a note left with no thoughts is removed.
- **FR11.19 (A Note Edited by Hand Belongs to the User, user 2026-11-27)**: in Edit mode the user can edit a note's text. From then on the note is never rewritten automatically: a later thought that belongs to it is written on its own and added underneath under `Added later`; deleting or editing one of its raw thoughts changes the raw list only. Choosing a style is the one action that regenerates it from the raw thoughts, after a confirmation that this replaces the user's edits. Ticking a checklist box is not an edit.
- **FR11.20 (Synthesis Screen for Many Notes, approved by the user 2026-11-27)**: the screen is a list of note titles grouped by day (number, title, time, unread dot); a note opens in place when tapped, and several can be open. A folder panel slides in from the left when its button is tapped (never by swiping, which changes stages) and lists `All notes` and every folder with note and unread counts. A Read / Edit switch sits at the top: Read mode (default) shows only the note and a quiet link to its raw thoughts; Edit mode adds folder, style, text editing, merge, delete and the per-thought actions. A setting (`Show notes opened`) and a quick toggle show all notes opened or collapsed.
- **FR11.21 (A Recording Does Not Discard a Note Being Written, user 2026-11-27)**: recording is always instant. When a recording arrives during a Synthesis run, the note being written is finished and saved; then the run pauses, the thought is transcribed, and the run resumes with the new thought included. A run that is still sorting thoughts into folders stops at once. The two models are never in memory together.
- **FR11.22 (Requested Rewrites Always Happen, 2026-11-27)**: a note waiting to be rewritten (merge, moved or edited thought, style or folder change) is rewritten without further action from the user, also after the app is restarted.
- **FR11.23 (Moved-Out Thought Takes the Folder Style, user 2026-11-27)**: a thought moved out into its own note is written in the default style of its folder.
- **FR11.24 (Parked, user 2026-11-27)**: an automatically produced, read-only description of each folder built from its notes. The user found a version based only on note titles insufficient; to be designed later.

#### FR12: Thermal & Resource-Aware Adaptive Queue Gating
- **FR12.1**: The queue service must query Android native thermal status (`PowerManager.getThermalHeadroom()` and `OnThermalStatusChangedListener`).
- **FR12.2**: Audio capture and lightweight STT must never be throttled or blocked.
- **FR12.3**: If device thermal state reaches `THERMAL_STATUS_SEVERE` or `THERMAL_STATUS_CRITICAL`, or if available system RAM drops below 300MB, the system must defer on-device LLM post-processing into an adaptive backoff queue.
- **FR12.4**: As soon as device thermal headroom returns to safe levels (`THERMAL_STATUS_MODERATE` or lower), the queue worker must automatically resume deferred LLM inference.

#### FR13: System Observability & Telemetry Visualizers
- **FR13.1**: The Settings screen must render an interactive 24-hour battery consumption curve showing Eudemonia's background energy draw relative to device drain.
- **FR13.2**: The Settings screen must render a memory lifecycle timeline graph illustrating baseline idle RAM (<60MB), sequential load spikes during inference (~1.6GB), and the sharp reclamation curve following the inactivity eviction (FR6.3).
- **FR13.3**: The queue service and UI state must hydrate synchronously from disk (`queue.json`) on cold app restart within <50ms.

#### FR14: The Action Engine (Tasks & Calendar Time-Blocking)
> **Deferred until after the first public release (2026-11-26, see R1).** The Action tab is not shown in R1.

- **FR14.1**: During synthesis, the LLM extracts actionable commitments, producing structured action items with description, temporal anchor (`05/11  02:00 PM`), urgency level, and origin note link.
- **FR14.2**: The **Action** screen organizes commitments with interactive checkboxes, calendar time-block previews, and 1-tap `[ 📅 Push to Calendar ]` dispatch.
- **FR14.3**: Calendar account and sync configuration is managed in Settings; connection status is reflected live in the Action screen.

#### FR15: Insights Hub (Cognitive Climate & Recurrent Patterns)
> **Deferred until after the first public release (2026-11-26, see R1).** The Insights tab is not shown in R1.

- **FR15.1**: Evaluates reflective notes for psychological valence (-1.0 to +1.0) and cognitive energy (Low/High).
- **FR15.2**: The **Insights** screen visualizes a weekly/monthly emotional valence heatmap, topic cognitive density matrix, and surfaces recurrent thought patterns detected across sessions over time.

#### FR16: On-Device Model Delivery & Device-Fit Model Choice (Approved by the User 2026-11-26)
- **FR16.1 (Download Inside the App)**: The speech model and the language model are downloaded by the app itself, each started by the user, with visible progress, resumption after a lost connection, and a fingerprint (SHA-256) check before a file is ever used. A file that fails the check is discarded and reported. Downloads use Wi-Fi only unless the user allows mobile data.
- **FR16.2 (Capture Never Waits for a Model)**: Recording works before any model is present. Thoughts recorded without the speech model wait, visibly, and are transcribed as soon as it is ready; they are not marked failed.
- **FR16.3 (Choice of Language Model)**: The app offers a short list of validated language models. Each entry shows its download size, the memory it uses and a plain description of its quality. Entries too large for the phone's memory are greyed out and cannot be selected, with the reason stated. Only one language model is active at a time; the user can change or delete it in Settings.
- **FR16.4 (Only Models That Earn Their Place)**: A model is listed only if it has been measured to write notes that keep the spoken details on a phone of the class it is offered to (TASK-065). A smaller model that does not meet that bar is not listed.
- **FR16.5 (No Model, Honest Message)**: When no listed language model fits the phone, or none has been downloaded, Synthesis says so plainly and Capture and transcription keep working. No fallback output of any kind is produced (FR5.5).
- **FR16.6 (What the Network Is Used For)**: The network permission is used for these downloads only. No recording, transcript, note, identifier or usage data is sent anywhere.
- **FR16.7 (Small Writing Model Listed, user 2026-11-27)**: Qwen3 1.7B is offered on phones with 6 GB of memory or more, with a quality note saying its notes are less tidy and can miss a detail.
- **FR16.8 (Choice of Speech Model, user 2026-11-27)**: speech models are listed and chosen in the same way as writing models. Offered: Parakeet v3 (25 European languages) and Parakeet v2 (English only; clearly the most accurate for English on the user's own recordings). Only one speech model is in memory at a time. Which one is recommended to new users is not yet decided.

#### FR17: Settings Organisation (User, 2026-11-26)
- **FR17.1**: Settings opens on what the user changes most, in this order: Folders (FR11.14, with each folder's description, add, edit, rename and remove), automatic Synthesis, on-device models, the capture widget.
- **FR17.2**: `Phone memory and temperature` is second to last and `Permissions` is last; both are collapsed until opened.
- **FR17.3**: The in-app log viewer is not part of the first release (parked for later; the app still writes its rotating log file for support). Open-source and model credits are required by their licences (the speech model's licence demands attribution) but stay out of the way: one small `Open-source licences` link at the very bottom.

---

### D. Non-Functional Requirements (NFR)

| Category | Requirement | Target Metric / Benchmark |
| :--- | :--- | :--- |
| **Latency** | Audio Capture Dispatch | **< 5ms** from trigger release to queue handoff |
| **Latency** | Native Hardware Haptics | **< 20ms** from dual-key press to vibration pulse |
| **Latency** | On-Device STT Inference | **< 2.5s** per 10 seconds of recorded speech (Pixel 7a) |
| **Latency** | On-Device LLM Classification | Not applicable at capture since 2026-11-21 (no LLM in the capture path, FR5.2). A Synthesis-turn budget is to be set from measurement; the former **< 1.8s** per-thought target was measured unreachable on a Pixel 7a (~14.5s). |
| **Memory** | Baseline Idle RAM Footprint | **< 60 MB** when models are unloaded |
| **Memory** | Active Inference RAM Footprint | The speech model and the language model are never in memory together. Peak is set per language model from measurement and must leave a safe margin on the device: Qwen3-4B Q4_K_M **≤ 3.7 GB** (measured 3.58 GB on a Pixel 7a with 8 GB, context 4096, own engine), Qwen2.5-1.5B ≤ 1.9 GB; speech model ~600 MB. A model is offered only on devices with enough memory for it (roadmap: Device-Tier Model Recommendation). *(Restated 2026-11-22 with the user's agreement; previously < 1.6 GB.)* |
| **Memory** | Inactivity Eviction Timeout | Models evicted after **180 seconds (3 min)** of zero activity |
| **Battery** | 24-Hour Background Standby | **< 2.5%** total battery consumption in foreground listening mode |
| **Reliability** | Queue Failure Isolation | **100%**: A corrupt or silent audio file must never block the queue |
| **Reliability** | Queue Cold-Start Hydration | **< 50ms** hydration from disk on app restart |
| **Reliability** | UI Render Fluidity | **Locked 60/120fps** animation on processing indicators during active inference |
| **Reliability** | Thermal Safeguard | LLM deferred when thermal status >= `THERMAL_STATUS_SEVERE` |
| **Reliability** | App Crash-Free Rate | **> 99.9%** across background trigger cycles |
| **Privacy** | Network Transmission | **0 bytes**: Absolute zero outbound traffic for audio, text, or metrics. The only network use is the download of the on-device model files that the user starts (FR16, approved 2026-11-26); no user data is part of that request. |

---

## 6. User Experience (UX) & Four-Stage Interaction Architecture

> [!NOTE]
> **Complete UX Blueprint, Component Sandbox & Declarative Widget Code**:
> For the exhaustive design token dictionary, component sandbox architecture (`previews/`), ASCII wireframes, and component contracts for every screen, refer to [`UX.md`](file:///Users/harshmavani/Documents/Eudemonia/UX.md).

### A. The 4-Stage Navigation Shell
> **R1 (2026-11-26)**: the shell shows two stages, Capture and Synthesis, each half of the segmented bar; stages 3 and 4 below return with FR14 and FR15. Swiping left or right moves between the stages as well as tapping, and the tab highlight keeps the rounded shape of the bar (no rectangular flash).

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
- **Returning Right After the First Public Release (decided 2026-11-26, see Section 5 R1)**: the payment flow and the lock that leads to it; note-wording trials; the thermal and battery guard (FR12); the dual-volume-button trigger with its Accessibility declaration (FR1); the Action and Insights stages (FR14, FR15).
- **Notes as Markdown Files (requested 2026-11-26)**: synthesized notes are already stored as Markdown text; the aim is to keep them as `.md` files so the user can export them easily. Display of the Markdown is in R1 (FR11.15); file export is a later task.
- **AI-Assisted Topical Merge Suggestions (v1.5)**: Deterministic, zero-LLM entity and keyword set-intersection matching across the last 48 hours to display proactive suggestion pills (`[ 🔗 Similar to #S-01 (Marcus deliverables) • Merge? ]`).
- **Device-Tier Model Recommendation (v1.5)**: Recommend the on-device model best suited to the user's handset (RAM, chipset) from a small validated set of low, mid and high tier options, each measured for output quality, latency, memory and thermal impact. *(Detailed by the user 2026-11-22)*: on first launch the user chooses from 3–4 validated models, each shown with its memory footprint and a short quality description; models too large for the phone's memory are greyed out and cannot be selected; the chosen model is downloaded only after it is selected. Candidates to benchmark for 6 GB phones include SmolLM3 3B and SmolLM2-1.7B-Instruct.
- **Several Subjects Within One Folder (open question, parked 2026-11-21)**: Two unrelated subjects in one folder (e.g. two apps under `Work`) currently share a session. The intended answer is a separate single-level folder per subject; secondary tags may help. To be revisited once real synthesis output exists.
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
