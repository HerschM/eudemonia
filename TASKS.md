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
- **Synthesis design APPROVED by the user 2026-11-21** after two rounds; full text in `IMPLEMENTATION.md` Section 4.B (APPROVED REVISION block), spec amended (FR5.5 no fallback, FR11.11 session definition / context-aware folders / size-based rewrite rule, roadmap note on several subjects per folder). Rejected and not to be revived: per-thought labelling in isolation, code-only grouping, keyword or any other fallback, staged condensing with stored per-thought text, the `<300 input tokens` delta figure (never a user requirement). **Next**: TASK-069 capture cleanup (removal list sent to the user for confirmation before deleting), then TASK-070 measurement and prompt work (phone run needs the user's go-ahead: ~20 min, data kept), then TASK-049. User confirmed the recording-start warmup made the first thought faster (TASK-067 device check done except a memory figure).
- **Still unverified on device**: TASK-067 cold first thought after the warmup fix, and speech-model-only memory (user confirmed 2026-11-21 that warm thoughts are fast); cross-process `RECORDING_STATE_CHANGED` haptic sync; first-launch permission prompt → foreground service start on a fresh install; `SystemTelemetryCollector` readings; crash-loop guard against a real native abort.
- **Phone state (2026-11-23 ~00:20)**: debug build of the uncommitted final tree installed (`adb install -r`, new engine); data intact; 9 sessions written by Qwen3-4B with the new prompt and the new engine, pipeline "In Sync"; exports of every stage in the git-ignored `integration_test/voice_samples/real/`. Model files in the app's folder: `qwen2.5-1.5b.gguf` (unused by the current profile) and `qwen3-4b.gguf` (≈ 2.3 GB free). `/data/local/tmp` is clean. `svc power stayon` is `false`. **The app's Accessibility service is still switched off** (banner on the Capture screen, caused by earlier `am force-stop` tests) — the user must tap Enable once; never use `force-stop`. One silent test recording was made and deleted during the preemption test.
- **Evaluation assets**: harness and samples described under TASK-066; the user's recordings and their results are git-ignored in `integration_test/voice_samples/real/`; Whisper large-v3 reference on the Mac: `whisper-cli -m ~/ggml-large-v3.bin -f <wav> -nt -np`.
- **User decisions and open questions (2026-11-22 evening)**: DECIDED — the phone moves to **Qwen3-4B** and the user wants synthesis re-run to compare quality; TASK-073 may come first, but the user asked for a plainer explanation before approving it (given in the evening report; **approval still pending**, as is the wording change of `AGENTS.md` 4.C). The model the user ran in PocketPal is `Qwen3.5-4B-Q4_K_M` (architecture `qwen35`, not loadable by the pinned llama.cpp — see TASK-073 library findings). New requests recorded: TASK-065 (catalogue benchmark incl. SmolLM3 3B, SmolLM2-1.7B-Instruct) and TASK-074 (first-launch model chooser). The user raised the session to effort xhigh with ultracode on, for deep analysis and briefing other models only — not for routing; orchestrator's recommendation sent: ultracode off by default (ask for it per task), high effort for design and diagnosis, medium for execution stretches. STILL OPEN: (1) approve TASK-073 and its foundation (keep the package / its 0.9.0-dev line / own binding); (2) an unplugged screen-off test of the wake lock by the user; (3) the memory NFR (< 1.6 GB peak) no longer matches a 3B/4B model and must be restated with the user (TASK-071 target). Answered earlier 2026-11-22: a late-processed thought joins the session of its capture time (yes); appending to an oversized session is fine for now, revisit with a better model.
- **NOW (2026-11-23 ~00:20)**: last commit `c4f076b`. **Uncommitted, gated on the final tree** (analyze 0 issues; `flutter test test/` 400 passed + 6 skipped host cases; host test of the real library 6 passed; `:app:testDebugUnitTest` exit 0; debug APK built and installed): (1) structured-prompt rework and missing-thought check (TASK-071 log); (2) **TASK-073 complete and verified on the phone** (own binding to llama.cpp `af6b5243`, chunked prefix-reusing loop, organise grammar, thread policy, direct-I/O load; Progress Log has every measurement; `IMPLEMENTATION.md` 1.E.2 rewritten, 4.D kept as rationale, Chronicle #37 closed); (3) spec: FR11.14 additions, memory figure ≤ 3.7 GB; TASK-075 added; `.gitignore` entry for agent worktrees; the implementer's worktree was merged and removed. **Next**: the user's commit; then TASK-072 (thermal guard — now the main lever on run time, see its added note), the asterisk decision for titles, TASK-065 / TASK-074 later. **Open questions to the user**: asterisks around titles (render bold or drop them); the unplugged screen-off test; whether notes as long as the spoken text are acceptable or a later, better model should condense again.
- **Device rule**: never run `flutter test integration_test/... -d <device>` (it uninstalls the app and wipes its data and models); use `flutter drive ... --keep-app-running` as documented in `test_driver/integration_test.dart`.
- **Known open product gaps (not started)**: `isReprocessing` (yellow) is never cleared; placeholders remain in Settings/HUD (`Google Calendar`, `Next refresh in 14h`, unsaved synthesis thresholds, no-op `Keep Raw Audio`, in-memory folder manifestos); capture-time folder inference deviates from FR5.2 until TASK-049.

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

- [x] **TASK-069: Capture Cleanup — Remove Folder, Classifier & Fallback Leftovers of the Old Capture Flow**
  - **Area**: `lib/features/notes/data/note_model.dart`, `lib/features/notes/data/notes_repository.dart`, `lib/features/ai_processing/{audio_queue_item,audio_queue_service,note_classifier,llm_service}.dart`, `lib/features/synthesis/{domain,data}/`, `integration_test/voice_pipeline_eval_test.dart`
  - **Spec**: `PRODUCT_SPEC.md` FR5.2 (capture is audio + transcript only), FR5.5 (no fallback)
  - **Details** (audit done 2026-11-21; list awaiting the user's confirmation): remove `Note.folder` (+ index, repository reassign/filter/list/search-by-folder), `AudioQueueItem.folder`, `AudioQueueStatus.categorizing` (stored queues holding it must still load), `NoteClassifier` entirely (cleanup prompt, JSON parser, `fallbackClassify`) and the classify path in `LLMService` (load/dispose stay for TASK-049), per-origin `folder` on `SynthesisOriginNote`/record. Keep `Note.correctedText` (displayed, user-editable text). Interim until TASK-049: the placeholder `synthesizeRawNotes()` groups by time only. Give the evaluation harness a speech-only mode. Schema change: Ask-First item, approved in principle by the user 2026-11-21.
  - **Progress Log**: 2026-11-21 DONE. Implemented by `eudemonia-implementer`, diff reviewed by the orchestrator, removal list confirmed by the user beforehand (user also said: no backward-compatibility code while in development). Also done in the same change: `session_clock.dart` (45 min idle / 2 h cap, pure, unit tested) now drives the placeholder `synthesizeRawNotes()`; `deleteCluster()` returns thoughts to `processed`; one-time orphan repair removed; `integration_test/llm_latency_benchmark_test.dart` deleted (it only exercised the removed classify call; TASK-070 replaces it); `voice_pipeline_eval_test.dart` is speech-only. `LLMService` now only loads and disposes the model; `LLMConfig` still carries turn fields (`clearKvCacheEveryXTurns`, `kvCacheTtl`, `inputTokenLimit`) to be settled in TASK-049b. Gate (orchestrator run): `dart analyze` 0 issues, `flutter test test/` 221 passed, `:app:testDebugUnitTest` exit 0, APK built, installed with `adb install -r`, app launches on the Pixel 7a with the changed database layout. OPEN (user question 2026-11-21): the user states no session should exist unless organise + write have run; the placeholder `synthesizeRawNotes()` still creates sessions without an LLM — asked whether to disable it now or leave it until TASK-049b replaces it.
  - **Verification**: existing suites green with folder/classifier assertions removed or rewritten; new cases: a stored queue item with status `categorizing` hydrates as pending transcription; a saved thought has no folder property; `dart analyze` 0 issues; full gate.

- [x] **TASK-070: Synthesis Measurement & Prompt Design — Context Size, Speed, Memory and Output Quality on Real Transcripts**
  - **Area**: `integration_test/`, `tool/`, prompt drafts (location decided in the task)
  - **Details**: (1) On the Mac with the same GGUF (`llama-cli`), draft and iterate the organise prompt (folders for a batch of thoughts in context, constrained output) and the write prompt (from raw thoughts; and note + new thoughts) on the user's 22 transcripts; check for invention, lost facts, over-weighting of the newest thought. (2) On the Pixel 7a (user go-ahead needed, `flutter drive --keep-app-running`, rebuild + reinstall after): load time, memory, reading and writing speed at context 2048 / 4096 / 8192 (and larger if affordable); quality against input length. Output: recommended context size, output budget rule, the size threshold for the rewrite rule, a Synthesis latency budget for the NFR table, confirmation that grammar-constrained output works in `llama_cpp_dart` 0.2.2.
  - **Progress Log**:
    - 2026-11-21 Mac prompt work (same GGUF, `llama-server`, temperature 0, grammar-constrained organise output). Scripts kept in `tool/synthesis_prompt_lab/` (`syn.py` = prompts + scoring, `compare.sh <name> <gguf>` = rerun on another model); input transcripts are the user's and stay git-ignored at `integration_test/voice_samples/real/thoughts_run2.json`. Comparison models downloaded to git-ignored `models/eval/` (`qwen3-1.7b`, `qwen3-4b`, `llama32-3b`, all Q4_K_M).
    - **Write turn (from raw thoughts), Qwen2.5-1.5B**: faithful, fillers removed, self-correction resolved (`r08` → "Wednesday at 11", no invented "AM" once the prompt said "add nothing"), long clips `r12`/`r13` intact, no preamble after adding "Output only the note. Begin with its first sentence". It is a light clean-up, not a compression; stronger condensing is a style choice (FR5.3), not the default.
    - **Update turn (existing note + new thoughts)**: Qwen2.5-1.5B lost facts in both test cases (dropped the name "Anjali", dropped "get candles", dropped "cut it down to three steps"); Qwen3-4B also dropped the name; Qwen3-1.7B appended the correction without applying it; only Llama-3.2-3B got both right. Confirms rewrite-from-raw as the default and makes the update path a last resort.
    - **Organise turn** — score = thoughts given an acceptable folder out of 21 (acceptable sets judged by the orchestrator; small sample, differences of 1–2 are not significant) and 12 constructed context cases (abrupt follow-ups, an open session):

      | Model | Old folders: 3 at a time / 5 / all 21 / context | Subject folders: 3 / 5 / all 21 / context |
      |---|---|---|
      | Qwen2.5-1.5B (current) | 17 / 15 / 13 / 10 | 18 / 17 / 17 / 12 |
      | Qwen3-1.7B | 14 / 17 / 14 / 9 | 15 / 15 / 17 / 12 |
      | Llama-3.2-3B | 21 / 17 / 18 / 11 | 20 / 15 / 14 / 12 |
      | Qwen3-4B | 20 / 20 / 19 / 10 | 20 / 19 / 17 / 12 |

      Findings: (1) the old folder list mixes subjects (`Work`, `Journal`) with kinds of thought (`Todos`, `Ideas`); a subject-only test set (`Work`, `Personal`, `Journal`, `Uncategorized`, each with a one-line description and the rule "choose by what it is about, not whether it is a task or an idea") lifts the current model to 17–18/21 and 12/12 on context. User agreed 2026-11-21 the folders overlap and allowed changing them; wants a structure (tags or similar) so user-created folders cannot reintroduce the overlap — open design point for TASK-048. (2) Small batches beat one big batch for the small models; with the old list the 1.5B collapses to one folder at 21 thoughts. (3) "Say the subject first, then the folder" made the 1.5B worse. (4) A 4B model gains about two thoughts in 21 at 2.3x the file size and ~2.4x the time on the Mac; not enough evidence to change the phone model now (user has allowed a phone model test if wanted). Qwen3 needs its thinking disabled and emits a stray `</think>`.
    - **Grammar is not available per turn**: `llama_cpp_dart` 0.2.2 builds the sampler (including any grammar) once at model load, so the organise turn cannot have its own grammar while the write turn shares the model. Checked on the Mac without grammar: identical scores, 1 malformed reply in 17 turns (a line missing). Decision: no grammar; the reply is validated in Dart (`parseOrganiseReply`: exact line count, numbering and folder names). Because sampling is greedy, re-sending the same prompt returns the same reply, so the retry after an invalid reply must change the input (split the batch in half), not repeat it.
    - **User, 2026-11-21**: folders may be changed as suited (agrees the old list overlaps); wants a structure such as tags so user-created folders cannot reintroduce overlap; phone model may be changed for testing if useful. Working test set adopted for the engine defaults: `Work`, `Personal`, `Journal`, `Uncategorized` (existing UI still shows the old names until TASK-048).
    - **Built 2026-11-21 (implementer, reviewed)**: `LLMService.generate(prompt, maxOutputTokens)` (fresh scope per call, cap enforced by counting streamed chunks then `stop()`, throws on not-loaded / timeout / engine error, never returns partial text; `nPredict = -1`, `nBatch = max(batchSize, nCtx)` because the binding rejects prompts longer than nBatch); `lib/features/synthesis/domain/folder_definition.dart` (`defaultFolders`: Work, Personal, Journal, Uncategorized); `synthesis_prompts.dart` (organise / write / update prompts ported byte-identical from the lab, `parseOrganiseReply`, output budgets); `integration_test/synthesis_llm_eval_test.dart`. Unused `LLMConfig` fields `clearKvCacheEveryXTurns`, `kvCacheTtl`, `inputTokenLimit` removed; `maxOutputTokens` in `LLMConfig` is now unused (drop in TASK-049b).
    - **Phone run 1, Pixel 7a, Qwen2.5-1.5B Q4_K_M, debug build, 2026-11-21** (results, git-ignored: `integration_test/voice_samples/real/synthesis_llm_eval_2026-11-21_run1.json`):
      - **Context size changes memory only.** Outputs and timings were identical at 2048 / 4096 / 8192. App memory (PSS) after load: 1819 / 2024 / 2151 MB; after dispose ≈ 520 MB (test-harness baseline). So the model costs ≈ 1.3 GB, and going 2048 → 8192 costs ≈ +330 MB (≈ 54 KB per token of window; the earlier 30 KB estimate was low).
      - **Speed**: reading the prompt ≈ 50 tokens/s, writing ≈ 9 tokens/s (reading ≈ 5.5x faster, confirming that rewriting from raw thoughts costs little more than updating). Load: 76 s the first time after install (cold file), ≈ 10 s afterwards.
      - **Turn times**: organise 3 thoughts 8.6–11 s; organise 5 thoughts 12–19 s; write 34 words 8 s; write 3 thoughts / 181 words 27 s; write one 252–275 word thought 38–41 s; write 4 thoughts / 729 words 113–120 s (output 721 words, faithful).
      - **Quality limits found**: (a) writing ALL 21 unrelated thoughts (1101 words) produced garbage at every context size — the model described its own instructions in 86 tokens instead of writing the note; (b) organising all 21 at once returned an invalid reply on the phone (valid on the Mac), while batches of 3 and 5 were valid and sensible; (c) the update turn dropped the second new thought ("book the big meeting room"). So the limit is the model's reliability on long/many-item input, not the window: 729 words is verified good, 1101 words / 21 thoughts is bad, the cliff in between is unmeasured.
      - **Consequences for TASK-049b**: context 4096 is enough for this model (8192 buys nothing); organise in batches of at most 5 thoughts; a write turn takes at most ~700 words of raw thoughts until the cliff is located; every write reply needs a sanity check (e.g. output far shorter than a clean-up of the input could be → invalid); for a session beyond the write limit the measured evidence is against the agreed "existing note + new thoughts" LLM update — orchestrator proposes writing only the new thoughts and appending them to the note (no LLM edit of existing text). Needs the user's decision.
    - **Condensing / structuring test on the Mac (the "transformation" the user wants from Synthesis)**, prompt in `tool/synthesis_prompt_lab/structured.py` (title + grouped short bullets, keep every fact): Qwen2.5-1.5B fails — 275 words → 45 words of vague bullets, loses facts (stomach upset, ankle pain, running, who the shoes are for), ignores the title rule, switches to third person. Qwen3-4B does it well — title, 9 complete bullets, 104 words, facts kept. Conclusion: the current model can clean a transcript but cannot reliably condense and structure; a ~4B model can. Since condensed output is about 40% of the length, total time may be similar despite slower generation. **Next**: phone run with Qwen3-4B Q4_K_M (2.5 GB; user allowed a phone model test) to measure load, memory, speed and whether `llama_cpp_dart` 0.2.2 loads it; Qwen3 needs `<think>\n\n</think>\n\n` appended after the assistant header to disable thinking.
    - **Phone run 2, Qwen3-4B Q4_K_M, context 4096**: the model loaded in 11.7 s (so `llama_cpp_dart` 0.2.2 can load Qwen3), app memory after load 3879 MB, then Android killed the app during the first turn (`exit-info`: `LOW_MEMORY`, RSS 4.5 GB). A 4B Q4 model does not fit on the Pixel 7a (7.6 GB RAM, ~3 GB available) as configured. Model file removed from the phone again. The eval test now takes `--dart-define=SYN_MODEL=…`, `SYN_CTX=…`, `SYN_EMPTY_THINK=true` (Qwen3) and `SYN_TEMPLATE=llama3`, and has four `structured` turns.
    - **Condensing prompt on the mid-size models (Mac)**: Llama-3.2-3B Q4_K_M (2.0 GB) does it well — title, headings, complete first-person bullets, facts kept, 275 → 173 words; Qwen3-1.7B states wrong facts ("baby will eat because of stomach upset", "shoes for self and baby"). Phone run 3 = Llama-3.2-3B at context 4096 to see whether it fits in memory and how fast it is.
    - **Phone run 3, Llama-3.2-3B Q4_K_M, context 4096** (results git-ignored: `…/real/synthesis_llm_eval_2026-11-21_run3_llama32-3b.json`; model removed from the phone afterwards, normal build reinstalled): loads in 10.8 s; app memory 3528 MB after load and ≈ 4.2 GB during turns (not killed this time, but the 4B was killed at 4.5 GB RSS, so this is at the edge); 1562 MB after dispose (not back to baseline — unexplained). Speed: reading ≈ 20 tokens/s, writing ≈ 3–4 tokens/s. Clean turns: structured note from the 275-word clip 74 s (title + 10 complete bullets, facts kept, "clod" corrected to "cloud"); structured note from 4 thoughts / 729 words 149 s → 267 words under four headings, facts kept with one slip ("my baby's apps" for "mine and hers"). The organise replies were invalid with the Llama template (not investigated). Memory is far above the file size (2.0 GB file → ≈ 3 GB added); untested levers: `gpuLayers = 0` (file-backed, reclaimable pages), smaller `nBatch`, a smaller quantisation.
    - **BUG found in `LLMService.generate` (must be fixed in TASK-049b before any production use)**: when the output cap is hit, `stop()` does not end the stream before `generate` returns, and chunks are not tied to a prompt, so text from the capped turn leaks into the next turn's output (seen in run 3: turns 4, 10, 11 and 12 contain text from earlier turns; turn 4 then ran 550 s). Run 1 never hit the cap, so its results are clean. Fix direction: after a cap or timeout, wait for that prompt's completion event (or reload) before returning, and discard chunks that do not belong to the current prompt.
    - **Middle path on the current model (Mac, `tool/synthesis_prompt_lab/sectioned.py`: keep the sentences, only group under topic headings)**: still unreliable — changed a meaning ("I had a bad night…, so it is still going to be fun"), dropped the app-launch target, and inverted a fact ("Stretching in evenings: causes back pain"). Qwen2.5-1.5B is dependable only for the plain clean-up write.
    - **TASK-070 conclusion (to the user 2026-11-21, decision pending)**: with Qwen2.5-1.5B, Synthesis can deliver correct folders in small batches and a faithful cleaned note, but not condensing or restructuring. A 3B model delivers the structured note but needs ≈ 4.2 GB on the Pixel 7a as configured and is ≈ 2.5x slower; a 4B model does not fit. Options put to the user: (A) build the engine now on the 1.5B with the clean-up note and make the model swappable; (B) first spend a session on getting a 3B model to fit safely (memory levers above, licence check), then build on it; orchestrator recommends A then B, since the engine is the same either way.
  - **Verification**: numbers and sample outputs recorded in this task's Progress Log and shown to the user before TASK-049b starts.

- [/] **TASK-049: Synthesis Engine — Context-Aware Organise Turn, Write Turn, Model Residency & Automatic Triggers (rewritten 2026-11-21 from the approved design, `IMPLEMENTATION.md` 4.B)**
  - **Area**: `lib/features/synthesis/domain/` (`synthesis_engine.dart`, `synthesis_model_profile.dart`, `synthesis_prompts.dart`, `session_clock.dart`), `lib/features/synthesis/application/` (runner, triggers), `lib/features/synthesis/data/synthesis_repository.dart`, `lib/features/ai_processing/` (`llm_service.dart`, `model_residency_arbiter.dart`, `model_lifecycle_manager.dart`, `llm_config.dart`)
  - **Spec**: `PRODUCT_SPEC.md` FR5.5 (No Fallback), FR11.8 (triggers), FR11.11 (session definition)
  - **User decision 2026-11-21**: build the engine first on the current model (it is model-agnostic), "but the bottom line is that we gotta make things work as per the product expectation"; then "double down on model optimisations for Llama 3.2 3B" (TASK-071). Product expectation = the condensed, organised note, which only the 3B delivered.
  - **Details (decisions made by the orchestrator within the approved design)**:
    1. *Part 1 — LLM call and residency (`ai_processing`)*: fix the `generate` leak (collect only this prompt's chunks; after cap/timeout/cancel stop and wait ≤15 s for that prompt's completion event, else dispose the service and throw `LlmEngineStuckException`); `cancelActiveGeneration()` → in-flight call throws `LlmCancelledException`; strip `<|im_end|>` and `<|eot_id|>`; one generate at a time; engine seam for unit tests. `LLMConfig`: drop `maxOutputTokens`, context default 4096, generation timeout 5 min. `ModelResidencyArbiter`: speech and language model never resident together; speech always wins (`acquireSpeech()` preempts the language holder and waits for its release; `tryAcquireLanguage(onPreempt)` is refused while speech holds); `ModelLifecycleManager` acquires before loading the speech model, releases on eviction/failed load, exposes `isBusy`.
    2. *Part 2 — pure engine (`synthesis/domain`)*: `SynthesisModelProfile` (model file, chat format chatml/llama3, note style cleanUp/structured, organise batch 5, write limit 700 words, output-ratio sanity bounds) makes the model swappable. `organise()`: new thoughts in time order → time groups (session clock) → batches ≤5; each batch sees the joinable sessions (existing or formed earlier in the run; note or thoughts cut to 60 words); reply validated by `parseOrganiseReply`; invalid/capped/timeout → split the batch (never resend an identical prompt — sampling is greedy); a single thought that still fails is reported failed. Thoughts then join the session of the same folder they fit by capture time (`t ≥ start`, `t − start < 2 h`, `t − last ≤ 45 min`) or start a new one. `write()`: all raw thoughts in one turn while ≤ write limit (note replaced); beyond it, with an existing note, only the new thoughts are written and **appended** (the LLM "existing note + new thoughts" update is dropped: it lost facts in every TASK-070 measurement; `buildUpdatePrompt` deleted); otherwise pieces ≤ limit joined by a blank line; each reply sanity-checked (not capped, non-empty, length within the profile's ratio bounds), invalid → split, single thought failing → session not written.
    3. *Part 3 — runner, persistence, triggers (`synthesis/application` + repository)*: one run at a time; does not start while recording or while the capture queue has pending items; evicts the speech model, takes the language slot, loads the LLM, organises, then writes session by session and **commits each session only after its write succeeded** (create/update cluster, mark unread, thoughts → `synthesized`); failed thoughts stay `processed` with `Note.synthesisAttempts` incremented (automatic runs skip a thought after 3 failed attempts; the manual action always retries; engine faults and preemption do not count as attempts); preemption by capture cancels the turn, unloads the LLM and ends the run (uncommitted work is redone next time); LLM always unloaded at the end of a run. Triggers per FR11.8: count threshold (default 3), quiet window (default 15 min), manual; settings values persisted. Replaces the placeholder `synthesizeRawNotes()`. `isReprocessing` sessions (style change, merge, eject) are rewritten by the same run and the flag cleared.
    4. *Interpretation to confirm with the user*: "a closed session changes only on explicit user action" is applied by **capture time** — a thought processed late (e.g. after a failed attempt) still joins the session it belonged to in time; it never joins a session whose window had ended when the thought was spoken.
  - **Out of scope here**: folder management and overlap guard (TASK-048), action extraction (TASK-050), UI for failed thoughts and run progress (TASK-041/042/051), 3B model fit (TASK-071).
  - **Verification**:
    - **Unit Tests**: `test/features/ai_processing/llm_service_test.dart`, `model_residency_arbiter_test.dart`, `model_lifecycle_manager_test.dart`; `test/features/synthesis/synthesis_engine_test.dart`, `synthesis_prompts_test.dart`, runner/repository/trigger tests (Part 3).
    - **Gate**: `~/flutter/bin/dart analyze`, `~/flutter/bin/flutter test test/`, `cd android && ./gradlew :app:testDebugUnitTest`, debug APK build.
    - **Device**: one end-to-end run on the Pixel 7a over the user's real thoughts (memory never shows both models, a recording during a run preempts it, sessions appear only after both turns).
  - **Progress Log**:
    - 2026-11-21: task text rewritten; Parts 1 and 2 delegated in parallel (disjoint directories). Part 3 to be briefed after both are reviewed.
    - 2026-11-21: **Parts 1 and 2 DONE and reviewed by the orchestrator** (uncommitted). Part 1: `LLMService` now runs on an `LlmEngine`/`LlmPromptSession` seam (`LlamaCppEngine` real implementation, load logic unchanged); per-prompt chunks only; stop-and-wait (15 s) after cap/timeout/cancel; `cancelActiveGeneration()`; `ModelResidencyArbiter` wired into `ModelLifecycleManager` (`isBusy` added). Orchestrator fixes on review: a failed prompt (completion event `success == false`) now throws instead of returning empty text; arbiter hands the hold to speech even when the preemption callback releases synchronously (test added). Part 2: `synthesis_engine.dart`, `synthesis_model_profile.dart`, `ChatFormat` parameter on the prompt builders, `buildUpdatePrompt` removed (also turn 10 of the phone measurement test). Note for TASK-071: the llama3 format now starts with `<|begin_of_text|>` (the earlier phone run did not) — check for a doubled BOS when investigating the invalid organise replies. Gate: `dart analyze` 0 issues, `flutter test test/` 275 passed. Part 3 (runner, repository operations, triggers, `Note.synthesisAttempts`, manual buttons) delegated to an Opus implementer.
    - 2026-11-21: **Part 3 DONE and reviewed** (uncommitted): `application/synthesis_runner.dart` (`SynthesisRunResult`, `isSynthesisCandidate`, `synthesisRunningProvider`), `application/synthesis_trigger_controller.dart` (20 s settle delay, quiet timer, 60 s retry after `busy`), `application/synthesis_settings.dart` (thresholds persisted with `shared_preferences`, already a dependency), `presentation/manual_synthesis.dart` (the four manual buttons start a run without waiting and show a SnackBar), repository `createSession` / `updateSession` / `removeEmptySession`, placeholder `synthesizeRawNotes()` deleted, `Note.synthesisAttempts` added (generated code rebuilt), trigger started in `main.dart` and notified from the audio queue wiring. Orchestrator fixes on review: a `preempted` run is retried like a `busy` one (a preempting recording may never yield a thought); a session deleted by the user during the run is not written to (its thoughts stay in Capture). Known limits: the HUD button is not disabled during a run (needs `pipeline_hud_modal.dart`); a recording that starts while the LLM is still loading waits for that load before the speech model loads (recording itself is not blocked). Gate: analyze 0 issues, `flutter test test/` 310 passed, `:app:testDebugUnitTest` exit 0, debug APK built.
    - 2026-11-21: **First end-to-end run on the Pixel 7a FAILED — root cause found**: the automatic trigger fired at launch and the run loaded the model, but the first organise turn that hit its output cap could not be stopped: log "Warning: Stop command timed out, forcing state reset." → `LlmEngineStuckException` → run `failed` (no session created, no attempts counted — correct per FR5.5). Cause: `llama_cpp_dart` 0.2.2's child isolate loops over an `async*` generator around the synchronous FFI token call and never returns to its event loop, so stop / dispose / free-slot messages are not read until the model ends by itself; the model memory was then never freed (PSS stayed ≈ 2.6–2.9 GB after "disposed"). This is also the real cause of the TASK-070 leak bug, of the 550 s turn and very likely of the "1562 MB left after dispose" seen with Llama 3.2 3B. **Fix in progress (Opus implementer)**: replace `LlamaParent`/`LlamaScope` with our own worker isolate (`llama_isolate_engine.dart`) on the package's `Llama` class: per-prompt token cap enforced in the worker, event-loop yield after every token so stop is honoured, awaited dispose with isolate kill as last resort; runner disposes the LLM fully before releasing the arbiter. After review: re-run on the phone. App was force-stopped on the phone after the failed run (the build on it is the uncommitted Part 3 build; user data intact).
    - 2026-11-21: **Worker-isolate engine DONE, reviewed, verified on the phone.** `llama_isolate_engine.dart` (`LlamaIsolateEngine`, `runTokenLoop`), `LlmEngine.sendPrompt(prompt, maxOutputTokens)`, awaited `dispose()` (shared teardown future), runner disposes before releasing the arbiter; orchestrator raised `stopTimeout` 15 s → 2 min (prompt reading is one uninterruptible native call; killing the worker leaks the model). Gate: analyze 0 issues, `flutter test test/` 320 passed, `:app:testDebugUnitTest` exit 0 (run before the engine swap; no Kotlin change since), debug APK built and installed with `adb install -r`. **Device run 2 (Pixel 7a, screen locked, automatic trigger at launch)**: run `completed` in ≈ 5 min; 10 sessions created from the user's waiting thoughts (the 22 evaluation clips plus later test thoughts), 4 thoughts failed validation and stayed in Capture with one attempt counted; PSS ≈ 2.45 GB during the run, 572 MB after unload (model really freed). Quality as predicted by TASK-070 for the 1.5B: folders mostly right with visible misfiles (a Riverpod bug-fix thought and a capture-button idea filed under `Personal`; the long "how I capture ideas" monologue under `Journal`), notes are a light clean-up close to concatenation, not the condensed organised note the product expects → TASK-071.
    - **Still open in TASK-049**: HUD button not disabled during a run; `appliedStyleId` has no effect on the prompt. Closed 2026-11-22: the four failed thoughts (rejected only for the reply's form, see TASK-071 log) and the stale `IMPLEMENTATION.md` 1.D figures. Preemption by a real recording was exercised on the phone on 2026-11-22 (TASK-073 Progress Log).

- [/] **TASK-071: Make a 3B-Class Model Fit Safely on the Pixel 7a for the Organised Note (Llama 3.2 3B first)**
  - **Area**: `lib/features/ai_processing/llm_config.dart`, `lib/features/synthesis/domain/synthesis_model_profile.dart`, `integration_test/synthesis_llm_eval_test.dart`, `tool/synthesis_prompt_lab/`
  - **Spec**: `PRODUCT_SPEC.md` FR11 (synthesis note quality), memory NFR
  - **Details**: requested by the user 2026-11-21 ("double down on model optimisations for Llama 3.2 3B") after TASK-049. Baseline (TASK-070 run 3, Q4_K_M, ctx 4096, `gpuLayers` 99, `nBatch` 4096): PSS 3528 MB after load, ≈4.2 GB during turns (Android killed a 4.5 GB process), 1562 MB left after dispose (unexplained), reading ≈20 tok/s, writing ≈3–4 tok/s, organise replies invalid with the Llama template (not investigated). Levers to measure one at a time: `gpuLayers = 0` (CPU only), smaller `nBatch` with prompt fed in batches (binding rejects prompt > nBatch — may need a binding patch or fork), smaller context (2048) with the write limit lowered to match, KV cache type, smaller quantisation (Q4_0 / Q3_K_M / IQ variants) checked for note quality on the Mac lab first, mmap vs mlock, thread count for speed. Also: fix the Llama-template organise failure, find the write cliff (words) for the 3B, investigate the 1.5 GB not freed after dispose, licence check (Llama 3.2 Community License vs Apache-2.0 Qwen), and compare other 3B-class candidates only if Llama cannot be made to fit. Target to propose to the user: peak PSS with a safe margin below the observed kill line, and a Synthesis latency budget for the NFR table.
  - **Verification**: measurements recorded in this task's Progress Log; structured-note quality re-checked on the user's real thoughts; no LMK kill across a full run on the Pixel 7a.
  - **Progress Log**:
    - 2026-11-22 **User report after commit `4d0bd79`** (three issues): (1) red error block on the Synthesis screen (`DropdownButton` assertion, value `Personal`); (2) phone slow across apps after merely opening the app; (3) PocketPal runs a 4B Q4_K_M model fine on the same phone, so find out why this app cannot. User confirmed: a late-processed thought joins the session of its capture time; appending to an oversized session is acceptable for now, to be revisited with a better model. User also requires synthesis to work with the screen off.
    - 2026-11-22 **Issue 1 root cause and fix (uncommitted)**: the per-card folder menu and the filter menu in `synthesis_screen.dart` had hard-coded old folder names (`Work, Ideas, Todos, Journal, Uncategorized`); the engine files into `defaultFolders` (`Personal` is new), so a `Personal` card threw. Not caught because widget tests used only old names and the orchestrator verified phone run 2 through the database and logs without opening the screen. Fix: both menus derive from `defaultFolders`; the card menu also contains the session's own folder if it is not in the list. New widget test renders one card per assignable folder plus a legacy folder. **Process rule added: after any device run that creates UI data, open the affected screen on the phone (screenshot) before reporting.** Known remaining: a 30-character folder name overflows the card header at 360 dp (matters for custom folders, TASK-048).
    - 2026-11-22 **Issue 2 evidence** (app log `app_flutter/logs/app_logs.txt` + `dumpsys activity exit-info`): on both launches (08:50, 08:55) `SynthesisTrigger` started a run 20 s after launch ("note threshold") for the 4 thoughts that had already failed twice; neither run logged an end; the second process still held RSS 3.0 GB when Android killed it (`LOW_MEMORY`) at 10:38. With the phone untouched the same run completes in 90 s (reproduced 11:30), so the hang happens only with the screen in use; cause NOT yet proven (suspect: llama Vulkan compute competing with the UI on the Mali GPU). Fixes so far (uncommitted): `SynthesisTriggerController.start()` only arms the quiet-window timer (no run right after launch); thoughts with a failed attempt no longer count towards starting a run (`maxAttempts: 1` in the trigger's eligible count) but are retried inside a run started by new thoughts; runner logs run start, duration, and the thought ids that failed at organise or write. Still open: reproduce the hang with the screen on; an attempt is not counted when the process dies mid-run.
    - 2026-11-22 **Issue 3 findings**. PocketPal v1.24.0 / llama.rn source (research subagent, citations in conversation only): Android default is CPU only (no Vulkan in its build; OpenCL only on Adreno), `n_ctx` 2048, `n_batch`/`n_ubatch` 512, f16 KV, mmap off, threads ≈ 80 % of cores, prompts fed in `n_batch` chunks, llama.cpp built per CPU feature set (`armv8.2-a+dotprod[+i8mm]`, `-O3`, no OpenMP) and picked at runtime. Our bundled libs (Oct 9, origin unknown, not from the commit the binding pins) reported `NEON | ARM_FMA | LLAMAFILE | OPENMP | REPACK` — **no DOTPROD**; plus Vulkan full offload. Android cpusets on this phone: background = cores 0–3 (little only), foreground = 0–5, top-app = 0–7 — a screen-off run in a process without a foreground service gets only little cores.
    - 2026-11-22 **Native libs rebuilt (uncommitted)**: `tool/build_llama_android.sh` builds llama.cpp `4ffc47cb2001e7d523f9ff525335bbe34b1a2858` (the submodule of `netdur/llama_cpp_dart@8d441a0` = 0.2.2; ffigen file byte-identical) for arm64, CPU only, `GGML_CPU_ARM_ARCH=armv8.2-a+dotprod`, no OpenMP, no Vulkan, `GGML_BACKEND_DL=OFF`, 16 KB aligned, stripped; jniLibs now 5.5 MB (was 54.7 MB; `libggml-vulkan.so`, `libomp.so` removed). Old libs backed up in the session scratchpad only. Two failures on the way: (a) load failed with `invalid value for main_gpu: 0 (available devices: 0)` → engine now sets `nGpuLayers = 0`, `mainGpu = -1` (`LLMConfig.gpuLayers` is now dead and must be removed); (b) first build used `+i8mm` and crashed with SIGILL — the Pixel 7a (`/proc/cpuinfo`: `asimddp`, no `i8mm`) has dotprod only. A build that picks variants at runtime for other phones is NOT done (devices without dotprod crash).
    - 2026-11-22 **Measurements, Llama 3.2 3B Q4_K_M, ctx 4096, 4 threads, Pixel 7a** (`SYN_SKIP_ALL=true`; results in scratchpad, to be copied to the git-ignored `integration_test/voice_samples/real/`): OLD libs, GPU off, screen off (little cores): PSS 3286 MB after load, ≈3.4 GB in turns, 729-word write 349 s (TTFT 53 s, 2.4 tok/s). NEW libs, screen on but phone thermally throttled from the previous runs (Thermal Status 2, big cores capped at 1.28 of 2.85 GHz): PSS 2612 MB after load, 2.75–2.84 GB in turns, **295 MB after dispose**, 729-word write 290 s (TTFT 120 s, 4.2 tok/s), structured 729 words 189 s. Organise replies still invalid with the Llama format (model prefixes "Thoughts:" / "Here are the sorted thoughts:" or returns the wrong count) — prompt/parse work needed. Sustained runs heat the phone into throttling: thermal behaviour is a real constraint for run length. Cool-start reruns of 3B and Qwen3-4B in progress.
    - Other changes 2026-11-22 (uncommitted): llama3 chat format no longer starts with `<|begin_of_text|>` (the binding tokenizes with `add_special = true`, so it was doubled); eval harness options `SYN_THREADS`, `SYN_SKIP_ALL`. Phone: `svc power stayon usb` was enabled for testing — turn off with `adb shell svc power stayon false` when done; evaluation models `llama32-3b.gguf` and `qwen3-4b.gguf` are on the phone (4.5 GB; storage 99 % full) — remove the unused ones afterwards.
    - 2026-11-22 **Cool-start measurements, CPU-only dotprod libs, ctx 4096, 4 threads, app on screen** (result files git-ignored in `integration_test/voice_samples/real/synthesis_llm_eval_2026-11-22_*.json`): **Llama 3.2 3B** PSS 2738 MB after load, 2.69–2.81 GB in turns, 333 MB after dispose; 729-word write 275 s (TTFT 110 s, 716 tokens ≈ 4.3 tok/s), structured 729 words 197 s, structured 275 words 107 s; folder replies invalid in the app's parser at the time (`Thoughts:` heading; 8 entries for 5 thoughts). Turns 2–6 of that run were 5–8× slower (TTFT up to 324 s) — most likely the test app was off screen then and confined to the little cores (it has no foreground service); not proven. **Qwen3-4B** (`SYN_EMPTY_THINK=true`): PSS 2824 MB after load, 3.31–3.37 GB in turns, 306 MB after dispose, **not killed**; both folder replies valid (`1: Personal` form); 729-word write 406 s (TTFT 167 s, 763 tokens ≈ 3.2 tok/s), structured 729 words 273 s, structured 275 words 112 s; structured notes good (title + 9–10 short bullets, facts kept). The "cool start" lasted seconds: after 10 min of cooling the first turn was no faster than in the warm run, and the fast-core cap was back at 0.98 GHz of 2.85 GHz by the end. Speed from a truly cold phone is still unmeasured.
    - 2026-11-22 **Real app, Qwen2.5-1.5B, CPU-only libs** (`fgrun.sh` in the scratchpad: taps Synthesize Now, samples `dumpsys meminfo`, `/proc/<pid>/cpuset`, per-thread CPU, frequency caps): PSS 1.66–1.81 GB with the app on screen, 1.57–1.63 GB in the background, 311–351 MB after unload (Vulkan build: 2.45–2.52 GB). On screen the four threads sit on cores 4–7 (`/top-app`); after HOME the process is in `/foreground` (cores 0–5: two mid, four little) and stays there (foreground service). Seven organise turns took 322 s (25 s on screen, rest in the background) and 212 s fully on screen with the caps at ≈ 1 GHz; the Vulkan build did the same seven turns in ≈ 90 s. **So for this small model the CPU build is 2–3.5× slower than the GPU build was, in exchange for ≈ 0.8 GB less memory; for the 3B/4B the CPU build is what makes them fit.** `gfxinfo` reports no frames for a Flutter surface, so screen smoothness during a run is not measured.
    - 2026-11-22 **Wake lock, attempt counting, GPU setting removed** (Sonnet implementer, diff reviewed, gate rerun by the orchestrator): `ProcessingWakeLock.kt` + `cpu_wake_lock.dart` (per-owner `PARTIAL_WAKE_LOCK` with timeout; synthesis run and queue worker), attempts counted at run start and undone for a preempted run, `LLMConfig.gpuLayers` deleted. On the phone `dumpsys power` lists `Eudemonia:synthesis` during a run. Not verified unplugged (USB prevents suspend) — needs the user's test.
    - 2026-11-22 **Why four thoughts never synthesized — found and fixed**: new `SynthesisEngine.onRejected` diagnostics (logged by the runner) showed every reply was `Thoughts:` + `1. Journal` / `2. Personal` — a heading the model echoes from the prompt and a dot instead of a colon; the single-thought retries answered with two entries for one thought. `parseOrganiseReply` now reads the form leniently (`:`, `.` or `)` after the number, blank lines, one heading line without digits) and nothing else; tests added. Rerun on the phone: "Organised into 4 session(s)", run `completed after 459s; 0 thought(s) not synthesized` (25 s on screen, the rest in the background), Synthesis screen checked by screenshot ("In Sync", new cards render). Quality note: the 1.5B filed a thought about the app's speech-model loading under `Journal`.
    - **Levers found but not built (candidates for TASK-073 / later TASK-071 work)**: (a) the static instructions are ≈ 75–80 % of an organise prompt and most of a short write prompt (1528 prompt characters for 58 words of thoughts; 1115 for 34 words) and are re-read every turn at 11–16 tok/s — reuse of the identical prefix inside a run removes most of the time of short turns; (b) prompt reading is one native call (up to ≈ 2–2.5 min for a 700-word session on the CPU), so a recording that preempts a run can wait that long for its transcript — feed the prompt in small chunks with a stop check; (c) the binding creates no persistent ggml thread pool (a disposable pool per decode call) and the library is built without OpenMP — attach a pool with `ggml_threadpool_new` / `llama_attach_threadpool` (both in the bindings) and A/B it; prompt reading with the old OpenMP library looked ≈ 2× faster in one uncontrolled comparison (thermal state differed); (d) thread count per cpuset (4 on screen, up to 6 in `/foreground`), read from `/proc/self/status` `Cpus_allowed_list`; (e) per-turn sampler with a GBNF grammar for the organise turn (Llama 3.2 3B); (f) Q4_0 quantisation uses repacked dot-product kernels that Q4_K_M does not get on this CPU; (g) prefilling the answer with `1:`; (h) context 2048 for runs that fit; (i) a build that selects dotprod / i8mm / baseline at runtime for other phones; (j) a newer llama.cpp for newer models (the binding pins Dec 2025).
    - 2026-11-22 late evening — **Structured-note prompt reworked after the first Qwen3-4B run lost details** (user report: session `#S-01` came back as terse sentences, "already purchased E6 shoes" became "Buy E6 shoes"). Reproduced on the Mac (Homebrew `llama-server`, same GGUF, raw ChatML prompt with the empty think block, greedy; lab scripts `lab.py` / `labcmp.py` in the session scratchpad, sessions exported from the phone with `integration_test/synthesis_reset_test.dart`). Cause: the prompt asked for "as few words as possible" and showed no example; the model's format and fidelity swung with every wording change (variants: no title or bullets, third person "the user", near-verbatim output, whole thoughts dropped). Measure used: per-thought coverage (share of a thought's distinctive words found in the note) plus key facts. Old prompt: coverage 0.28–0.42 on long thoughts, 612 output tokens for the 8 sessions (1271 spoken words). **Chosen prompt** (one worked example, complete first-person sentences, rule that every numbered thought must appear): title and bullets in all sessions, every thought ≥ 0.67 coverage, 1478 output tokens (≈ 2.4× the writing time); one sentence still lost in one session (launch target in `#S-01`). The variant that let related details share a bullet dropped whole thoughts and was rejected. **Code**: `_structuredSystem` (prompt), `structuredOutputBudget` = 1.3 × words + 96, `qwen3_4b` profile write limit 500 words and valid output 0.4–1.3 of the input, new reply check `thoughtsMissingFrom` (`minThoughtCoverage` 0.3; a note that leaves a thought out is rejected and the piece is split). Gate: analyze 0 issues, `flutter test test/` 358. User requirement recorded in the spec: fidelity before brevity (FR11.14); per-folder default style is TASK-075 (decision pending). The asterisks around titles are left as they are (user decides later); the example keeps them so the output is consistent.
    - 2026-11-22 22:28–22:59 — **New prompt verified on the Pixel 7a (old engine, app on screen)**: 8 sessions deleted and re-written from the same 28 thoughts; run `completed` in 1862 s (organise 9.7 min as before, writing 21.3 min against 10.7 min with the terse prompt — the price of the longer notes on the old engine), peak PSS 3473 MB, 365 MB after unload, no write reply rejected, thought 29 again unfiled (`Answer: Work`, form only). Export `integration_test/voice_samples/real/synthesis_export_qwen3-4b_newprompt_2026-11-22.md` scored against the raw thoughts: every session has a title and bullets, lowest thought coverage 0.67–1.0 (before: 0.28–0.42 and one session without title or bullets); `#S-01` on the phone is word for word the Mac lab output ("I already purchased E6 shoes, and we will get one for her also"), including its one known loss (the launch-target sentence). Cards checked by screenshot, 0 exceptions in logcat.

- [x] **TASK-073: Own llama.cpp Generation Loop in the Worker Isolate (Prefix Reuse, Interruptible Chunked Prompt Reading, Per-Turn Grammar, Persistent Thread Pool)** — *approved by the user 2026-11-22 on option C (own binding for a current llama.cpp), together with the `AGENTS.md` 4.C wording; **done and verified on the Pixel 7a 2026-11-23***
  - **Area**: `lib/features/ai_processing/llama_isolate_engine.dart`, `lib/features/ai_processing/llm_service.dart` (`LlmEngine.sendPrompt` options), `lib/features/synthesis/domain/synthesis_prompts.dart` (grammar for the organise reply), `integration_test/synthesis_llm_eval_test.dart`
  - **Spec**: `PRODUCT_SPEC.md` FR11 (synthesis), capture-priority NFR; `AGENTS.md` 4.A and 4.C
  - **Details**: replace the package's `Llama` class inside the `llm-worker` isolate by a loop on the raw `llama_cpp` bindings (`Llama.lib`): own model/context/sampler handles; tokenize once; decode the prompt in chunks of at most 64–128 tokens with a stop check between chunks (preemption latency of seconds instead of minutes); keep the KV entries of the longest common token prefix with the previous prompt of the same run and decode only the rest (`llama_memory_seq_rm` from the divergence point) — output must be token-identical to a cold turn (greedy), verified by a test on the phone; sampler chain per prompt (greedy; optional GBNF grammar passed by the caller, used for the organise reply so its form is always valid while the folder remains the model's choice); a persistent ggml thread pool attached to the context; thread count chosen per prompt from the allowed CPU set. Everything is released at the end of the run as today. **Needs the user's agreement to reword `AGENTS.md` 4.C** ("each turn complete and independent, release KV between tasks") to: a turn's output never depends on earlier turns; an identical prompt prefix may be reused inside one run; all model state is released when the run ends.
  - **Verification**: unit tests of the pure parts (chunk planning, common-prefix length, stop between chunks, cap, completion messages) through the existing engine seam; on the Pixel 7a: identical outputs with and without prefix reuse for the measurement turns; run time of a typical 5-thought run before/after; a recording started during prompt reading gets its transcript within 15 s; no memory left after dispose.
  - **Library findings (2026-11-22, evidence from the llama.cpp git history and the package registry)**: `llama_cpp_dart` 0.2.2 is still the latest stable release (published 2026-01-02) and pins llama.cpp `4ffc47c` of **2025-12-28**; master on 2026-11-22 (`8d60873`) is 5072 commits ahead, 219 of them in `ggml/src/ggml-cpu`. (1) **Models**: Qwen3.5 files declare architecture `qwen35`, added by `fc0fe400` on 2026-02-10, so the pinned library cannot load the model the user ran in PocketPal (`Qwen3.5-4B-Q4_K_M`, Apache-2.0; PocketPal 1.24.0 uses llama.rn 0.13.0-rc.11 of 2026-11-12 with llama.cpp sources vendored). `smollm3` is known at the pin. (2) **CPU speed work after the pin that applies to a dotprod-only ARM phone and Q4_K_M files**: Q4_K scale vectorisation (`6ad70c5a`, 2026-01-28); repacked dot-product kernels for Q6_K (`c03a5a46`, 2026-02-10) and Q5_K (`bc160d35`, 2026-02-23) — at the pin only Q4_0, Q4_K and Q8_0 are repacked, so the Q6_K tensors inside a Q4_K_M file take the slower path (this corrects lever (f) in TASK-071: Q4_K itself is repacked at the pin); flash-attention CPU work (`bcb43163` tiled FA for prompt processing, `9f682fb6` FA split for generation, `684b3610` GEMM microkernel); tiled mul_mat for K-quants (`d834d44e`, 2026-09-26); NEON 4x4 gemm tile (`ab4a77b9`, 2026-11-12). (3) The app runs with **flash attention off** (package default `disabled`; `llama_isolate_engine.dart` never sets it). (4) The package has a pre-release line, `0.9.0-dev.12` (2026-08-01): rewritten API (`LlamaEngine`, `EngineChat`), pins `afeebe10` of 2026-07-29 (knows `qwen35`), bundles its own Android libraries through a native-assets hook, needs Flutter ≥ 3.44 (installed: 3.47.5). **Foundation options for this task**: (A) stay on 0.2.2 and only write the loop; (B) move to 0.9.0-dev.12; (C) own `ffigen` binding for a llama.cpp commit we choose, own loop, own libraries (`tool/build_llama_android.sh` already builds them). Measured comparison and source review: see Progress Log.
  - **Progress Log**:
    - 2026-11-22 evening — **Source review** (research agent on Sonnet; evidence by file and line in its report, clones in the session scratchpad `research/`). `llama_cpp_dart` 0.9.0-dev.12 (tag commit `04743fd`; llama.cpp `afeebe10` = b10182; last release 2026-08-01, last commit on main 2026-08-07; README: the API "may break once more before 1.0"; MIT): a raw prompt can be run without forced templating (`EngineSession.generate`, or the synchronous classes `LlamaModel` / `LlamaContext` / `LlamaSession` / `Generator`, usable inside our own isolate after `LlamaLibrary.load`); **no automatic prefix reuse** (the caller keeps a session and appends, or calls `memorySeqRm`; the chat API clears the cache every turn); **prompt reading cannot be cancelled** (`Generator._prefill` loops `llama_decode` without a check; `abort_callback` exists only in the raw bindings and is listed as deferred); sampler chain per request, but **any GBNF grammar aborts the process at the tag** (issue #112, fixed on main in `23dae0b`, unreleased) and `greedy: true` skips the grammar; **no thread pool is created or attached** (raw bindings only); the bundled Android AAR is arm64 CPU-only and built **without `GGML_CPU_ARM_ARCH`** (checked in the binary: no dot-product instructions) — `bundle_android: false` plus own `.so` files from the same commit is possible; the bindings are ffigen output tied to the pinned commit. **llama.rn 0.13.0-rc.11 (PocketPal 1.24.0)**: vendors llama.cpp b12292 (`af6b5243`, 2026-11-11); reuses the common prefix of the previous prompt (`find_common_prefix_length` + `llama_memory_seq_rm`); decodes the prompt `n_batch` tokens at a time and checks an interrupt flag after each batch; attaches a persistent ggml thread pool; builds the CPU variants `v8`, `v8_2`, `v8_2_dotprod`, `v8_2_i8mm`, `v8_2_dotprod_i8mm` and picks one at run time; no OpenMP. **Consequence**: PocketPal's engine already does the four things this task proposes, on a library two weeks old. Option B would still need our own loop (interruptible reading, prefix reuse, thread pool), our own libraries and an unreleased grammar fix, on a pre-release that has not moved since August — the orchestrator recommends **option C** (decision is the user's).
    - 2026-11-22 evening — **Speed comparison on the Pixel 7a, raw library without the app** (`llama-bench` built with the production flags at three commits; Qwen3-4B Q4_K_M; 256 prompt tokens, 32 generated, 2 repetitions; one process per run, each started below 45 °C with no frequency cap; figures are tok/s read / write; FA = flash attention):
      - Cores 4–7 (two mid, two fast), 4 threads — pin `4ffc47c`: 20.6 / 7.3 (repeat 20.3 / 6.7), FA on 20.2 / 8.0; `afeebe10` (2026-07-29): 27.6 / 7.0, FA on 29.6 / 7.4; master `8d60873`: 26.9 / 6.9 (repeat 27.3 / 6.8), FA on 30.0 / 7.4.
      - All eight cores allowed, 4 threads — pin 20.0 / 6.6; master 27.3 / 6.9: with a persistent pool the scheduler finds the fast cores by itself.
      - Cores 0–5 (the `/foreground` set an app gets when it is not on screen) — pin: 4 threads 7.7 / 3.5, 6 threads 9.7 / 4.0, 2 threads on cores 4–5 8.8 / 4.6. Master with FA: 4 threads 11.6 / 4.9, 6 threads 17.1 / 3.9, 2 threads on 4–5 13.5 / 4.6. No frequency cap appeared in these 80-second runs.
      - Cores 0–3 (`/background`), 4 threads — pin 3.9 / 1.9.
      - Sustained (8 repetitions, ≈ 2.5 min, cores 4–7) — pin: read 20.2 → 12.3 from the fourth repetition, write 4.9; master with FA: read 30 → 18, write 5.2. The fast-core cap falls from 2.85 to 0.98 GHz and the mid-core cap from 2.35 to ≈ 1.0 GHz within 60–65 s.
      - Thread pool (`bench/tptest.c`: the package's call pattern on the pinned library, with and without `llama_attach_threadpool`; generation here starts at 256 tokens of context) — cores 4–7: no pool 19.0–19.6 / 5.9–6.1, pool 18.9–19.8 / 6.3–6.8; cores 0–5: no pool 10.2 / 3.4 then 6.3 / **0.34** (one repetition stalled for 94 s), pool 9.4 / 3.9 then 6.7 / 3.2.
    - **Conclusions (2026-11-22)**: (1) the library's age costs 35–48 % of reading speed and nothing measurable on writing; the July commit is as fast as master. (2) Flash attention on is worth ≈ 8–10 %. (3) After about a minute at full load, heat removes ≈ 40 % of reading and ≈ 30 % of writing speed and it stays there — sustained figures are the ones that count for a run. (4) Off screen the process is confined to cores 0–5 and today's fixed 4 threads give 7.7 / 3.5; the newer library with 6 threads for reading (`n_threads_batch`) and 2–4 for writing (`n_threads`) gives ≈ 17 / 4.6–4.9 on the same cores. (5) A persistent thread pool is worth only ≈ 5–10 % of writing speed; one unexplained 94-second stall was seen without a pool on the confined cores (single sample). (6) The app's own figures for this model (read ≈ 7–10, write ≈ 3.2–4.3 with 270–1150 prompt tokens, 2026-11-22 cool-start file; prompt tokens estimated as characters / 4) fall between the hot all-core figures (12.3 / 4.9) and the cores-0–5 figures (6.3–10 / 3.2–3.9): heat, the allowed cores and longer contexts explain them within the uncertainty; no large loss inside the Dart layer was found. Not closed: which core set the app had during that run — the run log must record allowed cores, thread counts, thermal status and tok/s per turn. (7) Writing speed for a 4B Q4_K_M model on this phone is bounded near 5 tok/s sustained by the hardware; the structured note style produces about half the output tokens of the clean-up style (360 against 763 for the 729-word session) and is the main lever on note time.
    - **Proposal after measurement (2026-11-22, awaiting the user)**: build this task on **option C** — own `ffigen` binding for a current llama.cpp commit (candidate: b12292 `af6b5243`, the one llama.rn 0.13.0-rc.11 ships), libraries from `tool/build_llama_android.sh`, the `llama_cpp_dart` dependency removed — and add to the scope: flash attention on; thread counts chosen per prompt from the allowed core set, separately for reading and writing (`llama_set_n_threads`); allowed cores, thermal status and tok/s per turn in the run log. Expected for Qwen3-4B off screen: reading 7.7 → ≈ 17 tok/s, writing 3.5 → ≈ 4.6–4.9, and organise turns skip the ≈ 75 % of their prompt that is static. Order proposed to the user: first the Qwen3-4B production profile and switch on the current library (TASK-071 next step), then this task, then TASK-072.
    - 2026-11-22 late evening — **Approved by the user; design written** (`IMPLEMENTATION.md` 4.D). Pinned commit: `af6b5243` (b12292). Built at that commit: Android `llama-bench` with the production flags and a macOS CPU build for host tests (session scratchpad `llama-build/wt-pin2`, `host-pin2`). **Chunk size** (Qwen3-4B, all cores, 4 threads, flash attention on, 256 prompt tokens): 512-token chunks read 32.0 tok/s, 128 → 30.2, 64 → 30.1, 32 → 26.1 → **64** (−6 %, a stop waits ≈ 2–4 s). **Threads**, all cores: 4 threads 30–32 read / 7.4–7.6 write, 6 threads 26.0 / 6.4, 8 threads 20.9 / 1.3; cores 0–5: 2 threads 14.5 / 5.1, 3 threads 11.1 / 4.6, 4 threads 11.6 / 4.9, 6 threads 17.1 / 3.9 (14.6 read with 64-token chunks) → **one rule for reading and writing: as many threads as fast cores are allowed (2–4); when only the slowest class is allowed, up to 4**. Implementation delegated to an Opus `eudemonia-implementer` in a git worktree (binding, backend, loop, thread policy, isolate engine, seam, organise grammar, harness, host test of the real library); the orchestrator keeps the build scripts, the Android libraries, the review and the phone verification.
    - 2026-11-22 23:02–23:21 — **First phone runs of the new engine (harness, Qwen3-4B, app on screen, heat-soaked phone, organise + structured turns, `drive2.sh`)**: both runs completed; **all 6 replies identical with and without prefix reuse**; both grammar-bound organise replies valid; threads 4/4 on cores 0-7. Reuse: organise turn 2 kept 192 of 524 prompt tokens (read 15.0 s against 31.1 s), structured turns kept 448 tokens — the instructions and the worked example — (read 18.4 / 27.7 / 71.4 s against 44.9 / 55.2 / 95.0 s). Reading without reuse ≈ 14–19 tok/s hot (old engine 7–10); writing 2.8–3.5 tok/s in this heat-soaked state (206 tokens in 58 s, 639 in 230 s) — no faster than the old engine, as the benchmark predicted: writing is bound by heat. **Memory problem found and fixed**: PSS after load was 4.5–4.6 GB (old engine 2.8 GB), falling to 3.3 GB over the turns. Cause measured with `llama-bench -lm` and `/proc/<pid>/smaps_rollup`: this llama.cpp repacks the Q4_K/Q6_K weights into its own buffers at load, so with the default memory map the file is held twice — peak 4250 MB (2463 anonymous + 1787 file) against 2812 MB with load mode `none` or `dio`; speed unchanged. Fix: `NativeLlamaBackend` loads with `LLAMA_LOAD_MODE_DIRECT_IO` (no second copy, no page-cache pollution). Consequence to remember: the weights are now anonymous memory (not evictable) — the peak is what the device must really have.
    - 2026-11-22 23:31–23:40 — **Direct I/O verified in the app (harness, same six turns)**: load 9.2 s (old engine 4.8 s: the weights are repacked at load), PSS 3538 MB after load and flat at 3566–3582 MB through the turns (old engine 3.3–3.4 GB; first new-engine runs 4.5–4.6 GB after load), 286 MB after dispose; replies identical to the memory-mapped runs. The spec's memory figure for Qwen3-4B is now ≤ 3.7 GB. Context 4096 costs ≈ 600 MB of that; a smaller context for runs that fit stays an open lever.
    - 2026-11-22 23:42–23:56 — **Full app run with the new engine** (same 28 thoughts, same prompts, app on screen, phone already hot): `completed` in **845 s** against 1862 s with the previous engine (organise 3.6 against 9.7 min; writing phase 10.5 against 21.3 min); 15 turns, 9382 prompt tokens of which 4352 (46 %) reused, 15.1 tok/s decoded, 1639 output tokens at 3.28 tok/s; **0 thoughts unfiled** (the grammar removed the `Answer: Work` failure); peak PSS 3651 MB, 349 MB after unload; 8 sessions, cards checked by screenshot, 0 exceptions in logcat. Export: `integration_test/voice_samples/real/synthesis_export_qwen3-4b_ownengine_2026-11-22.md` (git-ignored).
    - 2026-11-22 23:58 — **Preemption by a real recording** (one session deleted with the reset tool, manual run, recording started from the Capture screen capsule 46 s into the run while the organise prompt was being read): trigger 23:59:16.36 → recording started 17.30 → run preempted 18.86 → model freed 19.48 → speech model loaded 27.33 → recording stopped 22.77 → transcript result 28.40 (silent room: "No speech detected", the test card was deleted). The run ended `preempted after 50s` and the manual run afterwards completed (378 s). **Finding**: the recording started 937 ms after the trigger, against 105–476 ms in the eleven earlier recordings in the log — the model's four threads on the fast cores delay the start of capture (one sample; follow-up in TASK-072 / TASK-063).
    - 2026-11-23 00:09 — **Off screen** (one session deleted, manual run, HOME pressed 3 s after the start): process in `/foreground`, log shows `threads 2 reading / 2 writing on cores 0-5` on every turn, run `completed` in 154 s for 3 thoughts; hot-phone speeds 7.5–12 tok/s reading, ≈ 2.9 tok/s writing; the wake lock was taken and released. **Verification list of this task: all met** (unit tests, host test of the real library, identical replies with and without reuse, run time before/after, transcript within 15 s of a recording during reading, memory back to baseline). **Left open, recorded elsewhere**: screen-off on an unplugged phone (the user's test); whether more threads read faster off screen once the phone is hot; the runtime CPU-variant build for phones without dotprod; context smaller than 4096 for runs that fit (≈ 600 MB); llama.cpp's load-time log on stderr (≈ 2.5k lines, harmless on Android).

- [ ] **TASK-072: Thermal, Battery and Device-State Guardrail for Automatic Synthesis Runs**
  - **Area**: `lib/features/synthesis/application/` (new single-purpose guard consulted by `SynthesisRunner` / `SynthesisTriggerController`), `android/app/src/main/kotlin/` (thermal status via `PowerManager.getCurrentThermalStatus` / `OnThermalStatusChangedListener`), `lib/features/settings/system_telemetry_service.dart`
  - **Spec**: `PRODUCT_SPEC.md` FR11.8 (automatic synthesis triggers); a battery/thermal NFR is to be added with the user's agreement
  - **Details**: requested by the user 2026-11-22. Measured on the Pixel 7a (TASK-071, 2026-11-22): a sustained CPU-only run of a 3B model drives the SoC to 80–86 °C within minutes; Android reports Thermal Status 1–2 and caps the fast cores at 0.98–1.28 GHz of 2.85 GHz, which more than halves token speed and slows the whole phone. The guard must decide **before** a run and **between turns**: do not start an automatic run when thermal status is at or above a threshold (proposal: MODERATE); pause or end the run between turns when it crosses the threshold and resume after cooling; bound the continuous work per run (turn or time budget) so a backlog is processed in several cooled slices. Also to decide with the user: battery level / charging condition, and behaviour with the screen on versus off. A manual run shows the reason instead of silently refusing. No fallback output of any kind; unprocessed thoughts stay in Capture.
  - **Added after TASK-073 (2026-11-23)**: with reading twice as fast, **writing is now the larger part of a run and it is bound by heat** — ≈ 7.5 tok/s on a cool phone, ≈ 5 after two minutes, ≈ 3 after an hour (Qwen3-4B). To examine here: (1) whether fewer threads on unthrottled cores beat four threads on throttled ones in the steady state (cores 0–5 showed no frequency cap in 80-second runs); (2) cool-down slices between turns; (3) the capture-start delay seen during a run (937 ms against 0.1–0.5 s, one sample): lower priority for the model's threads or one fast core left free while the app is on screen — capture must not wait for the model (`AGENTS.md` 4.A).
  - **Verification**: unit tests for the guard decisions (start refused / paused between turns / resumed / manual run told why) with a fake thermal source; Kotlin unit test for the status mapping; on the Pixel 7a a backlog run stays below the chosen thermal status and completes in slices.

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
  - **Progress Log**: 2026-11-21: implemented by `eudemonia-implementer`, diff reviewed by the orchestrator. Gate: `dart analyze` 0 issues, `flutter test test/` 231 passed, `:app:testDebugUnitTest` passed, debug APK built and installed on the Pixel 7a (`adb install -r`, data kept). User report 2026-11-21 after recording several thoughts on the new build: every thought after the first is "blazing fast"; the first was slow. Cause confirmed in code: `warmupOnRecordingStart()` existed but was never called (disabled after Chronicle #5, when it meant ~1.6 GB of two models during capture), so the cold speech-model load began only after the recording ended. Fix same day (orchestrator, small edit): `CaptureController` calls it once a recording has actually started; the warmup now starts the idle countdown itself when nothing follows it. Gate: `dart analyze` 0 issues, `flutter test test/` 234 passed, APK rebuilt and installed (`adb install -r`). Kotlin untouched. STILL to verify on device: first thought after the model has been evicted (>TTL idle or app restart) is now fast; no stutter/late haptic at recording start; app memory with speech model only. `integration_test/voice_pipeline_eval_test.dart` still exercises the LLM directly and should get an STT-only mode when next used.
  - **Verification**:
    - **Unit Tests**: `test/features/ai_processing/` — saved note equals transcript with fillers preserved and folder `Uncategorized`; queue never reports `categorizing`; lifecycle loads/evicts only STT and succeeds with no LLM file.
    - **Widget Tests**: N/A.
    - **Integration / Command Tests**: full gate; on device: record a thought, card shows transcript; measure STT time and app PSS with STT only.

- [ ] **TASK-068: On-Device Speech Recognition Accuracy — Evaluate Model Options & Vocabulary Biasing Against the Real-Voice Set**
  - **Area**: `lib/features/ai_processing/stt_engine.dart`, `download_models.sh`, evaluation harness; Settings vocabulary option only if biasing works.
  - **Spec**: [`PRODUCT_SPEC.md#fr4-on-device-speech-recognition-stt`](./PRODUCT_SPEC.md#fr4-on-device-speech-recognition-stt)
  - **Details**: Whisper large-v3 (Mac) transcribed all clips Parakeet int8 missed (`r05`, `r06`, `r12`, `r15`, `r17`, `r21`), so the audio is adequate. Compare on the 22 real clips: Parakeet with non-quantized encoder, a phone-sized Whisper (turbo/small via sherpa-onnx), and sherpa-onnx hotword biasing for user terms (check support for the TDT model). Record WER, speed and memory per option. Also re-measure STT speed with no LLM loaded (it was ~1s for short clips before the LLM loaded, ~real time after). Changing the model needs user approval.
  - **Verification**: To be specified with the design.

- [ ] **TASK-065: Validated Model Catalogue per Device-Memory Tier (Benchmark of Small Models for 6 GB / 8 GB / 12 GB Phones: Quality, Speed, Memory, Heat) — Future**
  - **Area**: `integration_test/synthesis_llm_eval_test.dart` (phone harness), `tool/synthesis_prompt_lab/` (Mac lab), `lib/features/synthesis/domain/synthesis_model_profile.dart` (one profile per catalogue model)
  - **Spec**: [`PRODUCT_SPEC.md#a-deferred-features--roadmap-v15--v20`](./PRODUCT_SPEC.md#a-deferred-features--roadmap-v15--v20) (`Device-Tier Model Recommendation`); requested by the user on 2026-11-20, detailed on 2026-11-22.
  - **Details**: produce the 3–4 models offered to users (TASK-074), each with measured evidence. Candidates named by the user 2026-11-22: **SmolLM3 3B** (PocketPal lists it at 1.81 GB — that is most likely the download size, memory in use must be measured: Llama 3.2 3B is a 2.0 GB file and needed 2.7–2.8 GB), **SmolLM2-1.7B-Instruct** (reputation for summarising), **Qwen3 4B** (3.3–3.4 GB measured on the Pixel 7a, expected too large for a 6 GB phone). Also to include: Qwen3.5-4B and a smaller Qwen3.5 (need the newer library, TASK-073), Llama 3.2 3B (licence check), Qwen2.5-1.5B (current baseline). For each model: a `SynthesisModelProfile` (chat format, thinking switched off where the model has it, note style); folder accuracy and note quality on the TASK-070 measurement set; read/write speed on a cool and on a warm phone; peak memory and memory after unload; heat; licence. Output: a catalogue table (model, download size, memory needed, minimum device memory, one-line quality description) in `IMPLEMENTATION.md`. Open at pickup: no 6 GB test phone is available — the minimum-memory rule is derived from measured peak memory plus a margin until one is.
  - **Verification**: one results file per model (git-ignored where it contains the user's transcripts); catalogue table reviewed by the user; profiles unit-tested.

- [ ] **TASK-074: First-Launch Model Chooser with In-App Download and Device-Memory Gating — Future**
  - **Area**: new `lib/features/model_setup/` (chooser screen, download service, device-memory rule) prototyped in `previews/` first; `android/app/src/main/kotlin/` (total device memory via `ActivityManager.MemoryInfo.totalMem`); `lib/features/ai_processing/model_file_validator.dart`
  - **Spec**: [`PRODUCT_SPEC.md#a-deferred-features--roadmap-v15--v20`](./PRODUCT_SPEC.md#a-deferred-features--roadmap-v15--v20) (`Device-Tier Model Recommendation`, amended 2026-11-22). The model download is the app's only network use and was requested by the user (an `AGENTS.md` Ask-First item); hosting source to be confirmed at pickup.
  - **Details**: requested by the user 2026-11-22. When the app is opened for the first time it shows the 3–4 catalogue models (TASK-065), each with its memory footprint and a short quality description. The app reads the phone's memory and greys out (not selectable) the models that are too large for it, e.g. Qwen3 4B on a 6 GB phone. Selecting a model starts its download. Needed around that: free-storage check, resumable download, integrity check (size and SHA-256) before first load, Wi-Fi versus mobile-data choice, licence text, changing the model later in Settings. Until a model is present, capture and transcription work and thoughts wait in Capture — no fallback output. To decide with the user at pickup: where the files are hosted, whether the speech model is delivered the same way (today both models are copied to the phone with `adb`), and what happens to existing notes when the model is changed.
  - **Depends on**: TASK-065 (catalogue and profiles), TASK-073 (a library that can load every catalogue model).
  - **Verification**: widget tests including 360dp (greyed-out state, progress, failure and resume), unit tests for the memory rule and the download state machine, check on a fresh install on the Pixel 7a.

- [ ] **TASK-075: Default Note Style per Folder in Settings (Product Decision Pending) — Future**
  - **Area**: `lib/features/synthesis/domain/synthesis_model_profile.dart` (`NoteStyle`), `lib/features/synthesis/domain/synthesis_prompts.dart` (one write prompt per style), folder settings (with TASK-048), `previews/` first
  - **Spec**: [`PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering`](./PRODUCT_SPEC.md#fr11-synthesis-predefined-folders--session-clustering) FR11.14 (`Default Note Style per Folder`, `Fidelity Before Brevity`), FR11.7 (style presets)
  - **Details**: proposed by the user 2026-11-22 after a `Personal` note came back as terse sentences: each folder could carry a default writing style (bullets under headings, flowing paragraphs, …) chosen in Settings and applied by the write turn. Decide with the user first: which styles exist, how they relate to the on-demand style re-writer (FR11.7, `appliedStyleId` currently has no effect), and whether the style belongs to the folder or to the session. Every style must satisfy Fidelity Before Brevity and be measured for it on the user's sessions (the lab check of thought coverage and key facts used on 2026-11-22) before it is offered.
  - **Verification**: to be specified with the design; at least prompt tests per style, engine tests that the folder's style selects the prompt, and a phone run compared against the raw thoughts.

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

