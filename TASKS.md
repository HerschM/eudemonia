# TASKS.md — Eudemonia Active Task Tracker & Execution Backlog

> **Purpose**: This document tracks active and pending engineering tasks bridging [`PRODUCT_SPEC.md`](./PRODUCT_SPEC.md) (the *What* & *Why*) and [`IMPLEMENTATION.md`](./IMPLEMENTATION.md) (the *How* & *Architecture*).
>
> **Archive Reference**: Completed historical tasks (TASK-001 through TASK-036, TASK-047) are archived in [TASKS_archive.md](./TASKS_archive.md). Milestones 11–13 (TASK-052 through TASK-061) are complete and await archiving once the remaining on-device checks are done.
>
> **Context Optimization Rule**:
> - Never load the entire tasks file if you only need the active milestone.
> - For specifications, use heading-specific searches or line ranges in [PRODUCT_SPEC.md](./PRODUCT_SPEC.md) (e.g., `grep -n '## FR...' PRODUCT_SPEC.md`).
> - When executing tasks, activate the relevant skill: `.agents/skills/eudemonia-task-lifecycle/SKILL.md`.

---

## Active Work Handoff (Read First After Compaction or When Starting a New Agent)

> Maintained by the orchestrating agent. Updated at every stopping point so no context lives only in a conversation.

- **Working model**: An orchestrator (top-tier model) designs, briefs, reviews diffs and owns docs/git; `eudemonia-implementer` (Sonnet, Opus for native/concurrency work) writes code and tests; `eudemonia-verifier` (Haiku, read-only) runs the gate. See `AGENTS.md` Section 9.
- **Agreed order of work**: (B) TASK-062 LLM latency → (A) TASK-063 native capture core → (C) TASK-064 inference in its own process. A and C implement the target architecture in `IMPLEMENTATION.md` Section 4.C.
- **Verified on device (Pixel 7a, Android 17, 4 KB pages, serial `38031JEHN08164`)**: launch without crash, Isar on `isar_community` opens the existing database, STT worker isolate loads in ~5s and transcribes a short clip in ~1.6s, new Capture screen and floating capsule work, no 16 KB dialog.
- **Still unverified on device**: cross-process `RECORDING_STATE_CHANGED` haptic sync, first-launch permission prompt → foreground service start on a fresh install, `SystemTelemetryCollector` readings, crash-loop guard against a real native abort.
- **Current task**: TASK-062 is NOT closed (user decision 2026-11-20). Measured so far: 31.6s → 14.5s per ~40-word thought. User positions: 12–15s processing time is acceptable (results are not needed immediately); NO loss of grammar-correction quality or functionality is acceptable; smaller-model trials are deferred; a device-based model recommendation feature (low/mid/high tier, validated for output quality and resource use) is wanted as a FUTURE task; the user wants memory numbers for any KV-cache retention; the user asked for a robust voice-to-text test setup with real voice samples.
- **Plan awaiting user approval (proposed 2026-11-20, nothing below is started)**:
  1. *Test foundation*: voice-sample fixtures (16 kHz mono WAV + reference transcripts: synthetic via macOS `say`, plus real recordings from the user) and an on-device evaluation harness run via `flutter drive --keep-app-running` that reports STT word error rate, end-to-end WAV → STT → LLM → note results, LLM cleanup quality checks (valid JSON, no fallback, no dropped content, fillers removed, folder), per-stage timings and app memory (PSS via `SystemTelemetryService`).
  2. *Close TASK-062 against that harness*: (a) memory numbers at baseline / models loaded / during a turn / after eviction; (b) investigate whether `llama_cpp_dart` can keep the system-prompt prefix in the KV cache between turns without carrying earlier thoughts over, then implement it and amend FR5.6 if it works and the measured memory cost is acceptable; (c) long thoughts: scale the output budget with input length (today 256 tokens truncates ~180+ words into the fallback); (d) iterate the cleanup prompt until the quality checks pass, with greedy sampling.
  3. *Then* TASK-049, TASK-063, TASK-064. Orchestrator's assessment: TASK-049 does not make the per-thought cleanup turn faster (models already stay loaded for 3 minutes; clustering batches the synthesis turn, not the capture turn), so it need not go first; when it lands the capture prompt loses the folder and the harness is simply re-run.
  4. *Future task to add on approval*: device-tier model recommendation (needs a PRODUCT_SPEC entry first).
- **Open questions to the user**: approve the plan and order; supply ~10 real voice recordings or accept synthetic-only for now; whether to commit the current uncommitted work; confirm that FR5.6 may be relaxed if the measurements support it.
- **Device rule**: never run `flutter test integration_test/... -d <device>` (it uninstalls the app and wipes its data and models); use `flutter drive ... --keep-app-running` as documented in `test_driver/integration_test.dart`.
- **Known open product gaps (not started)**: `isReprocessing` (yellow) is never cleared; deleting a synthesis session leaves its thoughts `synthesized`; placeholders remain in Settings/HUD (`Google Calendar`, `Next refresh in 14h`, unsaved synthesis thresholds, no-op `Keep Raw Audio`, in-memory folder manifestos); capture-time folder inference deviates from FR5.2 until TASK-049.

---

## Task Status Legend
- `[x]` **Completed**: Implemented, verified with unit/widget tests, and passing all quality gates.
- `[/]` **In Progress**: Active development or test coverage underway.
- `[ ]` **Pending**: Ready for pickup within the active milestone.

---

## Milestone 9: Deep Synthesis Clustering, Folder Manifestos & Merge Architecture (In-Scope Active)

- [ ] **TASK-041: Multi-Select Mode & Manual "Club Thoughts" Action**
  - **Area**: `lib/features/capture/presentation/multi_select_action_bar.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering`](./PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering) (`FR11.5: Manual multi-select mode with floating Club Thoughts action`)
  - **Details**: Implement long-press selection mode on capture cards. Display circular selection checkboxes and bottom floating bar: `[ X Selected ] [ 🧩 Club Thoughts ]`. Tapping button invokes LLM synthesis turn across selected thoughts.
  - **Verification**:
    - **Unit Tests**:
      - File: `test/features/notes/multi_select_coordinator_test.dart`
      - Cases:
        1. Toggling note selection adds/removes ID from active selection set.
        2. Clearing selection exits selection mode.
    - **Widget Tests**:
      - File: `test/features/home/multi_select_action_bar_test.dart`
      - Cases:
        1. Long pressing thought card renders selection checkboxes.
        2. Floating bar displays count of selected items.
        3. Tapping "Club Thoughts" invokes clubbing callback with selected IDs.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/multi_select_action_bar_test.dart`

- [ ] **TASK-042: Synthesis Card, Origin Audit Drawer & Raw Note Ejection**
  - **Area**: `lib/features/synthesis/presentation/synthesis_card.dart`, `lib/features/synthesis/presentation/note_ejection_modal.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering`](./PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering) (`FR11.6: Synthesis note presentation, FR11.7: Origin audit view, FR11.8: Raw note ejection`)
  - **Details**: Build presentational widget for synthesized notes (`#S-01`, predefined folder badge `[ 💡 Ideas ▾ ]` with 1-tap reassignment dropdown, consolidated summary, session time span, duration). Include expandable raw notes count drawer (`[ 🧩 3 Raw Notes ▾ ]`). Inside expanded drawer, add `[ ⤢ Move Out ]` button presenting dialog to (1) Move to another clubbed note or (2) Make it an independent synthesized note.
  - **Verification**:
    - **Unit Tests**:
      - File: `test/features/synthesis/synthesis_model_test.dart`
      - Cases:
        1. Synthesized cluster holds references to list of origin raw notes.
        2. Ejecting raw note removes reference and triggers cluster re-synthesis.
        3. Promoting raw note to independent note creates standalone synthesized entry.
    - **Widget Tests**:
      - File: `test/features/synthesis/synthesis_card_test.dart`
      - Cases:
        1. Renders synthesis note with #S-01 badge, predefined folder pill, and session duration.
        2. Tapping raw notes pill expands list of origin thoughts.
        3. Tapping "Move Out" opens ejection modal with two distinct actions.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/synthesis/synthesis_card_test.dart`

- [ ] **TASK-048: Semantic Folder Manifestos & Custom Folder Management Repository**
  - **Area**: `lib/features/notes/data/folder_manifesto_model.dart`, `lib/features/notes/data/folders_repository.dart`, `lib/features/settings/presentation/folder_management_widget.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering`](./PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering) (`FR11.14: Semantic Folder Manifestos & Custom Folder Management`)
  - **Details**: Implement `FolderManifesto` persistent model in Isar (`id`, `name`, `description`, `autoGeneratedSummary`, `lastUpdated`). Provide CRUD operations in `FoldersRepository` for adding custom folders and updating descriptions. Build Settings UI section allowing users to view manifestos, edit descriptions, and add new custom folders. Include background worker to refresh `autoGeneratedSummary` every 5 notes.
  - **Verification**:
    - **Unit Tests**:
      - File: `test/features/notes/folders_repository_test.dart`
      - Cases:
        1. Seeds default folders (`Work`, `Ideas`, `Todos`, `Journal`) with baseline descriptions.
        2. Creates new custom folder and persists to database.
        3. Updates folder description and verifies change persists.
        4. Injects folder descriptions into `NoteClassifier` ChatML prompt.
    - **Widget Tests**:
      - File: `test/features/settings/folder_management_widget_test.dart`
      - Cases:
        1. Renders list of folders with names, note counts, and descriptions.
        2. Tapping `+ Add Custom Folder` opens creation dialog and submits new folder.
        3. Tapping `Edit` opens description editor and saves updated manifesto.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/notes/folders_repository_test.dart`

- [ ] **TASK-049: 2D Active Session Horizon Clustering & Delta Synthesis Engine**
  - **Area**: `lib/features/ai_processing/note_clustering_service.dart`, `lib/features/notes/data/synthesis_session_model.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering`](./PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering) (`FR11.11: Active Session Horizon & 2D Domain-Bounded Clustering`)
  - **Details**: Implement 2D session clustering combining temporal proximity ($Y=45$m sliding idle window, $T_{max}=2$ hours hard ceiling) and target folder domain. If a user dictates notes across two distinct folders in the same window, route them to separate active clusters. Implement delta synthesis integrating incoming raw notes into an active cluster summary without re-running full context from scratch.
  - **Verification**:
    - **Unit Tests**:
      - File: `test/features/ai_processing/session_clustering_test.dart`
      - Cases:
        1. Routes incoming note within 45m window and same folder into existing active cluster.
        2. Routes note within 45m window but different folder into a separate active cluster.
        3. Finalizes cluster when 45 minutes of quiet elapse.
        4. Forces cluster finalization when session duration reaches 2-hour hard ceiling.
        5. Delta synthesis prompt integration passes existing summary and delta thoughts.
    - **Widget Tests**:
      - N/A — Backend clustering and LLM orchestration service.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/session_clustering_test.dart`

- [ ] **TASK-050: Delta Action Extraction & Task State Immutability**
  - **Area**: `lib/features/ai_processing/action_extractor.dart`, `lib/features/action/data/action_item_model.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering`](./PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering) (`FR11.12: Delta Action Extraction & Task State Immutability`)
  - **Details**: When an active cluster receives new notes after initial action extraction has occurred, run an additive delta action extraction pass. Pass existing tasks to the prompt to extract strictly new or modified actions. Ensure existing tasks in Isar (including completed ones with `isCompleted = true`) retain their IDs and state without duplicates or resets.
  - **Verification**:
    - **Unit Tests**:
      - File: `test/features/ai_processing/delta_action_extraction_test.dart`
      - Cases:
        1. Initial extraction extracts commitments from newly synthesized narrative.
        2. Delta extraction pass on cluster update extracts only newly introduced tasks.
        3. Completed tasks in database retain `isCompleted = true` across delta pass.
        4. Duplicate actions matching existing task signatures are discarded.
    - **Widget Tests**:
      - N/A — Action extraction domain service.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/delta_action_extraction_test.dart`

- [ ] **TASK-051: Explicit Synthesis Note Merging UI & State Consolidation**
  - **Area**: `lib/features/synthesis/presentation/synthesis_screen.dart`, `lib/features/synthesis/presentation/note_merge_modal.dart`, `lib/features/synthesis/synthesis_repository.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering`](./PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering) (`FR11.13: Explicit Synthesis Note Merging`)
  - **Details**: Implement `[ 🔗 Merge ]` action on synthesis cluster cards. Build `NoteMergeModal` listing other existing sessions. Selecting a target session moves all origin raw notes into target session, removes source session from database, and flags target session for Yellow re-synthesis with clean SnackBar feedback: `"Merged #S-02 into #S-01"`.
  - **Verification**:
    - **Unit Tests**:
      - File: `test/features/synthesis/synthesis_merge_test.dart`
      - Cases:
        1. Consolidates origin raw notes from source cluster into target cluster.
        2. Deletes source cluster from database.
        3. Marks target cluster as `ThoughtState.enqueued` (Yellow) for re-synthesis.
    - **Widget Tests**:
      - File: `test/features/synthesis/note_merge_ui_test.dart`
      - Cases:
        1. Tapping `[ 🔗 Merge ]` opens merge sheet showing available target sessions.
        2. Selecting target session triggers merge callback and shows clean SnackBar.
        3. Source card is removed from feed and target card transitions to Yellow re-processing.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/synthesis/synthesis_merge_test.dart`

---

## Milestone 11: Capture Pipeline Hardening — Queue Recovery, Off-Thread STT, Model Eviction Safety & Native State Sync (Completed)

- [x] **TASK-052: Off-Thread Speech Recognition via Dedicated STT Worker Isolate**
  - **Area**: `lib/features/ai_processing/stt_service.dart`, `lib/features/ai_processing/stt_engine.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr2-non-blocking-audio-capture`](./PRODUCT_SPEC.md#fr2-non-blocking-audio-capture) (`FR2.3: Audio capture must never await model loading`) and [`PRODUCT_SPEC.md#fr4-on-device-speech-recognition-stt`](./PRODUCT_SPEC.md#fr4-on-device-speech-recognition-stt)
  - **Details**: Run Sherpa-ONNX model loading and decoding inside a long-lived worker isolate so the UI isolate that services capture triggers is never blocked by inference. Preserve resampling, tail padding, and native stream cleanup.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/stt_service_isolate_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/stt_service_isolate_test.dart)
      - Cases:
        1. Transcribe before initialize throws; initialize then transcribe returns engine text.
        2. Load failure propagates and leaves the service uninitialized; a later load succeeds.
        3. Engine failure fails only that request.
        4. Decoding does not block the calling isolate.
        5. Dispose during an in-flight transcription lets it finish; reinitialize works.
        6. `resampleLinear` passthrough and 48kHz → 16kHz reduction.
    - **Widget Tests**:
      - N/A — Non-UI component.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/stt_service_isolate_test.dart`
      - **Pending on-device check**: transcribe a real recording on hardware (no device was attached during implementation).

- [x] **TASK-053: Audio Queue Cold-Start Recovery, Atomic Persistence & Stable Daily Sequence Numbers**
  - **Area**: `lib/features/ai_processing/audio_queue_service.dart`, `lib/features/notes/data/notes_repository.dart`, `lib/main.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr3-persistent-fifo-audio-queue`](./PRODUCT_SPEC.md#fr3-persistent-fifo-audio-queue) (`FR3.1, FR3.2, FR3.4`), [`PRODUCT_SPEC.md#fr13-system-observability--telemetry-visualizers`](./PRODUCT_SPEC.md#fr13-system-observability--telemetry-visualizers) (`FR13.3`), and [`PRODUCT_SPEC.md#fr9-capture-screen-presentation-status-colors--dual-filters`](./PRODUCT_SPEC.md#fr9-capture-screen-presentation-status-colors--dual-filters) (`FR9.4, FR9.5`)
  - **Details**: Reset interrupted items to `pending` and prune `completed` items on hydration; resume the queue on app launch; make `enqueue()` wait for hydration; serialize and atomically write `queue.json`; issue daily sequence numbers from an in-memory high-water mark without scanning the database on the capture path; never save a note for a thought deleted mid-processing; delete the raw audio file when a note is deleted.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/queue_resilience_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/queue_resilience_test.dart)
      - Cases:
        1. Items interrupted mid-inference are handed back to the worker as pending.
        2. Completed items are pruned on hydration.
        3. A capture enqueued before hydration settles does not drop persisted items.
        4. `resumePendingWork` hydrates and drains the leftover queue.
        5. Rapid successive mutations always leave a parseable queue file.
        6. Sequence continues from the highest number persisted today; deleting the newest thought leaves a gap.
        7. A thought deleted mid-inference is not resurrected as a note.
        8. A failing item does not block the items behind it.
      - File: [`test/features/notes/notes_repository_cleanup_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/notes/notes_repository_cleanup_test.dart)
      - Cases:
        1. `deleteNote` removes the raw audio recording; succeeds when the file is already gone.
        2. `maxDailySequenceFor` only considers notes from the given calendar day.
    - **Widget Tests**:
      - N/A — Non-UI component.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/queue_resilience_test.dart test/features/notes/notes_repository_cleanup_test.dart`

- [x] **TASK-054: Model Lifecycle Eviction Safety, Partial-Load Cleanup & Reactive Memory State**
  - **Area**: `lib/features/ai_processing/model_lifecycle_manager.dart`, `lib/features/settings/settings_screen.dart`, `lib/features/home/presentation/main_navigation_shell.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr6-model-lifecycle--memory-management`](./PRODUCT_SPEC.md#fr6-model-lifecycle--memory-management) (`FR6.1–FR6.4`)
  - **Details**: Restart the inactivity countdown after failed items; dispose both models when a load fails part-way; share one load future across callers; defer eviction while inference is in flight; expose lifecycle state through a synchronous `NotifierProvider` for the HUD and Settings.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/model_lifecycle_manager_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/model_lifecycle_manager_test.dart)
      - Cases:
        1. A failed LLM load releases the already-loaded STT model.
        2. Every concurrent caller observes a load failure and a retry can succeed.
        3. Eviction requested during inference is deferred until the task completes.
        4. Eviction requested while loading waits for the load, then unloads.
        5. `runWithModels` restarts the inactivity countdown even when the task throws.
        6. State transitions are reported to the `onStateChanged` listener.
      - File: [`test/features/ai_processing/queue_resilience_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/queue_resilience_test.dart)
      - Cases:
        1. Models are still evicted after the TTL when every item fails.
    - **Widget Tests**:
      - File: [`test/features/settings/production_settings_screen_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/settings/production_settings_screen_test.dart)
      - Cases:
        1. Evict button reports reclaimed memory (existing case, unchanged).
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/model_lifecycle_manager_test.dart`

- [x] **TASK-055: Capture Controller Extraction & Truthful Recording State with Native Sync**
  - **Area**: `lib/features/capture/capture_controller.dart`, `lib/features/home/home_screen.dart`, `lib/features/ai_processing/audio_recording_service.dart`, `android/app/src/main/kotlin/com/eudemonia/eudemonia/RecordingStateTracker.kt`, `ButtonInterceptorService.kt`, `MainActivity.kt`, `EudemoniaForegroundService.kt`
  - **Spec**: [`PRODUCT_SPEC.md#fr1-hardware-key-trigger--volume-safety`](./PRODUCT_SPEC.md#fr1-hardware-key-trigger--volume-safety) (`FR1.3`), [`PRODUCT_SPEC.md#fr2-non-blocking-audio-capture`](./PRODUCT_SPEC.md#fr2-non-blocking-audio-capture) (`FR2.1, FR2.2`), and [`PRODUCT_SPEC.md#fr10-lock-screen--notification-center-capture-trigger`](./PRODUCT_SPEC.md#fr10-lock-screen--notification-center-capture-trigger) (`FR10.2, FR10.3`)
  - **Details**: Move hardware trigger handling out of `HomeScreen` into a Riverpod `CaptureController`; revert recording state when the microphone fails to start; report the authoritative state to native so the interceptor's start/stop haptic and the notification stay correct; make notification actions idempotent via `desiredRecording`.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/capture/capture_controller_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/capture/capture_controller_test.dart)
      - Cases:
        1. Trigger starts recording; second trigger stops and enqueues.
        2. Recording state reverts when the microphone could not start.
        3. Native side is told the authoritative state after every trigger, including failed starts.
        4. Explicit stop while idle and explicit start while recording are no-ops.
        5. A bounce within the 500ms cooldown is dropped.
      - File: [`android/app/src/test/kotlin/com/eudemonia/eudemonia/RecordingStateTrackerTest.kt`](file:///Users/harshmavani/Documents/Eudemonia/android/app/src/test/kotlin/com/eudemonia/eudemonia/RecordingStateTrackerTest.kt)
      - Cases:
        1. Triggers alternate between start and stop.
        2. A dropped trigger is corrected by the authoritative state.
        3. A recording started elsewhere makes the next trigger a stop.
      - File: [`android/app/src/test/kotlin/com/eudemonia/eudemonia/EudemoniaForegroundServiceTest.kt`](file:///Users/harshmavani/Documents/Eudemonia/android/app/src/test/kotlin/com/eudemonia/eudemonia/EudemoniaForegroundServiceTest.kt)
      - Cases:
        1. `deliverTrigger` forwards `desiredRecording` for explicit notification actions.
    - **Widget Tests**:
      - N/A — Controller and native components; existing `HomeScreen` widget suites remain green.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/capture/capture_controller_test.dart`
      - `cd android && ./gradlew :app:testDebugUnitTest`
      - **Pending on-device check**: cross-process `RECORDING_STATE_CHANGED` delivery and haptic patterns.

- [x] **TASK-056: Foreground Service Microphone Permission Gate & Offline-Only Release Manifest**
  - **Area**: `android/app/src/main/kotlin/com/eudemonia/eudemonia/MainActivity.kt`, `EudemoniaForegroundService.kt`, `android/app/src/main/AndroidManifest.xml`
  - **Spec**: [`PRODUCT_SPEC.md#fr8-background-reliability--permissions`](./PRODUCT_SPEC.md#fr8-background-reliability--permissions) (`FR8.1`) and [`PRODUCT_SPEC.md#d-non-functional-requirements-nfr`](./PRODUCT_SPEC.md#d-non-functional-requirements-nfr) (`Privacy: 0 bytes network transmission`, `App Crash-Free Rate`)
  - **Details**: Request `RECORD_AUDIO` (and `POST_NOTIFICATIONS` on API 33+) while the activity is visible and start the `microphone` foreground service only once the microphone is granted; report the service as running only after `startForeground()` succeeds; remove the `INTERNET` permission from the release manifest.
  - **Verification**:
    - **Unit Tests**:
      - N/A — Android framework permission and service-start paths are not reachable from JVM unit tests (no Robolectric in the project); existing service suites remain green.
    - **Widget Tests**:
      - N/A — Native Android component.
    - **Integration / Command Tests**:
      - `cd android && ./gradlew :app:testDebugUnitTest`
      - `~/flutter/bin/flutter build apk --debug`
      - **Pending on-device check**: fresh-install launch on Android 14+ (permission prompt, then service start).

---

## Milestone 12: Durable Synthesis Sessions, Spec-Conformant Capture Screen & Live System Telemetry (Completed)

- [x] **TASK-057: Persist Synthesis Sessions with Write-Through Storage & Orphaned Thought Repair**
  - **Area**: `lib/features/synthesis/data/synthesis_session_record.dart`, `lib/features/synthesis/data/synthesis_session_store.dart`, `lib/features/synthesis/data/synthesis_repository.dart`, `lib/core/database/app_database.dart`, `lib/main.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr7-local-persistence`](./PRODUCT_SPEC.md#fr7-local-persistence) (`FR7.1: Raw and synthesized thoughts must be saved to an embedded local database`) and [`PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering`](./PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering) (`FR11.4, FR11.10`)
  - **Details**: Store synthesis sessions in a new Isar collection (schema change approved by the user), write every repository mutation through to it, hydrate on launch, share one Isar instance across repositories, and repair thoughts orphaned by the previous in-memory implementation.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/synthesis/synthesis_persistence_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/synthesis/synthesis_persistence_test.dart)
      - Cases:
        1. Sessions created in one launch are restored in the next, with their origin thoughts.
        2. Read, folder, style, merge and delete edits are durable.
        3. A session created after a restart continues the identifier sequence.
        4. Transient view state (`isExpanded`) is not persisted.
        5. Orphaned synthesized thoughts return to the clustering buffer; claimed thoughts stay put.
        6. `SynthesisSessionRecord` round-trips every durable field.
    - **Widget Tests**:
      - File: [`test/features/synthesis/synthesis_screen_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/synthesis/synthesis_screen_test.dart)
      - Cases:
        1. Existing synthesis screen suites remain green on the persisted repository.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/synthesis/`
      - **Pending on-device check**: the Isar-backed path (host tests exercise the in-memory store, which holds the same records).

- [x] **TASK-058: Capture Screen per FR9 — Dual Dropdown Filters, Floating Capture Trigger & No Folder Categorization**
  - **Area**: `lib/features/capture/presentation/capture_screen.dart`, `lib/features/capture/presentation/floating_capture_capsule.dart`, `lib/features/notes/presentation/thought_card.dart`, `lib/features/home/presentation/main_navigation_shell.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr9-capture-screen-presentation-status-colors--dual-filters`](./PRODUCT_SPEC.md#fr9-capture-screen-presentation-status-colors--dual-filters) (`FR9.1–FR9.8`) and [`PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering`](./PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering) (`FR11.2: The horizontal folder carousel is removed`)
  - **Details**: Promote the approved capture preview into production: replace `HomeScreen`/`NoteListScreen` with `CaptureScreen`, remove folder UI from capture cards, add triage and status dropdowns, per-day headers, the clickable floating capture capsule with waveform and elapsed timer, and `Captured a new note [#0X]` feedback. Capture-time folder inference stays as hidden metadata until TASK-049 (documented deviation from FR5.2).
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/capture/capture_controller_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/capture/capture_controller_test.dart)
      - Cases:
        1. `handleTrigger` returns the queued capture only when it finishes a recording.
    - **Widget Tests**:
      - File: [`test/features/capture/capture_screen_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/capture/capture_screen_test.dart)
      - Cases:
        1. Renders dual dropdown filters and floating capsule without the folder carousel, on 360dp with 0 overflows.
        2. Groups thoughts under a day header and shows no folder on any card.
        3. Ambient permission banner appears while permissions are missing.
        4. Failed item renders in-card with Retry and is isolated by the Failed status filter.
        5. Synthesized filter shows only clubbed thoughts, labelled with their session.
        6. Filters that match nothing explain themselves.
        7. Capsule tap starts listening with an elapsed timer; tapping again captures with clean SnackBar feedback.
      - File: [`test/features/home/pipeline_pill_cold_start_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/home/pipeline_pill_cold_start_test.dart)
      - Cases:
        1. Pipeline pill and Capture badge show hydrated pending items immediately on launch (supersedes the TASK-024/TASK-025/TASK-031 AppBar pill and in-body banner cases).
      - Files: `test/features/home/thought_card_interaction_test.dart`, `thought_card_states_test.dart`, `unread_triage_test.dart`, `feed_immediate_hydration_and_playback_test.dart`, `test/features/notes/note_sequence_and_overflow_test.dart` (migrated from chips and category picker to the FR9 contracts).
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/capture/ test/features/home/`

- [x] **TASK-059: Live Device Thermal & Memory Telemetry in Settings and Pipeline HUD**
  - **Area**: `android/app/src/main/kotlin/com/eudemonia/eudemonia/SystemTelemetryCollector.kt`, `MainActivity.kt`, `lib/features/settings/system_telemetry_service.dart`, `lib/features/settings/settings_screen.dart`, `lib/features/home/presentation/pipeline_hud_modal.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr12-thermal--resource-aware-adaptive-queue-gating`](./PRODUCT_SPEC.md#fr12-thermal--resource-aware-adaptive-queue-gating) (`FR12.1: query Android native thermal status`) and [`PRODUCT_SPEC.md#fr13-system-observability--telemetry-visualizers`](./PRODUCT_SPEC.md#fr13-system-observability--telemetry-visualizers)
  - **Details**: Replace hardcoded thermal headroom and RAM figures with readings from `PowerManager`, `Debug.getMemoryInfo` and `ActivityManager.MemoryInfo`; show `Unavailable` when the OS cannot provide a value. Display only — thermal gating of the queue remains TASK-038.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/settings/system_telemetry_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/settings/system_telemetry_test.dart)
      - Cases:
        1. Maps a full OS reading and derives display values; clamps past the severe threshold.
        2. Values the device cannot report stay unavailable.
        3. Service reads a snapshot and returns null when the platform cannot be queried.
    - **Widget Tests**:
      - File: [`test/features/settings/system_telemetry_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/settings/system_telemetry_test.dart)
      - Cases:
        1. Settings shows OS thermal headroom and memory and refreshes while open (360dp).
        2. Settings shows `Unavailable` rather than invented figures.
        3. Pipeline HUD opens immediately and fills in the live reading.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/settings/system_telemetry_test.dart`
      - `cd android && ./gradlew :app:testDebugUnitTest`
      - **Pending on-device check**: `SystemTelemetryCollector` values on real hardware (framework calls are not reachable from JVM unit tests).

---

## Milestone 14: On-Device LLM Latency & Capture-Independent Architecture (In-Scope Active)

- [/] **TASK-062: Bring On-Device LLM Turn Latency Within Budget (Measured, CPU vs GPU Offload, Sampling & Prompt Size)**
  - **Area**: `lib/features/ai_processing/llm_config.dart`, `lib/features/ai_processing/llm_service.dart`, `lib/features/ai_processing/note_classifier.dart`, `integration_test/llm_latency_benchmark_test.dart`
  - **Spec**: [`PRODUCT_SPEC.md#d-non-functional-requirements-nfr`](./PRODUCT_SPEC.md#d-non-functional-requirements-nfr) (`Latency: On-Device LLM Classification < 1.8s`) and [`PRODUCT_SPEC.md#fr5-on-device-llm-pipeline-two-tier-post-processing`](./PRODUCT_SPEC.md#fr5-on-device-llm-pipeline-two-tier-post-processing)
  - **Details**: Measured on the Pixel 7a before any change: model load ~28s, one capture turn 24.6s (the generation timeout is 25s, after which the heuristic fallback is used silently). Evidence so far: `LLMService` passes library-default `ModelParams()` whose `nGpuLayers = 99` offloads every layer to the bundled Vulkan backend, and library-default `SamplerParams()` (temperature 0.8, non-greedy) for a strict-JSON task. Plan: (1) make GPU offload and greedy sampling explicit `LLMConfig` fields and add an on-device benchmark; (2) choose defaults from the measurements; (3) if still over budget, shrink the prompt and the output schema (the `reasoning` and `confidence_scores` fields are generated tokens). FR5.6 (purge KV cache every turn) stays in force, so prompt-prefix caching is not an option without a spec change.
  - **Progress Log**:
    - Step 1 (done, uncommitted): `LLMConfig.gpuLayers` (default 99) and `LLMConfig.greedySampling` (default false) added and wired into `LLMService.initialize()`; `integration_test/llm_latency_benchmark_test.dart` added (`integration_test` dev dependency).
    - Benchmark run 1 on Pixel 7a (2 turns per variant, ~40-word transcript; the run took 18 min and heated the phone):

      | Variant | Load | Turn 1 | Turn 2 | Fallback |
      | :--- | :--- | :--- | :--- | :--- |
      | GPU offload 99, 4 threads, sampled (current) | 34.4s | 30.5s | 49.4s | yes |
      | CPU only, 4 threads, sampled | 5.9s | 85.1s | 99.7s | yes |
      | CPU only, 4 threads, greedy | 13.0s | 85.2s | 111.4s | yes |
      | CPU only, 2 threads, greedy | 7.5s | 85.2s | 504.5s (outlier, likely thermal) | yes |

    - Findings from run 1: (a) the GPU-offload hypothesis is refuted — Vulkan offload is ~3x faster per turn than CPU on this device, at the cost of a ~30s load; keep `gpuLayers = 99`. (b) Every turn fell back to the heuristic and the numbers are not real latencies: `processText()` times out at 25s but never stops generation; `clearKvCache()` → `disposeScope()` then waits for the model to run to `maxOutputTokens`, and the partial buffer captured at the timeout fails JSON parsing. This is a production bug: a slow turn blocks the queue well past 25s and yields only the fallback. (c) Greedy vs sampled made no measurable difference to speed.
    - Step 2 (done, uncommitted): `LLMConfig.generationTimeout` (default 25s); on timeout `processText()` now calls `LlamaParent.stop()` so the turn ends promptly; `LlmTurnMetrics` (`lastTurnMetrics`: time to first token, total, chunks, timedOut, usedFallback, rawOutput) logged per turn; benchmark rewritten (one turn per variant, 240s timeout, 30s cool-down); `test_driver/integration_test.dart` added.
    - **Device safety rule learned the hard way**: `flutter test integration_test/... -d <device>` UNINSTALLS the app when it finishes, wiping its database, recordings and the model files under `/sdcard/Android/data/com.eudemonia.eudemonia/files`. Run 1 did this to the user's phone (test notes lost). Always use `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/<file> -d <device> --keep-app-running`, then reinstall the normal build with `adb install -r build/app/outputs/flutter-apk/app-debug.apk`. Models are restored with `bash download_models.sh`.
    - Benchmark run 2 on Pixel 7a (real completions, no timeout, ~40-word transcript, greedy):

      | Variant | Load | Time to first token (prompt eval) | Generation | Total | Speed |
      | :--- | :--- | :--- | :--- | :--- | :--- |
      | GPU offload 99, 4 threads | 3.9s (warm) | 11.3s | 20.3s for 148 chunks | 31.6s | 7.3 chunks/s |
      | CPU only, 4 threads | 6.9s | 15.0s | 115.1s for 137 chunks | 130.1s | 1.2 chunks/s |
      | CPU only, 6 threads | 5.3s | 13.6s | 148.5s for 137 chunks | 162.0s | 0.9 chunks/s |

    - Findings from run 2: GPU offload is 6x faster at generation; keep it. A ~40-word thought takes 31.6s, which exceeds the 25s timeout, so in the shipped configuration such thoughts always fall back to the heuristic. Of the 148 output chunks only ~55 are the corrected text; the rest are a markdown fence, `confidence_scores` (~45) and `reasoning` (~35), none of which is shown to the user. The system prompt costs ~11s of evaluation every turn because FR5.6 forbids keeping its KV state.
    - Step 3 (done, uncommitted): `NoteClassifier.buildPrompt()` shortened and reduced to a two-key reply with the folder first (`{"folder": ..., "corrected_text": ...}`); `generationTimeout` default raised to 60s; `greedySampling` default set to `true`; a reply with no folder and no keyword evidence now resolves to `Uncategorized` instead of silently becoming `Work`. The benchmark now runs only the two GPU variants and prints the raw reply of each.
    - Benchmark run 3 (first trimmed prompt, text-first reply): 13.1s greedy / 10.4s sampled, but the model omitted the `folder` key entirely — rejected, led to the folder-first format.
    - Benchmark run 4 on Pixel 7a (final prompt, same ~40-word transcript):

      | Variant | Load | Time to first token | Generation | Total | Reply |
      | :--- | :--- | :--- | :--- | :--- | :--- |
      | GPU offload, greedy (**shipped default**) | 2.7s (warm) | 8.7s | 5.8s for 60 chunks (10.4/s) | **14.5s** | folder present, every sentence kept |
      | GPU offload, sampled | 9.6s | 7.2s | 4.7s for 48 chunks | 11.9s | folder present, **dropped the final sentence** |

    - Outcome: 31.6s (and always timing out into the fallback) → 14.5s with a real LLM result. Greedy is the default because sampling lost content. Known residue: the 1.5B model still leaves some discourse fillers ("basically", "so yeah") while removing "um"/"uh".
    - **Residual gap and open decision (user)**: the 1.8s NFR is not reachable with this model on this device (rewriting ~55 tokens at ~10 tokens/s is ~6s on its own, plus ~8s re-evaluating the prompt because FR5.6 purges the KV cache each turn). Options put to the user on 2026-11-19: (1) accept ~12–15s and revise the NFR; (2) relax FR5.6 to cache the system-prompt prefix; (3) try a smaller model; (4) rule-based cleanup with LLM for folder only. Orchestrator recommendation: 1 + 2. No option is implemented until the user chooses.
    - Not yet addressed: `maxOutputTokens = 256` truncates the rewrite of thoughts longer than roughly 180 words, which then fall back to the heuristic.
  - **Verification**:
    - **Unit Tests**:
      - File: `test/features/ai_processing/llm_config_test.dart`
      - Cases:
        1. New fields have documented defaults, participate in equality/`copyWith`, and reject invalid values.
    - **Widget Tests**:
      - N/A — Inference configuration.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test integration_test/llm_latency_benchmark_test.dart -d 38031JEHN08164` (on-device; prints load and per-turn timings for each variant).
      - Acceptance: record the measured table in this task and in `IMPLEMENTATION.md`; the chosen default must not exceed the 25s timeout and should approach the 1.8s target as far as the hardware allows, with the residual gap stated.

- [ ] **TASK-063: Native Capture Core — Foreground Service Owns Microphone, WAV Writing & Capture Inbox**
  - **Area**: `android/app/src/main/kotlin/com/eudemonia/eudemonia/` (new capture recorder + inbox), `lib/features/ai_processing/audio_queue_service.dart` (inbox ingestion), `lib/features/capture/`
  - **Spec**: [`PRODUCT_SPEC.md#fr2-non-blocking-audio-capture`](./PRODUCT_SPEC.md#fr2-non-blocking-audio-capture), [`PRODUCT_SPEC.md#fr10-lock-screen--notification-center-capture-trigger`](./PRODUCT_SPEC.md#fr10-lock-screen--notification-center-capture-trigger), and Scenario 2 in [`PRODUCT_SPEC.md#3-target-personas--user-scenarios`](./PRODUCT_SPEC.md#3-target-personas--user-scenarios)
  - **Details**: Implement Phase 1 of `IMPLEMENTATION.md` Section 4.C. Detailed design and task breakdown to be written by the orchestrator before pickup.
  - **Verification**: To be specified with the design.

- [ ] **TASK-064: Run Model Inference in a Dedicated Process Started on Demand**
  - **Area**: To be specified with the design (Phase 2 of `IMPLEMENTATION.md` Section 4.C).
  - **Spec**: [`PRODUCT_SPEC.md#fr6-model-lifecycle--memory-management`](./PRODUCT_SPEC.md#fr6-model-lifecycle--memory-management) and [`PRODUCT_SPEC.md#d-non-functional-requirements-nfr`](./PRODUCT_SPEC.md#d-non-functional-requirements-nfr) (`Memory: Baseline Idle RAM`, `App Crash-Free Rate`)
  - **Details**: Depends on TASK-063 and on the model/runtime settings chosen in TASK-062.
  - **Verification**: To be specified with the design.

---

## Milestone 13: Launch Stability — Model File Integrity, Crash-Loop Protection & 16 KB Page-Size Compatibility (Completed)

- [x] **TASK-060: Model File Validation, Crash-Loop Guard & Verified Model Downloads**
  - **Area**: `lib/features/ai_processing/model_file_validator.dart`, `lib/features/ai_processing/model_load_guard.dart`, `lib/features/ai_processing/model_lifecycle_manager.dart`, `lib/features/ai_processing/audio_queue_service.dart`, `download_models.sh`
  - **Spec**: [`PRODUCT_SPEC.md#d-non-functional-requirements-nfr`](./PRODUCT_SPEC.md#d-non-functional-requirements-nfr) (`Reliability: App Crash-Free Rate`, `Queue Failure Isolation`) and [`PRODUCT_SPEC.md#fr6-model-lifecycle--memory-management`](./PRODUCT_SPEC.md#fr6-model-lifecycle--memory-management)
  - **Details**: Reject malformed model files before they reach the native runtimes, stop the app from re-attempting a model load that killed the previous process, surface the reason on the failed card with Retry as the override, and make the download script pin revisions and verify checksums.
  - **Verification**:
    - **Unit Tests**:
      - File: [`test/features/ai_processing/model_load_safety_test.dart`](file:///Users/harshmavani/Documents/Eudemonia/test/features/ai_processing/model_load_safety_test.dart)
      - Cases:
        1. Accepts a well-formed ONNX file; rejects truncated, spliced, zero-filled, empty, LFS-pointer and HTML files; reports a missing file by name.
        2. Accepts a complete model set; rejects non-GGUF LLM weights and a missing `tokens.txt`.
        3. A corrupt file fails the load without reaching the native runtime.
        4. A successful load leaves no crash marker.
        5. After a process death inside a load, the next launch refuses to load the same files.
        6. Replacing the model files lifts the block automatically.
        7. Queue items fail with a readable reason while blocked, and Retry attempts the load again.
    - **Widget Tests**:
      - N/A — Non-UI component.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/model_load_safety_test.dart`
      - `bash download_models.sh` (verified download and device push)
      - On-device (Pixel 7a): launch, model load, and processing of a queued recording completed without a crash.

- [x] **TASK-061: 16 KB Page-Size Compatible Native Libraries (Isar Community Fork Migration)**
  - **Area**: `pubspec.yaml`, `lib/core/database/app_database.dart`, `lib/features/notes/data/`, `lib/features/synthesis/data/`
  - **Spec**: [`PRODUCT_SPEC.md#d-non-functional-requirements-nfr`](./PRODUCT_SPEC.md#d-non-functional-requirements-nfr) (`Reliability`) and the target platform in the document header (`optimized for modern Android 14/15/16`)
  - **Details**: Replace the abandoned `isar` 3.1.0+1 packages, whose `libisar.so` is 4 KB aligned, with `isar_community` 3.4.1 and regenerate schemas (dependency swap approved by the user's request to fix the warning).
  - **Verification**:
    - **Unit Tests**:
      - Existing repository and persistence suites remain green on the fork.
    - **Widget Tests**:
      - N/A — Dependency migration.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test`
      - `~/flutter/bin/flutter build apk --debug`, then `llvm-readelf -lW` on every `lib/arm64-v8a/*.so`: all 16 libraries report 16 KB or larger `LOAD` alignment; `zipalign -c -P 16 4` passes.
      - On-device (Pixel 7a): existing database opened; no compatibility dialog on launch.

---

## Milestone 6: Four-Stage Screen Navigation & Benchmark (In-Scope Pending)

- [ ] **TASK-029: Four-Stage Persistent Top Navigation Bar & Screen Switcher**
  - **Area**: `lib/features/home/home_screen.dart`, `lib/features/capture/`, `lib/features/synthesis/`, `lib/features/insights/`, `lib/features/action/`
  - **Spec**: [`PRODUCT_SPEC.md#6-user-experience-ux--four-stage-interaction-architecture`](./PRODUCT_SPEC.md#6-user-experience-ux--four-stage-interaction-architecture) (`Section 6: Four-Stage Navigation Shell replacing legacy folder pills`)
  - **Details**: Remove legacy folder pills (`All`, `Work`, `Ideas`, `Todos`, `Journal`) from the top bar. Implement a persistent segmented navigation bar (`Capture`, `Synthesis`, `Insights`, `Action`) that switches views seamlessly.
  - **Verification**:
    - **Unit Tests**:
      - File: `test/features/navigation/stage_navigation_test.dart`
      - Cases:
        1. Default stage is `Capture`.
        2. Switching stages updates active stage provider state synchronously.
    - **Widget Tests**:
      - File: `test/features/home/stage_switcher_ui_test.dart`
      - Cases:
        1. Persistent top bar renders 4 stage tabs: Capture, Synthesis, Insights, Action.
        2. Tapping Synthesis tab switches active view to Synthesis screen.
        3. Tapping Insights tab switches active view to Insights screen.
        4. Tapping Action tab switches active view to Action screen.
        5. Active tab is visually highlighted.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/home/stage_switcher_ui_test.dart`

- [ ] **TASK-030: Automated Capture Latency (<5ms Budget) Benchmark Verification**
  - **Area**: `test/benchmark/capture_latency_benchmark_test.dart`, `lib/features/ai_processing/batch_pipeline_service.dart`
  - **Spec**: [`PRODUCT_SPEC.md#d-non-functional-requirements-nfr`](./PRODUCT_SPEC.md#d-non-functional-requirements-nfr) (`NFR Latency: Audio Capture Dispatch < 5ms from trigger release to queue handoff`)
  - **Details**: Implement automated benchmark test measuring elapsed duration from `stopRecordingAndProcess()` trigger call to queue handoff completion, asserting execution completes in under 5ms.
  - **Verification**:
    - **Unit Tests**:
      - File: `test/benchmark/capture_latency_benchmark_test.dart`
      - Cases:
        1. Measures 100 iterations of `stopRecordingAndProcess()`.
        2. Computes P95 and asserts P95 duration is strictly < 5 milliseconds.
    - **Widget Tests**:
      - N/A — Benchmark execution test.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/benchmark/capture_latency_benchmark_test.dart`

---


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
      - File: `test/features/ai_processing/thermal_gated_queue_test.dart`
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
      - File: `test/features/settings/telemetry_data_source_test.dart`
      - Cases:
        1. Telemetry repository records timestamped memory samples.
        2. Computes 24h battery usage percentage from power manager stats.
    - **Widget Tests**:
      - File: `test/features/settings/telemetry_charts_ui_test.dart`
      - Cases:
        1. Battery sparkline renders within container bounds on 360dp screens.
        2. Memory lifecycle curve displays baseline and peak annotations.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/settings/telemetry_charts_ui_test.dart`

---



## Milestone 10: Action Engine & Insights Dashboards (In-Scope Pending)

- [ ] **TASK-043: Action Item & Commitment Extraction Pipeline**
  - **Area**: `lib/features/ai_processing/action_extractor.dart`, `lib/features/action/action_item_model.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr14-the-action-engine-tasks--calendar-time-blocking`](./PRODUCT_SPEC.md#fr14-the-action-engine-tasks--calendar-time-blocking) (`FR14.1: Extract action items, due dates, urgency`)
  - **Details**: Enhance LLM prompt schema to extract actionable commitments during synthesis, detecting task description, temporal anchors (due date/time e.g. `05/11  02:00 PM`), and urgency level (Normal, High). Store extracted tasks in Isar database linked to origin session.
  - **Verification**:
    - **Unit Tests**:
      - File: `test/features/ai_processing/action_item_extraction_test.dart`
      - Cases:
        1. Parses structured JSON response extracting task description and temporal anchor.
        2. Classifies urgent tasks with High urgency flag.
        3. Returns empty action item list for non-actionable journal thoughts.
    - **Widget Tests**:
      - N/A — LLM parsing logic.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/action_item_extraction_test.dart`

- [ ] **TASK-044: Action Screen UI, Calendar Time-Blocking & Calendar Sync**
  - **Area**: `lib/features/action/presentation/action_screen.dart`, `lib/features/settings/calendar_sync_service.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr14-the-action-engine-tasks--calendar-time-blocking`](./PRODUCT_SPEC.md#fr14-the-action-engine-tasks--calendar-time-blocking) (`FR14.2: Action screen with checkboxes and calendar time-blocks, FR14.3: Calendar sync status and push`)
  - **Details**: Implement Action screen displaying pending commitments with checkboxes, urgency tags, and origin thought links. Include visual calendar time-block timeline and 1-tap `[ 📅 Push to Calendar ]` action. Reflect calendar sync status from Settings.
  - **Verification**:
    - **Unit Tests**:
      - File: `test/features/action/action_repository_test.dart`
      - Cases:
        1. Toggling checkbox updates `isCompleted` in local database.
        2. Generates time blocks from task temporal anchors.
    - **Widget Tests**:
      - File: `test/features/action/action_screen_test.dart`
      - Cases:
        1. Renders pending task cards with date tags and urgency chips.
        2. Tapping checkbox marks task completed with strikethrough styling.
        3. Calendar status card displays connected status and settings shortcut.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/action/action_screen_test.dart`

- [ ] **TASK-045: Journal Emotional Valence & Cognitive Energy Scoring**
  - **Area**: `lib/features/ai_processing/note_classifier.dart`, `lib/features/insights/mind_climate_model.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr15-insights-hub-cognitive-climate--recurrent-patterns`](./PRODUCT_SPEC.md#fr15-insights-hub-cognitive-climate--recurrent-patterns) (`FR15.1: Valence -1.0 to +1.0 and cognitive energy scoring`)
  - **Details**: Evaluate reflective thoughts for psychological valence (-1.0 to +1.0) and cognitive energy (Low/High). Store scoring in note metadata for aggregation in Insights.
  - **Verification**:
    - **Unit Tests**:
      - File: `test/features/ai_processing/valence_scoring_test.dart`
      - Cases:
        1. Extracts valence float between -1.0 and +1.0 from structured output.
        2. Assigns `CognitiveEnergy.high` for creative breakthroughs or energized speech.
        3. Clamps out-of-range valence scores safely to [-1.0, 1.0].
    - **Widget Tests**:
      - N/A — AI classification metadata logic.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/ai_processing/valence_scoring_test.dart`

- [ ] **TASK-046: Insights Hub Visualizers (Valence Heatmap, Topic Density Matrix, Recurrent Pattern Dashboard)**
  - **Area**: `lib/features/insights/presentation/insights_screen.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr15-insights-hub-cognitive-climate--recurrent-patterns`](./PRODUCT_SPEC.md#fr15-insights-hub-cognitive-climate--recurrent-patterns) (`FR15.2: Weekly/monthly emotional transition heatmap, topic density, recurrent patterns`)
  - **Details**: Build Insights screen with sub-view switcher across (1) Weekly/Monthly emotional valence heatmap with 2-minute Coherence Breathing button, (2) Topic cognitive load treemap, and (3) Recurrent pattern and habit loop detector.
  - **Verification**:
    - **Unit Tests**:
      - File: `test/features/insights/insights_calculator_test.dart`
      - Cases:
        1. Aggregates daily thought valence into average daily score.
        2. Detects recurrent keywords across disjoint sessions over time.
    - **Widget Tests**:
      - File: `test/features/insights/insights_screen_test.dart`
      - Cases:
        1. Renders 7-day calendar row with color-coded valence chips.
        2. Sub-view switcher toggles between Emotion Map, Topic Density, and Recurrent Loops.
        3. Tapping Coherence Breath button triggers breathing session callback.
    - **Integration / Command Tests**:
      - `~/flutter/bin/flutter test test/features/insights/insights_screen_test.dart`

---

