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

---

## 5. Operational Boundaries (Always / Ask First / Never)

### Always
- Write unit or widget tests for every functional change.
- Verify tests and static analysis (`flutter test`, `dart analyze`) pass with 0 errors before concluding.
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
android/
└── app/src/main/kotlin/ # Accessibility service, foreground service & debouncers
test/                    # Unit, widget, and architecture tests mirroring lib/
```

---

## 7. Detailed Technical Reference & Evolution History

For comprehensive details on how subsystems are currently wired, their internal mechanics, and the chronicle of architectural challenges and historical fixes (including volume button debouncing, sequential model pre-warming, KV cache purging, and Riverpod queue notifiers), refer to:

- [`IMPLEMENTATION.md`](file:///Users/harshmavani/Documents/Eudemonia/IMPLEMENTATION.md)

> [!IMPORTANT]
> **`IMPLEMENTATION.md` is a Living Blueprint, Not Absolute Dogma**:
> Treat [`IMPLEMENTATION.md`](file:///Users/harshmavani/Documents/Eudemonia/IMPLEMENTATION.md) as a point-in-time snapshot of the codebase, not an immutable truth set in stone. When touching any subsystem, **always question existing patterns, audit them, and seek to improve them** to meet new requirements rather than accepting legacy choices as rigid constraints. When you make changes to a subsystem, you **must** update [`IMPLEMENTATION.md`](file:///Users/harshmavani/Documents/Eudemonia/IMPLEMENTATION.md) to keep the documentation aligned with the active codebase.

