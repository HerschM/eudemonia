---
name: eudemonia-quality-gate
description: Standard Operating Procedure (SOP) to run the full quality gate, static analysis, 360dp narrow viewport constraint checks, Flutter unit/widget tests, and native Android tests.
---

# Eudemonia Quality Gate & Verification Standard

This skill defines the non-negotiable verification sequence that any AI agent or human contributor must execute before committing changes, concluding an atomic task, or creating pull requests in the Eudemonia repository.

## Quality Gate Standard
Every contribution must strictly satisfy:
1. **0 errors and 0 warnings** in static analysis.
2. **100% passing tests** across affected unit and widget test suites.
3. **Zero framework layout assertions or `RenderFlex` overflows**, explicitly verified on narrow 360dp mobile viewports.
4. **Zero regressions** in the full test suite.

---

## Verification Sequence

Execute these steps in order:

### Step 1: Static Analysis Gate
Run Dart static analysis across the preview sandbox and test suite, or the entire codebase:

```bash
# Preview sandbox & tests (Fast check during UI iterations)
~/flutter/bin/dart analyze previews/ test/previews/

# Repository-wide static analysis (Quality gate standard)
~/flutter/bin/dart analyze
```
- **Standard**: Must output `No issues found!` or 0 errors and 0 warnings.
- *Note*: If running inside a sandboxed environment where `~/flutter` is outside workspace boundaries, execute with appropriate permissions.

### Step 2: Component & Preview Tests
Run isolated widget and mock data tests:

```bash
~/flutter/bin/flutter test test/previews/
```

### Step 3: Narrow Viewport (360dp) & Framework Assertion Verification
Mobile screens range down to 360dp width. All UI components and modal sheets must be verified against layout overflows:

In widget tests, configure the 360dp viewport:
```dart
tester.view.physicalSize = const Size(360 * 2, 800 * 2);
tester.view.devicePixelRatio = 2.0;
addTearDown(() => tester.view.resetPhysicalSize());
```
- Assert that no `RenderFlex overflowed by X pixels` occurs.
- Avoid placing unconstrained horizontal `Row` widgets directly inside narrow containers; use `Wrap` with `spacing` and `runSpacing`, or use `Flexible`/`Expanded` children.
- Ensure ink splash effects have a valid `Material` ancestor.

### Step 4: Full Repository Regression Test
Run the full test suite to guarantee zero side-effects across core, AI processing, persistence, and navigation:

```bash
~/flutter/bin/flutter test
```
- Confirm that all unit and widget tests pass.

### Step 5: Native Android Unit Tests (When Touching `android/`)
If native Kotlin code, accessibility services, debouncers, or foreground keep-alive services were modified:

```bash
cd android && ./gradlew :app:testDebugUnitTest
```

---

## Failure Triage Guide

1. **`RenderFlex overflowed by X pixels`**:
   - Locate the offending `Row` in the stack trace.
   - Replace rigid `Row` with `Wrap(spacing: ..., runSpacing: ...)`, or wrap text/elements in `Expanded` / `Flexible`.
2. **`Looking up a deactivated widget's ancestor is unsafe`**:
   - Occurs when an asynchronous callback or disposal accesses an ancestor `BuildContext` after the widget is popped.
   - Cache inherited references in `didChangeDependencies()` or perform operations before popping the navigator.
3. **`Missing Material ancestor`**:
   - Ensure widgets utilizing ink splashes (like `InkWell` or `ListTile`) are wrapped in `Material(color: Colors.transparent, child: ...)`.

