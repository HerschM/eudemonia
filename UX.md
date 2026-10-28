# UX.md — Eudemonia User Experience & Design Specification

> **Eudemonia Design System & Interaction Blueprint**  
> This document defines the visual design standards, design tokens, agent instructions, ASCII wireframes, and component contracts for all application screens.  
> **Rule**: Code implementation belongs in `.dart` files under [`previews/screens/`](file:///Users/harshmavani/Documents/Eudemonia/previews/screens) and [`lib/features/`](file:///Users/harshmavani/Documents/Eudemonia/lib/features). This file serves as the canonical design contract.

---

## 1. Design Philosophy & Agent Operating Rules

When designing, modifying, or refactoring any screen in Eudemonia, AI agents and developers **must adhere to these core principles**:

1. **OLED-First Minimalist Aesthetic**:
   - Use true pure black (`#0A0A0C` / `#000000`) for dark backgrounds to maximize battery efficiency on OLED displays.
   - Use high-contrast, subtle borders (`rgba(255, 255, 255, 0.08)`) instead of heavy dropshadows.
2. **Glanceability Under Zero Latency (<5ms)**:
   - Voice thoughts are captured instantaneously on physical button triggers. The recording state and queue counts must be legible at an immediate glance without visual clutter.
3. **Strict Cross-Page Visual Consistency**:
   - All screens must use the standardized spacing grid, corner radii, and color tokens defined in [Section 2](#2-design-system-tokens--style-consistency).
   - Never introduce ad-hoc colors, custom paddings, or one-off fonts outside the design system.
4. **Pure Presentational Widget Contract**:
   - UI widgets must accept primitive values and callback closures. Never embed direct calls to native platform channels (`MethodChannel`), databases (`Isar`), or on-device AI inference runtimes (`sherpa_onnx`, `llama_cpp_dart`) inside presentational widgets.
5. **Component Sandbox Prototyping (`previews/`)**:
   - All exploratory UI/UX design changes requested by the user must be implemented and tested in the isolated [`previews/`](file:///Users/harshmavani/Documents/Eudemonia/previews) sandbox first, using typed mock data, before promoting to [`lib/`](file:///Users/harshmavani/Documents/Eudemonia/lib).

---

## 2. Design System Tokens & Style Consistency

### A. Color Palette Tokens

| Token Name | Dark Value (Hex / RGBA) | Light Value (Hex / RGBA) | Usage / Intent |
| :--- | :--- | :--- | :--- |
| `background` | `#0A0A0C` | `#F5F5F7` | Screen background |
| `surface` | `#16161A` | `#FFFFFF` | Cards, list items, dialog containers |
| `surfaceElevated` | `#202026` | `#FFFFFF` | Elevated bottom sheets, dropdowns, popovers |
| `borderSubtle` | `rgba(255, 255, 255, 0.08)` | `rgba(0, 0, 0, 0.08)` | Standard card and container borders |
| `borderFocus` | `rgba(255, 255, 255, 0.16)` | `rgba(0, 0, 0, 0.16)` | Active or focused borders |
| `accentCapture` | `#10B981` (Emerald) | `#059669` | Active recording, haptic confirmation, queue health |
| `accentAction` | `#3B82F6` (Electric Blue) | `#2563EB` | Primary buttons, active category selection |
| `accentAI` | `#8B5CF6` (Violet) | `#7C3AED` | Language-corrected text badges, model processing |
| `accentWarning` | `#F59E0B` (Amber) | `#D97706` | Missing permissions, pending background warnings |
| `accentError` | `#EF4444` (Rose Red) | `#DC2626` | Failed queue items, retry triggers |
| `textPrimary` | `#F9FAFB` | `#111827` | Headings, primary thought text |
| `textSecondary` | `#9CA3AF` | `#6B7280` | Timestamps, metadata, folder labels |
| `textTertiary` | `#6B7280` | `#9CA3AF` | Inactive hints, micro-copy, drag handles |

### B. Typography Scale (Inter / System Sans)

| Style Name | Size | Weight | Tracking | Line Height | Usage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `Display Title` | 24sp | SemiBold (600) | -0.5px | 1.2 | App logo, hero headers |
| `Screen Title` | 20sp | SemiBold (600) | -0.3px | 1.3 | Top AppBar title |
| `Section Title` | 11sp | Bold (700) | +1.0px | 1.4 | Section headers (`FOLDERS`, `RECENT THOUGHTS`) |
| `Thought Body` | 15sp | Regular (400) | 0.0px | 1.5 | Corrected thought content |
| `Badge / Pill` | 11sp | SemiBold (600) | +0.2px | 1.2 | Queue pill, status chips |
| `Metadata` | 11sp | Medium (500) | +0.4px | 1.3 | Timestamps, confidence score tags |
| `Timer / Mono` | 24sp | Bold (700) | +1.0px | 1.0 | Audio recording elapsed timer (`RobotoMono`) |

### C. Spacing, Corner Radii & Elevation Rules

- **Base Spacing Grid**: 4dp / 8dp system.
  - Screen Horizontal Padding: `20dp`
  - Screen Top/Bottom Padding: `12dp`
  - Vertical Gap between Sections: `20dp` to `24dp`
  - Card Inner Padding: `16dp` to `18dp`
- **Corner Radii (`BorderRadius`)**:
  - Cards & Feed Items: `18dp`
  - Bottom Sheets & Modals: `28dp` (top corners)
  - Category Pills & Queue Chips: `20dp` (full capsule)
  - Buttons & Interactive Controls: `12dp`
  - Inner Badges / Tag Chips: `6dp` to `8dp`
- **Glassmorphism Blur Tokens**:
  - Backdrop Filter: `sigmaX: 16`, `sigmaY: 16` (Overlays: `sigmaX: 24`, `sigmaY: 24`)
  - Border Stroke: `1px solid rgba(255, 255, 255, 0.08)`
- **Accessibility & Touch Target Standards**:
  - Minimum interactive touch target: `48 x 48 dp`.
  - Always provide a `Material` ancestor for ink ripple splashes.
  - Verify layout adaptability down to narrow `360dp` viewport width without `RenderFlex` overflows.

---

## 3. UI/UX Modification SDLC & Sandbox Architecture

```
previews/
├── main_preview.dart                 # Preview sandbox runner: flutter run -t previews/main_preview.dart
├── mock_data.dart                    # Typed mock thoughts, timestamps, confidence scores
├── gallery_shell.dart                # Interactive screen gallery & scenario switcher
└── screens/
    ├── home_preview.dart             # Screen 1 Preview (Idle, 2 Pending, Failed Retry, Empty)
    ├── capture_hud_preview.dart      # Screen 2 Preview (Pulsating ring, waveform visualizer)
    ├── note_detail_preview.dart      # Screen 3 Preview (Raw ASR vs. Corrected, Confidence)
    ├── settings_preview.dart         # Screen 4 Preview (Enabled/Disabled chips, RAM telemetry)
    └── permissions_modal_preview.dart# Screen 5 Preview (Dual onboarding sheet)
```

### Modification Workflow for AI Agents:
1. **Never edit `lib/` for exploratory design iterations**: Make design changes in `previews/screens/`.
2. **Launch Preview Runner**:
   ```bash
   flutter run -t previews/main_preview.dart -d macos # or chrome/emulator
   ```
3. **Iterate via Natural Language Prompts**: Use the prompt recipes in Sections 4–8.
4. **Promotion**: Once visually approved, promote the clean presentational widget to `lib/features/<feature>/` and wire Riverpod state providers.

---

## 4. Screen 1: Home Dashboard & Capture Feed

### Screen Overview
The central hub displaying live queue processing status, ambient background permissions alert, horizontal category folders, and a reverse-chronological feed of language-corrected voice thoughts.

### Visual ASCII Wireframe

```
┌────────────────────────────────────────────────────────┐
│  Eudemonia                    [ ⚡ 2 pending ]  [ ⚙ ]  │ ◄── AppBar: Logo + Live Queue Pill + Settings
├────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │ ⚠️  Background Permissions Required     [Enable]│  │ ◄── Ambient Permission Card
│  └──────────────────────────────────────────────────┘  │     (Auto-hides when granted)
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 🌀  Processing voice thought (2 pending)...       │  │ ◄── In-Body Processing Card
│  └──────────────────────────────────────────────────┘  │     (Animated spinner during inference)
│                                                        │
│  FOLDERS                                               │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌──────┐ │
│  │ 💡 Ideas   │ │ 💼 Work    │ │ 📓 Journal │ │ ✅...│ │ ◄── Horizontal Glassmorphic Folders
│  │    14      │ │    28      │ │     7      │ │      │ │     (Emoji + Count badge + Folder name)
│  └────────────┘ └────────────┘ └────────────┘ └──────┘ │
│                                                        │
│  RECENT THOUGHTS                                       │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 💼 WORK • 10m ago                           [ ⋯ ]│  │ ◄── Thought Card
│  │ "Remember to send the quarterly sync notes to    │  │     (Folder badge, relative time,
│  │  Sarah before the end-of-day sprint review."     │  │      language-corrected text)
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 💡 IDEAS • 2h ago                           [ ⋯ ]│  │
│  │ "Explore on-device vector embedding index for    │  │
│  │  instant semantic recall of audio transcripts."  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│         [ 🎙️ Press Vol Up + Vol Down to Capture ]      │ ◄── Ambient hardware trigger hint
└────────────────────────────────────────────────────────┘
```

### Component Contract & Sandbox
- **Sandbox File**: [`previews/screens/home_preview.dart`](file:///Users/harshmavani/Documents/Eudemonia/previews/screens/home_preview.dart)
- **Production Target**: [`lib/features/home/home_screen.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/home/home_screen.dart)
- **Key Parameters**:
  - `int pendingCount`: Count of audio items in queue (renders AppBar pill and In-Body banner when > 0).
  - `int failedCount`: Count of failed items (renders Retry banner when > 0).
  - `bool hasMissingPermissions`: Renders ambient warning card when true.
  - `List<NoteItem> notes`: List of language-corrected thought objects.
  - Callbacks: `onEnablePermissions`, `onRetryFailed`, `onOpenSettings`, `onSelectFolder(folder)`, `onTapNote(noteId)`.
- **States Covered**: `Idle`, `Processing (X pending)`, `Error/Retry`, `Fresh Install (Empty)`.

### AI Modification Prompt Recipe
```markdown
"Antigravity: In previews/screens/home_preview.dart:
1. Add an interactive search bar below the FOLDERS section to filter thoughts by keyword in real time.
2. In the folder carousel, add an 'All' pill selected by default.
3. Add a swipe-to-delete action on thought cards with an undo snackbar."
```

---

## 5. Screen 2: Instant Audio Capture HUD & Waveform Sheet

### Screen Overview
Triggered instantaneously (<5ms) upon dual-volume button hardware press. Displays a dark translucent glassmorphic HUD with a pulsating emerald recording indicator, elapsed duration timer, and dynamic soundwave visualizer. Dismisses immediately on release.

### Visual ASCII Wireframe

```
┌────────────────────────────────────────────────────────┐
│                                                        │
│                    [ (Backdrop Blur) ]                 │
│                                                        │
│    ┌──────────────────────────────────────────────┐    │
│    │               ••••  DRAG BAR                 │    │ ◄── Subtle drag handle
│    │                                              │    │
│    │                  (( 🎙️ ))                    │    │ ◄── Emerald Pulsating Glow Ring
│    │                                              │    │
│    │                  00:04.2                     │    │ ◄── Monospace Audio Timer
│    │                                              │    │
│    │        ▂ ▃ ▅ ▇ █ ▇ ▅ ▃ ▂ ▃ ▅ ▇ ▅ ▃           │    │ ◄── Animated Soundwave Visualizer
│    │                                              │    │
│    │     [ ⚡ Haptic Confirmed • <5ms Capture ]    │    │ ◄── Zero-Latency Confirmation Badge
│    │                                              │    │
│    │         Release buttons to save thought      │    │ ◄── Contextual Micro-Copy
│    └──────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────┘
```

### Component Contract & Sandbox
- **Sandbox File**: [`previews/screens/capture_hud_preview.dart`](file:///Users/harshmavani/Documents/Eudemonia/previews/screens/capture_hud_preview.dart)
- **Key Parameters**:
  - `Duration elapsedDuration`: Current recording time (formatted as `mm:ss.S`).
  - `List<double> soundwaveAmplitudes`: Normalized audio amplitude levels (0.0 to 1.0) driving bar heights.
  - `bool isLocked`: Indicates whether capture occurred from device lock screen.
  - Callbacks: `onCancel`, `onStopAndSave`.
- **States Covered**: `Initial Trigger (<5ms)`, `Active Recording (Pulsing)`, `Max Duration Warning (>60s)`.

### AI Modification Prompt Recipe
```markdown
"Antigravity: In previews/screens/capture_hud_preview.dart:
1. Increase the height and density of the audio waveform visualizer bars.
2. Add a 'Swipe up to cancel' interactive gesture indicator.
3. Add an ambient status chip displaying 'Sherpa STT & Qwen Pre-warmed'."
```

---

## 6. Screen 3: Note Detail, Raw Audio & Taxonomy Inspector

### Screen Overview
Displays the language-corrected thought, alongside collapsible access to the raw ASR transcript, folder classification confidence distribution (e.g., Work: 88%, Ideas: 10%), and an on-device audio playback scrubber for original PCM/WAV recordings.

### Visual ASCII Wireframe

```
┌────────────────────────────────────────────────────────┐
│  [ ‹ Back ]             Thought Inspector       [ 🗑️ ] │
├────────────────────────────────────────────────────────┤
│  AI LANGUAGE CORRECTED                                 │
│  ┌──────────────────────────────────────────────────┐  │
│  │ "Sync with the mobile platform team regarding   │  │ ◄── High-legibility corrected text
│  │  background accessibility debounce latency."     │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ORIGINAL AUDIO PLAYBACK                               │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [ ▶ Play ]  00:02 / 00:05   ▂ ▃ ▅ ▇ █ ▇ ▅ ▃      │  │ ◄── Audio playback scrubber
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  FOLDER CLASSIFICATION & CONFIDENCE                    │
│  [ 💼 Work (88%) ✓ ]  [ 💡 Ideas (10%) ]  [ 📓 (2%) ]  │ ◄── Choice chips with confidence %
│                                                        │
│  ▼ RAW ASR TRANSCRIPT (UNEDITED)                       │
│  ┌──────────────────────────────────────────────────┐  │
│  │ "um like sync with the mobile platform team uh   │  │ ◄── Collapsible raw speech comparison
│  │  regarding background accessibility debounce..." │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  TELEMETRY: Sherpa Parakeet v3 (1.2s) • Qwen 2.5 (0.8s)│ ◄── Model latency badges
└────────────────────────────────────────────────────────┘
```

### Component Contract & Sandbox
- **Sandbox File**: [`previews/screens/note_detail_preview.dart`](file:///Users/harshmavani/Documents/Eudemonia/previews/screens/note_detail_preview.dart)
- **Key Parameters**:
  - `String correctedText`: LLM-corrected markdown/plain text.
  - `String rawText`: Raw Sherpa-ONNX transcript prior to grammar correction and filler word removal.
  - `String selectedFolder`: Currently assigned folder (`Work`, `Ideas`, `Todos`, `Journal`, `Uncategorized`).
  - `Map<String, double> confidenceScores`: Normalized confidence map across folders.
  - `String? audioFilePath`: Local path to original PCM/WAV audio for playback.
  - Callbacks: `onPlayAudio`, `onSeekAudio(position)`, `onFolderChanged(newFolder)`, `onDeleteNote`, `onShareNote`.

### AI Modification Prompt Recipe
```markdown
"Antigravity: In previews/screens/note_detail_preview.dart:
1. Add an inline text-editing mode allowing direct manual edits to the corrected thought text.
2. Add a waveform scrubber slider for interactive seeking during audio playback.
3. Display the exact memory footprint and inference latency tokens at the bottom."
```

---

## 7. Screen 4: Settings & Diagnostics Console

### Screen Overview
Controls background resilience, physical hardware button listener status, audio retention policies, model lifecycle memory telemetry, and real-time rotating diagnostic logs.

### Visual ASCII Wireframe

```
┌────────────────────────────────────────────────────────┐
│  [ ‹ Back ]       Settings & Diagnostics               │
├────────────────────────────────────────────────────────┤
│  HARDWARE & BACKGROUND PERMISSIONS                     │
│  Accessibility Interceptor:        [ ENABLED (Green) ] │ ◄── Standardized Status Badges
│  Battery Optimization Exemption:   [ ENABLED (Green) ] │     (Green = Enabled, Amber = Disabled)
│  Keep Alive Foreground Service:    [ Toggle ON ]       │
│                                                        │
│  AUDIO CAPTURE STORAGE                                 │
│  Keep Raw WAV Audio Files:         [ Toggle OFF ]      │
│                                                        │
│  ON-DEVICE AI MEMORY TELEMETRY                         │
│  Model State: READY  •  RAM: 1.58 GB                   │ ◄── Live RAM Telemetry Gauge
│  Inactivity Eviction Countdown: 02:44 (to <60MB)       │
│  [ Evict Models Now (<60 MB) ]                         │ ◄── Manual memory reclamation trigger
│                                                        │
│  DIAGNOSTIC LOGGING (2MB ROTATING)                     │
│  [ 👁️ View Live Logs ]  [ 📋 Copy Dump ]  [ 🗑️ Clear ] │ ◄── Rotating 2MB Log Tools
└────────────────────────────────────────────────────────┘
```

### Component Contract & Sandbox
- **Sandbox File**: [`previews/screens/settings_preview.dart`](file:///Users/harshmavani/Documents/Eudemonia/previews/screens/settings_preview.dart)
- **Production Target**: [`lib/features/settings/settings_screen.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/settings/settings_screen.dart)
- **Key Parameters**:
  - `bool isAccessibilityGranted`: Controls Accessibility chip (Emerald `Enabled` vs. Amber `Disabled`).
  - `bool isBatteryExemptGranted`: Controls Battery Exemption chip.
  - `bool isForegroundServiceEnabled`: Controls keep-alive toggle switch.
  - `bool keepRawAudio`: Controls audio file retention switch.
  - `String modelLifecycleState`: `Unloaded`, `Loading`, or `Ready`.
  - `String activeRamFootprint`: e.g., `< 60 MB` (idle) or `~1.58 GB` (active).
  - `String evictionCountdown`: e.g., `02:45`.
  - Callbacks: `onToggleForegroundService`, `onToggleKeepAudio`, `onEvictModels`, `onViewLogs`, `onCopyLogs`, `onClearLogs`.

### AI Modification Prompt Recipe
```markdown
"Antigravity: In previews/screens/settings_preview.dart:
1. Add an interactive slider to customize the Inactivity Eviction TTL between 1 and 10 minutes.
2. Add an export button to share the diagnostic log file directly via the Android ShareSheet."
```

---

## 8. Screen 5: Background Permissions Dual-Onboarding Sheet

### Screen Overview
Explains clearly why Eudemonia requires both **Accessibility Service** (for zero-latency physical hardware key interception when locked) and **Battery Optimization Exemption** (to prevent Android Doze hibernation from killing the background listening loop).

### Visual ASCII Wireframe

```
┌────────────────────────────────────────────────────────┐
│               ••••  DRAG INDICATOR                     │
│                                                        │
│  Zero-Friction Voice Setup                             │
│  Eudemonia operates 100% locally on-device. Two        │
│  permissions allow instantaneous button capture        │
│  without keeping the screen turned on:                 │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 1. Accessibility Service         [ ENABLED / ➔ ] │  │ ◄── Step 1: Hardware keys
│  │    Allows dual volume button press detection     │  │
│  │    even when screen is locked.                   │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 2. Battery Optimization Exemption [ ENABLED / ➔ ] │ ◄── Step 2: Prevent Doze
│  │    Prevents Android OS from freezing the         │  │
│  │    transcription queue worker.                   │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  [ All Set — Start Capturing ]                         │ ◄── Activates once both are granted
└────────────────────────────────────────────────────────┘
```

### Component Contract & Sandbox
- **Sandbox File**: [`previews/screens/permissions_modal_preview.dart`](file:///Users/harshmavani/Documents/Eudemonia/previews/screens/permissions_modal_preview.dart)
- **Production Target**: [`lib/features/settings/background_permission_service.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/settings/background_permission_service.dart)
- **Key Parameters**:
  - `bool isAccessibilityGranted`: Visual checkmark / "Done" state for Step 1.
  - `bool isBatteryExemptGranted`: Visual checkmark / "Done" state for Step 2.
  - Callbacks: `onRequestAccessibility`, `onRequestBatteryExempt`, `onDismiss`.

### AI Modification Prompt Recipe
```markdown
"Antigravity: In previews/screens/permissions_modal_preview.dart:
1. Add an animated celebratory checkmark when both permissions become granted.
2. Add a 'Why is this safe?' security FAQ accordion explaining the 0-byte internet network policy."
```
