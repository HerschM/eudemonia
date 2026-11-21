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
- **DECISION 2026-11-21 (user)**: the LLM is removed from the capture path. Capture shows the speech transcript exactly as spoken (fillers such as "um"/"uh" and misspoken words KEPT; no rule-based stripping either) as a fact check; all cleanup, condensing and filing happens in Synthesis. Silent omission of non-English speech is accepted for v1. A vocabulary setting is wanted if a biasing mechanism proves to work. `PRODUCT_SPEC.md` FR5.2 amended; rationale in `IMPLEMENTATION.md` chronicle #32.
- **Order of work now**: (1) TASK-067 capture without LLM (code delegated 2026-11-21; see its status below) → (2) **Synthesis is the priority** (Milestone 9: TASK-048..051, starting with a design review of `IMPLEMENTATION.md` Section 4.B by the orchestrator, including how the LLM handles long input) → (3) TASK-068 on-device STT accuracy options → later TASK-063 native capture core, TASK-064 inference process, TASK-065 device-tier models.
- **TASK-062 is closed by re-scope**, not by meeting its number: its fixes (timeout stop, greedy sampling, `modelLoadTimeout`, metrics, prompt lessons) carry to the Synthesis turn; KV-prefix caching for capture is dropped.
- **Verified on device (Pixel 7a, Android 17, 4 KB pages, serial `38031JEHN08164`)**: launch without crash, Isar opens the existing database, STT worker isolate loads and transcribes, Capture screen and floating capsule work, no 16 KB dialog, voice evaluation harness runs end to end.
- **Still unverified on device**: TASK-067 build on the phone (STT-only timings and memory); cross-process `RECORDING_STATE_CHANGED` haptic sync; first-launch permission prompt → foreground service start on a fresh install; `SystemTelemetryCollector` readings; crash-loop guard against a real native abort.
- **Phone state (2026-11-20 ~20:40)**: normal debug build WITH TASK-067 (no LLM at capture) installed 2026-11-21; models, synthetic samples and the user's 22 real clips are on the device; the user's 22 recordings are still in the app. After `flutter drive`, always `flutter build apk --debug` before `adb install -r`.
- **Evaluation assets**: harness and samples described under TASK-066; the user's recordings and their results are git-ignored in `integration_test/voice_samples/real/`; Whisper large-v3 reference on the Mac: `whisper-cli -m ~/ggml-large-v3.bin -f <wav> -nt -np`.
- **Open questions to the user**: none.
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

- [x] **TASK-062 (CLOSED BY RE-SCOPE 2026-11-21: LLM removed from capture, 1.8s target not met and no longer applicable; see Active Work Handoff): Bring On-Device LLM Turn Latency Within Budget (Measured, CPU vs GPU Offload, Sampling & Prompt Size)**
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
    - KV-prefix research (2026-11-20, read-only study of llama_cpp_dart 0.2.2, not yet verified on device):
      - A `LlamaScope` is a full separate llama context (`createSlot` → `llama_new_context_with_model`), not a sequence id. `disposeScope` frees that whole context. The model load also creates a "default" context, so today every turn allocates a second full context (its own KV cache sized for `nCtx`) and frees it afterwards. Suspected to be part of the ~8.7s time-to-first-token; to be measured.
      - A second `sendPrompt` on the same scope appends after the old tokens (previous answer included, plus another BOS). There is no prefix matching and no rollback, so naive scope reuse would contaminate turns.
      - Public API reachable from `LlamaParent`: `saveState(scope)`, `loadState(scope, bytes)`, `loadSession`. No `seq_rm` wrapper, no `nKeep`, no way to reset the position counter; `LlamaClear` exists in the child but the parent never sends it. Raw FFI bindings for `llama_memory_seq_rm` exist.
      - Candidate mechanisms, cheapest first: (1) evaluate the prefix once, `saveState`, then `loadState` before each turn (unverified whether `loadState` restores the slot position; user part would still get a BOS); (2) own isolate around the low-level `Llama` class with `llama_memory_seq_rm` rollback (needs a patch or raw-binding decode loop because the position counter is private). Decide by measuring (1) on device with the evaluation harness (TASK-066).
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

- [/] **TASK-066: On-Device Voice Evaluation Harness — Real & Synthetic Speech Samples, STT Accuracy, Cleanup Quality, Timing & Memory**
  - **Area**: `integration_test/voice_samples/` (`manifest.json`, `RECORDING_SCRIPT.md`, `synthetic/`, git-ignored `real/`), `integration_test/support/text_eval.dart`, `integration_test/voice_pipeline_eval_test.dart`, `tool/generate_synthetic_voice_samples.sh`, `tool/push_voice_samples.sh`, `test/eval/text_eval_test.dart`
  - **Spec**: [`PRODUCT_SPEC.md#10-success-metrics--quality-gates`](./PRODUCT_SPEC.md#10-success-metrics--quality-gates) (`Queue Processing Success Rate`, `Classification Precision`), [`PRODUCT_SPEC.md#fr4-on-device-speech-recognition-stt`](./PRODUCT_SPEC.md#fr4-on-device-speech-recognition-stt), [`PRODUCT_SPEC.md#fr5-on-device-llm-pipeline-two-tier-post-processing`](./PRODUCT_SPEC.md#fr5-on-device-llm-pipeline-two-tier-post-processing), and [`PRODUCT_SPEC.md#d-non-functional-requirements-nfr`](./PRODUCT_SPEC.md#d-non-functional-requirements-nfr)
  - **Why**: Until now no automated test exercised real speech. Host tests use a fake STT; real recognition ran on the phone once, on one short clip; the LLM benchmark used a typed transcript.
  - **Design (decided by the orchestrator)**:
    1. **Samples**: 16 kHz mono 16-bit WAV. `real/NN.wav` are the user's recordings of `RECORDING_SCRIPT.md` items 1–22 pulled from the phone (personal data, git-ignored). `synthetic/sNN.wav` are generated from the same scripted texts with macOS `say --data-format=LEI16@16000` (committed; deterministic regression set).
    2. **`manifest.json`**: array of `{ "id", "file", "reference" (exact expected words, or null for free-form), "expectSpeech" (false only for the silence item), "tags" (e.g. `short`, `medium`, `long`, `fillers`, `numbers`, `noise`, `whisper`, `fast`, `pause`, `pocket`, `far`), "mustKeep" (array of arrays of acceptable spellings for facts that must survive, e.g. `[["nine thirty","9:30"],["dentist"]]`), "expectedFolder" (or null) }`. One entry per real item and per synthetic item.
    3. **Delivery to the device**: samples are NOT bundled as app assets (the user's voice must never enter an APK or the repo). `tool/push_voice_samples.sh` pushes `manifest.json` and both sample folders to `/sdcard/Android/data/com.eudemonia.eudemonia/files/voice_samples/`; the harness reads them from `getExternalStorageDirectory()`.
    4. **`text_eval.dart` (pure Dart, host-tested)**: `normalizeForComparison` (lowercase, strip punctuation, collapse whitespace), `wordErrorRate(reference, hypothesis)` (word-level Levenshtein / reference length), `contentRecall(source, cleaned)` (share of the source's non-filler words still present in the cleaned text), `countFillers(text)` over a fixed list (`um`, `uh`, `er`, `ah`, `like` only as a filler is not detectable — count `um|uh|er|ah|umm|uhh|you know|basically|so yeah`), `missingFacts(text, mustKeep)`.
    5. **`voice_pipeline_eval_test.dart`** (run only via `flutter drive --keep-app-running`): uses the REAL `STTService`, `LLMService` and `ModelFileValidator` with the shipped `LLMConfig` defaults. Per sample: time STT, compute WER against `reference`; if speech is expected, run `processText` on the STT output and record `LlmTurnMetrics`, fallback flag, folder, `contentRecall(sttText, correctedText)`, remaining fillers, missing facts. For `expectSpeech: false` assert the transcript is empty. Memory (`SystemTelemetryService().read()` → app PSS) is sampled at start, after STT load, after LLM load, as a running maximum across turns, and 5s after both services are disposed. Results are printed as `EVAL|<json>` lines (one per sample plus one `EVAL_SUMMARY|<json>`) and also written to `<external files dir>/voice_eval_results.json` for retrieval with `adb pull`. A sample failing its expectations is recorded, not thrown, so one bad clip never hides the rest; the test fails only if the harness itself could not run.
  - **Progress Log**:
    - 2026-11-20: Host-side parts implemented by a Sonnet subagent and reviewed by the orchestrator (uncommitted): `manifest.json` (41 entries: real `r01`–`r22`, synthetic `s01`–`s09`, `s11`, `s12`, `s14`–`s21`), 19 synthetic WAVs generated and format-verified (0.7s to 75.9s; `s19` has the 5s pause, `s20` is digital silence), both `tool/` scripts, `text_eval.dart` with 18 passing host tests, and `voice_pipeline_eval_test.dart`. `dart analyze` clean.
    - NOT yet done: the harness has never been executed on a device; `tool/push_voice_samples.sh` has never been run; no real recordings pulled yet. Real recordings live in the app's private directory (`/data/user/0/com.eudemonia.eudemonia/app_flutter/recording_*.wav`); pull them in capture order with `adb exec-out run-as com.eudemonia.eudemonia cat <path>` into `integration_test/voice_samples/real/NN.wav` (debug builds allow `run-as`), mapping by order to script items and honoring any skips/redos the user reports.
    - 2026-11-20 device incident and fixes (uncommitted): (1) After the user reinstalled the app it reported `encoder.int8.onnx is missing` although the files were present: folders created by `adb` under `/sdcard/Android/data/<pkg>/files` are owned by the shell user with mode `drwxrws---`, and the reinstalled app (new UID) could not enter `parakeet/` (`File.exists()` returns false on a permission error, so the validator reported "missing"). Fixed by `adb shell chmod -R a+rwX` in `download_models.sh` and `tool/push_voice_samples.sh`; confirmed by the harness loading STT. Not explained: the same ownership worked on 2026-11-18. Fallback if it recurs: keep models in app-private storage. `run-as` cannot read that path at all, so it is not a valid probe of the app's access. (2) llama_cpp_dart hard-codes a 60s limit on model loading; the first load after an install exceeded it (`Operation "model loading" timed out`) while the load was still running. `LLMService.initialize()` now keeps polling `LlamaParent.status` up to `LLMConfig.modelLoadTimeout` (180s) and disposes the parent on real failure.
    - **First harness run, synthetic set, Pixel 7a** (raw results committed as `integration_test/voice_samples/results_synthetic_2026-11-20_run1.json`; 19 clips, 6m16s):
      - STT: mean WER 7.1%; errors are on names and numbers with the synthetic voice (`3 EM` for 3 PM, `$2,000` for forty two thousand, `Kartlan` for Kotlin, `Sunna` for Sana). Silence clip correctly returned no speech. STT time is erratic: 0.7s to 15s for clips under 10s — unexplained, suspected contention with the GPU-offloaded LLM; to investigate.
      - LLM: 0 fillers left in any clip; 18/19 real results, 1 fallback (`s12`, 76s / 249 words, hit the 256-token output limit as predicted, 45.7s). Short thoughts take 8.5–9.5s (time to first token ~4.9s), a 40s clip 25.9s.
      - **Fidelity defect (must fix, user requires no loss)**: the cleanup rewrites instead of only cleaning. It drops openers (`Remind me to`, `I need to`, `quick thought while I'm walking`), turns sentences telegraphic (`Onboarding screen feels too long, should cut it down to three steps... back hurts`), and removes the spoken self-correction in `s08`. `content_recall` ranged 0.56–1.0 (target ≥ 0.97). Likely cause: the imperative example in the prompt (`Call the dentist tomorrow morning.`). Fix in prompt iteration with examples that preserve first-person phrasing.
      - Folder: 6 of 7 expected folders matched (`s06` technical note filed as Ideas, expected Work).
      - **Memory (app PSS, debug build, test harness process)**: 351 MB at start, 1053 MB after STT load, 2480 MB after LLM load, **4162 MB peak during turns**, 533 MB five seconds after dispose. These are far above the documented ~1.6 GB / <60 MB figures. Unknowns to resolve before quoting them as product numbers: how much is debug-build overhead, how much is GPU memory counted in PSS, and how much is the second llama context created per turn (see KV research under TASK-062).
    - **Second harness run, all 41 clips incl. the user's 22 real recordings, Pixel 7a, 2026-11-20** (20m19s; raw results kept out of git because they contain personal speech: `integration_test/voice_samples/real/results_real_2026-11-20_run2.json`). Real-voice findings:
      - **STT accuracy** is good on clear speech: scripted quiet clips 0–4% WER, names right (`Priya`, `Anjali`, `Rahul`, `Sana`), fillers transcribed. Misses: `r05` "Buy milk" (2s clip) → `Baink.`; `r06` → `river port provider`, `Cotelin foreign service` (user reports an earlier take got these right, so recognition of these terms is unstable, not impossible); `r12` "fifteen or twenty seconds" → `15 or 2 seconds`, "um and uh" → `um and a`; `r15` pocket: the whole first sentence ("Testing capture from my pocket") is absent and "afternoon" → `after`; `r17` whisper: "I want to" → `I wonder`; `r21` far: `shape folder and the planning`; `r13` free-form: `clod` (Claude), `E6 shoes`. `r20` silence → empty (correct). `r22` English+Hindi: only the English sentence is output; Hindi is dropped silently. Unknown whether `r05`/`r15` losses are in the audio (capture start/stop clipping, see chronicle #15) or in recognition: inspect the WAVs.
      - **STT speed is a defect**: about real time or slower once the LLM is loaded (`r13` 128s audio → 169s; `r12` 91s → 95s; `r10` 32s → 38.5s; `r07` 19s → 23s), while the first two clips of the run took 0.7s and 1.4s. Same pattern on synthetic clips. Hypotheses to test in order: memory pressure evicting the mmapped models (peak PSS 5.0 GB on an 8 GB phone), CPU contention with llama threads, thermal throttling. Measure STT alone (no LLM loaded) vs with LLM loaded and idle.
      - **Cleanup fidelity defect confirmed on real speech** (`content_recall` min 0.51): drops openers (`r01`, `r15`, `r16`, `r18`), goes telegraphic (`r09`, `r18`), drops whole clauses (`r14` "quick thought while I'm walking", `r17` "so I'm speaking quietly", `r21` first sentence), strips list framing (`r07`), and in `r08` resolves the self-correction while inventing `AM` and a false causal link ("Rahul is out on Tuesday, so send the invite..."). In `r12` it deleted the quoted word `um` from "every um and uh". Clips 10, 11, 19, 04, 03 came back essentially verbatim and correct, so the model can do it; the prompt is steering it wrong.
      - **Long thoughts fail**: `r12` (253 words) hit the 256-token limit after 33.5s → fallback; `r13` (~290 words) failed in 0.6s with zero tokens → fallback (prompt + transcript presumably exceed the context window; confirm `nCtx` and the error). Fallback output keeps fillers (4 remaining).
      - **Folder**: 4 of 7 expected matched; the model over-uses `Ideas` (`r06` technical → Ideas, `r07` weekend chores → Ideas, and most unlabelled clips). Low priority because TASK-049 removes capture-time folders.
      - **Timing**: LLM 6.8–9.5s for short thoughts (TTFT ~4.8s), 14s for 19s clip, 25.8s for 50s clip.
      - **Memory (PSS, debug build)**: 343 MB start, 1061 MB after STT, 2613 MB after LLM load, **5017 MB peak**, 686 MB after dispose. Peak grew with clip length versus run 1 (4162 MB).
      - Synthetic clips: same picture as run 1 (1 fallback on `s12`, recall 0.56–1.0).
    - **Step 2 work list derived from run 2 (order)**: (1) memory + STT-speed investigation (they are probably the same problem; includes release-build numbers and the per-turn extra llama context); (2) cleanup prompt fidelity, verified on both sets, target `contentRecall` ≥ 0.97 and no invented words; (3) long thoughts: context size check, output budget scaled to input, chunking at sentence boundaries beyond that; (4) inspect `r05`/`r15` audio for clipped starts; (5) KV prefix caching + FR5.6 amendment; (6) STT vocabulary: evaluate sherpa-onnx hotword/contextual biasing for user terms (needs `modified_beam_search`; check support for this TDT model) or a user-term correction list in the cleanup prompt; (7) decide product behaviour for non-English speech (currently dropped silently).
    - **Reference check with Whisper large-v3 on the Mac, 2026-11-21** (`whisper-cli -m ~/ggml-large-v3.bin -f <clip> -nt -np`; whisper.cpp via Homebrew, model at `~/ggml-large-v3.bin`): on the same WAV files Whisper transcribed every clip Parakeet got wrong correctly: `r05` "Buy milk.", `r06` "riverpod provider ... kotlin foreground service", `r12` "15 or 20 seconds", `r15` both sentences incl. "Friday afternoon" (one slip: "captured"), `r17` "I want to write down", `r21` "shared folder under planning". **Conclusion: the audio is fine (no clipped starts); these are recognition-model errors of Parakeet int8.** Whisper's own faults: on `r13` (128s free speech) it silently skipped two passages and lost punctuation; on `r22` it translated/invented the Hindi part. Work item added: evaluate better on-device STT options (Parakeet non-int8 encoder, Whisper turbo/small via sherpa-onnx, hotwords) against this set.
    - **Design question raised by the user 2026-11-21 (DECIDED same day: LLM removed from capture, fillers kept; see Active Work Handoff and TASK-067)**: user reaffirmed FR5.2 strictly — Capture shows everything that was spoken (including misspoken words) as a fact check; compression belongs to Synthesis — and asked whether the LLM should run at Capture at all. Orchestrator recommendation: remove the LLM from the capture path (STT output + deterministic um/uh removal only; Parakeet already punctuates and capitalises), run the LLM only in Synthesis. Consequences if approved: per-thought latency ≈ STT time, no simultaneous STT+LLM memory, long-thought fallback problem disappears from Capture, TASK-062 is closed by re-scoping (prompt/latency learnings move to the Synthesis turn, KV-prefix caching dropped), FR5.2/FR5.6 wording amended, capture-time folder removed (aligns with TASK-049). Memory/STT-speed investigation is on hold until the decision.
    - Harness procedure note: after `flutter drive`, run `~/flutter/bin/flutter build apk --debug` before `adb install -r`, otherwise the test build is what gets reinstalled.
    - Interpretation notes for the report: scripted references contain the spoken fillers and number words, while STT may omit fillers and emit digits, so raw WER overstates errors on items 2, 3, 7, 9, 12, 14; judge those by `mustKeep` facts and by a filler-stripped comparison computed from `stt_text` in `voice_eval_results.json`. Synthetic entries carry a `synthetic` tag and no condition tags. Item `r12` (2 minutes) is expected to expose the 256-token output limit until that part of TASK-062 is fixed.
  - **Pass criteria used when reporting to the user** (targets, not yet met or measured): STT WER ≤ 10% on quiet-room clips (reported separately for noise/whisper/far/fast); 0 LLM fallbacks; `contentRecall` ≥ 0.97; 0 missing facts; 0 remaining fillers; long clips (items 11–13) fully processed; folder matches where `expectedFolder` is set.
  - **Verification**:
    - **Unit Tests**:
      - File: `test/eval/text_eval_test.dart`
      - Cases:
        1. `wordErrorRate` is 0 for identical text ignoring case and punctuation, and counts substitutions, insertions and deletions.
        2. `contentRecall` ignores filler words and drops when a sentence is removed.
        3. `countFillers` and `missingFacts` (any acceptable spelling satisfies a fact).
    - **Widget Tests**:
      - N/A — Evaluation tooling.
    - **Integration / Command Tests**:
      - `bash tool/generate_synthetic_voice_samples.sh` then `bash tool/push_voice_samples.sh`
      - `~/flutter/bin/flutter drive --driver=test_driver/integration_test.dart --target=integration_test/voice_pipeline_eval_test.dart -d 38031JEHN08164 --keep-app-running`, then `adb install -r build/app/outputs/flutter-apk/app-debug.apk`.

- [/] **TASK-067: Capture Without LLM — Save the Speech Transcript As Spoken, Speech-Model-Only Lifecycle**
  - **Area**: `lib/features/ai_processing/audio_queue_service.dart`, `lib/features/ai_processing/model_lifecycle_manager.dart`, `lib/features/ai_processing/model_file_validator.dart`
  - **Spec**: [`PRODUCT_SPEC.md#fr5-on-device-llm-pipeline-two-tier-post-processing`](./PRODUCT_SPEC.md#fr5-on-device-llm-pipeline-two-tier-post-processing) (FR5.2)
  - **Details**: `AudioQueueService` drops its `LLMService` dependency and the categorizing step; notes are saved with `correctedText == rawText` (trimmed) and the default folder. `ModelLifecycleManager` loads, validates, guards and evicts the speech model only, so a missing GGUF cannot block capture. `LLMService`, `NoteClassifier`, `LLMConfig` remain for Synthesis. `AudioQueueStatus.categorizing` kept as a legacy stored value.
  - **Progress Log**: 2026-11-21: implemented by `eudemonia-implementer`, diff reviewed by the orchestrator. Gate: `dart analyze` 0 issues, `flutter test test/` 231 passed, `:app:testDebugUnitTest` passed, debug APK built and installed on the Pixel 7a (`adb install -r`, data kept). NOT yet verified on device: a real capture with the new build, STT-only timing and memory. `integration_test/voice_pipeline_eval_test.dart` still exercises the LLM directly and should get an STT-only mode when next used.
  - **Verification**:
    - **Unit Tests**: `test/features/ai_processing/` — saved note equals transcript with fillers preserved and folder `Uncategorized`; queue never reports `categorizing`; lifecycle loads/evicts only STT and succeeds with no LLM file.
    - **Widget Tests**: N/A.
    - **Integration / Command Tests**: full gate; on device: record a thought, card shows transcript; measure STT time and app PSS with STT only.

- [ ] **TASK-068: On-Device Speech Recognition Accuracy — Evaluate Model Options & Vocabulary Biasing Against the Real-Voice Set**
  - **Area**: `lib/features/ai_processing/stt_engine.dart`, `download_models.sh`, evaluation harness; Settings vocabulary option only if biasing works.
  - **Spec**: [`PRODUCT_SPEC.md#fr4-on-device-speech-recognition-stt`](./PRODUCT_SPEC.md#fr4-on-device-speech-recognition-stt)
  - **Details**: Whisper large-v3 (Mac) transcribed all clips Parakeet int8 missed (`r05`, `r06`, `r12`, `r15`, `r17`, `r21`), so the audio is adequate. Compare on the 22 real clips: Parakeet with non-quantized encoder, a phone-sized Whisper (turbo/small via sherpa-onnx), and sherpa-onnx hotword biasing for user terms (check support for the TDT model). Record WER, speed and memory per option. Also re-measure STT speed with no LLM loaded (it was ~1s for short clips before the LLM loaded, ~real time after). Changing the model needs user approval.
  - **Verification**: To be specified with the design.

- [ ] **TASK-065: Device-Tier Model Recommendation (Low / Mid / High Tier Models Validated for Output Quality & Resource Use) — Future**
  - **Area**: To be designed.
  - **Spec**: [`PRODUCT_SPEC.md#a-deferred-features--roadmap-v15--v20`](./PRODUCT_SPEC.md#a-deferred-features--roadmap-v15--v20) (`Device-Tier Model Recommendation`), requested by the user on 2026-11-20.
  - **Details**: Trial two or three model options per tier with the TASK-066 harness (quality, latency, memory, thermal), then recommend a model from the device's RAM and chipset. Not started; smaller-model trials are explicitly deferred until TASK-062 is closed.
  - **Verification**: To be specified with the design.

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

