# AGENTS.md — Eudemonia Guidelines & Developer Contract

> This document defines the operating guidelines, core invariants, development standards, and verification workflows for AI agents working in the **Eudemonia** codebase. It adheres to open agentic standards (Linux Foundation / AAIF), prioritizing high-level contracts and architectural guardrails over brittle implementation details.

---

## 1. Project Overview & Tech Stack

Eudemonia is an on-device, zero-friction, voice-first thought capture system for Android. It captures fleeting thoughts instantaneously via physical hardware buttons, enqueues audio without blocking the user, transcribes speech on-device, and categorizes thoughts locally.

- **Frontend**: Flutter / Dart (State management: Riverpod)
- **Native Android**: Kotlin (Accessibility Service for hardware triggers, Foreground Service for process keep-alive)
- **On-Device AI**: Local Speech-to-Text (STT) and Large Language Model (LLM) inference runtimes
- **Persistence**: Local database (Isar) & file storage

---

## 2. Essential Commands & Verification Loop

Always use these exact CLI commands to build, test, and verify changes.

### Testing Commands
- **Run all Flutter tests**:
  ```bash
  ~/flutter/bin/flutter test
  ```
- **Run a single test file**:
  ```bash
  ~/flutter/bin/flutter test test/path_to_test.dart
  ```
- **Run native Android unit tests**:
  ```bash
  cd android && ./gradlew :app:testDebugUnitTest
  ```

### Static Analysis & Quality Gate
- **Analyze Dart code**:
  ```bash
  ~/flutter/bin/dart analyze
  ```
  *Standard*: All code contributions must achieve **0 errors** and **0 warnings**.

### UI/UX Component Sandbox
- **Run UI/UX preview sandbox (isolated from backend services)**:
  ```bash
  ~/flutter/bin/flutter run -t previews/main_preview.dart -d macos # or chrome/emulator
  ```

---

## 3. Core Architectural Invariants (Non-Negotiable Guardrails)

Future agents may evolve algorithms, models, and UI screens, but must **NEVER** compromise the following system invariants:

### A. Zero-Latency Capture (<5ms)
- Pressing the hardware trigger to start or stop recording must feel instantaneous to the user.
- Enqueue audio and dismiss the recording UI indicator immediately.
- Recording start/stop must **never** block on model loading, disk conversion, or AI inference.

### B. Hardware Button & Audio Safety
- **Pass-Through**: Standard volume adjustment (single clicks, continuous holds) must pass through to system audio transparently. Avoid runaway volume loops or unhandled key consumption.
- **Native Haptics**: Trigger haptic feedback must execute directly in Android native code upon event confirmation. Never defer haptics across asynchronous bridges.
- **No Rogue Launches**: Background hardware interceptors must never launch activities directly from the background; dispatch events via intent broadcasts.

### C. Mobile Memory & Resource Management
- Mobile RAM is severely constrained (~1.6 GB+ for AI models). Unmanaged models risk triggering Android Low Memory Killer (LMK) kills or system blackouts.
- **On-Demand Loading & Inactivity Eviction**: Heavy models must be evicted from memory when idle for a configurable period, returning baseline memory footprint to <60 MB.
- **Sequential Loading**: When loading multiple models, load them sequentially rather than concurrently to prevent peak memory allocation spikes.
- **Stateless Inference**: Each classification turn should be complete and independent. Release inference context and KV cache allocations between tasks.

### D. Background Reliability
- Reliable background operation requires both Accessibility Service (button interception) and Battery Optimization Exemption (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`).
- Keep-alive foreground services must be used responsibly to prevent OS hibernation without draining unnecessary battery.

---

## 4. Test-Driven Development (TDD) & Quality Standards

Agents must follow a strict **Test-Driven Development (TDD)** discipline:

1. **Red -> Green -> Refactor**:
   - When fixing a bug, write a failing unit or widget test reproducing the issue first.
   - When adding a feature, write tests defining the behavioral contract before implementing.
   - Implement the minimal code required to pass, then refactor cleanly.
2. **Contract-Enforcing Test Doubles (Crucial Lesson)**:
   - **Failure Mode**: Mocks/fakes that unconditionally return stubbed data without checking lifecycle readiness give false-positive passes while production crashes.
   - **Rule**: All test doubles for lifecycle-managed services (STT, LLM, queues) **must enforce lifecycle state** (e.g., throwing if called prior to initialization), matching real-world behavior.
3. **Edge Case & Layout Testing**:
   - Verify boundary conditions: empty audio, silent transcripts, rapid trigger presses, narrow viewports (e.g. 360dp width).
   - Ensure widgets do not produce `RenderFlex` overflows or framework assertions.
4. **Task-Driven Execution Loop**:
   - Consult [`TASKS.md`](file:///Users/harshmavani/Documents/Eudemonia/TASKS.md) to pick up the next atomic task (`[ ]` or `[/]`).
   - Maintain strict task boundaries: execute one atomic task at a time, check off sub-tasks, and mark `[x]` upon passing all verification commands.

### B. Task Creation & Maintenance Standards (`TASKS.md`)
When creating or updating tasks in [`TASKS.md`](file:///Users/harshmavani/Documents/Eudemonia/TASKS.md), agents **must** follow these strict rules:
1. **Strict Spec Alignment**: The `Spec` link **must** cite and link directly to the exact line range in [`PRODUCT_SPEC.md`](file:///Users/harshmavani/Documents/Eudemonia/PRODUCT_SPEC.md) using line anchors (e.g., `[PRODUCT_SPEC.md:L146](file:///Users/harshmavani/Documents/Eudemonia/PRODUCT_SPEC.md#L146)`). The link must jump directly to the specific requirement, never to the generic top of the file. Never invent requirements not grounded in the specification.
2. **Never Create Out-of-Scope Tasks**: Consult [`PRODUCT_SPEC.md#5.B`](file:///Users/harshmavani/Documents/Eudemonia/PRODUCT_SPEC.md#L134-L140). Never create tasks for out-of-scope features (e.g., cloud sync, multi-tag graphs, streaming transcription, iOS). If a new capability is needed, update `PRODUCT_SPEC.md` first with human alignment before creating tasks.
3. **Structured Verification Breakdown**: Every task's `Verification` section **must** contain explicit sub-sections:
   - **Unit Tests**: Test file path and specific bulleted test cases covered.
   - **Widget Tests**: Test file path and specific interaction/rendering test cases covered (or `N/A - Non-UI component`).
   - **Integration / Command Tests**: Exact CLI verification command (e.g., `flutter test`, `./gradlew :app:testDebugUnitTest`).
4. **Task Atomicity & Execution Boundaries**: Keep tasks scoped to single atomic units of work so any agent can execute one task from start to finish without scope creep.

### C. UI/UX Modification & Prototyping SDLC (Flutter Code-as-Design)
When designing, modifying, or iterating on user interfaces based on user requirements:
1. **Isolated Component Sandbox (`previews/`)**:
   - All exploratory UI/UX design, visual redesigns, and layout modifications requested by the user must take place in `previews/` using typed mock data.
   - **Never introduce prototype boilerplate, mock datasets, or preview scenario switchers into production (`lib/`)**.
2. **Pure Presentational Widget Contract**:
   - UI widgets in `lib/` must remain pure: accept primitive models/values and callback closures.
   - Presentational widgets must never make direct calls to native platform channels (`MethodChannel`), local databases (`Isar`), or load AI models (`sherpa_onnx`, `llama_cpp_dart`). This guarantees they can be rendered and hot-reloaded instantly in `previews/` without booting backend services.
3. **Promotion Workflow**:
   - Iterate with user feedback in `previews/` until visually approved.
   - Promote the widget to `lib/features/<feature>/presentation/` and wire Riverpod state providers.
   - Add widget tests under `test/features/` ensuring zero framework assertions and layout overflows.

---

## 5. Operational Boundaries (Always / Ask First / Never)

### Always
- Write unit or widget tests for every functional change.
- Verify tests and static analysis (`flutter test`, `dart analyze`) pass with 0 errors before concluding.
- Consult and update [`TASKS.md`](file:///Users/harshmavani/Documents/Eudemonia/TASKS.md) when picking up or finishing tasks.
- Prototype UI/UX screen modifications in the isolated `previews/` sandbox before promoting to production code in `lib/`.
- Provide failure isolation: if one queued item fails, log the error, mark it failed, and continue processing remaining items.
- Use resilient, synchronous state providers (like Riverpod `NotifierProvider`) for values required by new subscribers, avoiding raw broadcast streams that drop past events.
- **Update [`IMPLEMENTATION.md`](file:///Users/harshmavani/Documents/Eudemonia/IMPLEMENTATION.md)** whenever you refactor, optimize, or alter any subsystem to keep the living blueprint synchronized.

### Ask First
- Adding external cloud/network services (Eudemonia is fundamentally an on-device, local-first system).
- Changing database schemas or underlying persistence engines.
- Introducing large third-party native C++ libraries or framework dependencies.

### Never
- Never block the UI thread on AI inference or heavy I/O operations.
- Never wrap `ListTile` directly inside a decorated container without a `Material` ancestor (violates Material ink splash contracts).
- Never commit prototype boilerplate, mock preview data, or scenario switchers into `lib/`.
- Never hardcode machine-specific paths or commit API secrets.

---

## 6. High-Level Project Structure

```
lib/
├── core/                # Core utilities, logging, themes
├── features/
│   ├── ai_processing/   # STT, LLM inference, model lifecycle & queues
│   ├── home/            # Main capture screen & thought feed
│   ├── notes/           # Note models, repositories & database storage
│   └── settings/        # Permissions, diagnostics & configuration
previews/                # Isolated UI/UX Component Sandbox (0 prod boilerplate)
├── main_preview.dart    # Standalone launcher: flutter run -t previews/main_preview.dart
├── mock_data.dart       # Typed mock datasets for all edge cases
├── gallery_shell.dart   # Interactive gallery switcher
└── screens/             # Dedicated screen previews (Home, Capture HUD, Notes, Settings)
android/
└── app/src/main/kotlin/ # Accessibility service, foreground service & debouncers
test/                    # Unit, widget, and architecture tests mirroring lib/
```

---

## 7. Detailed Technical Reference & Evolution History

For comprehensive details on product requirements, how subsystems are currently wired, their internal mechanics, and the chronicle of architectural challenges and historical fixes, refer to:

- [`PRODUCT_SPEC.md`](file:///Users/harshmavani/Documents/Eudemonia/PRODUCT_SPEC.md) — Comprehensive product requirements document, target personas, user journeys, functional/non-functional specs, and product roadmap.
- [`UX.md`](file:///Users/harshmavani/Documents/Eudemonia/UX.md) — Exhaustive UI/UX specification, Flutter Code-as-Design component contracts, and AI modification recipes.
- [`IMPLEMENTATION.md`](file:///Users/harshmavani/Documents/Eudemonia/IMPLEMENTATION.md) — Technical reference, subsystem mechanics, and historical chronicle of fixes.
- [`TASKS.md`](file:///Users/harshmavani/Documents/Eudemonia/TASKS.md) — SDLC task tracker bridging product spec and implementation with completed and pending atomic tasks.

> [!IMPORTANT]
> **`IMPLEMENTATION.md` is a Living Blueprint, Not Absolute Dogma**:
> Treat [`IMPLEMENTATION.md`](file:///Users/harshmavani/Documents/Eudemonia/IMPLEMENTATION.md) as a point-in-time snapshot of the codebase, not an immutable truth set in stone. When touching any subsystem, **always question existing patterns, audit them, and seek to improve them** to meet new requirements rather than accepting legacy choices as rigid constraints. When you make changes to a subsystem, you **must** update [`IMPLEMENTATION.md`](file:///Users/harshmavani/Documents/Eudemonia/IMPLEMENTATION.md) to keep the documentation aligned with the active codebase.

