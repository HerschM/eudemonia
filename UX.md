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
   - Voice thoughts are captured instantaneously on physical button triggers. Recording indicators and queue states must be legible at an immediate glance without visual clutter.
3. **Four-Stage Cognitive Flow (Progressive Refinement)**:
   - The user interface is strictly structured around a 4-phase transformation pipeline: **Capture** → **Synthesis** → **Insights** → **Action**.
   - Category folder pills are removed from top-level navigation; navigation switches seamlessly across the 4 stages.
4. **Strict Cross-Page Visual Consistency**:
   - All screens must use the standardized spacing grid, corner radii, and color tokens defined in [Section 2](#2-design-system-tokens--style-consistency).
   - Never introduce ad-hoc colors, custom paddings, or one-off fonts outside the design system.
5. **Pure Presentational Widget Contract**:
   - UI widgets must accept primitive values and callback closures. Never embed direct calls to native platform channels (`MethodChannel`), databases (`Isar`), or on-device AI inference runtimes (`sherpa_onnx`, `llama_cpp_dart`) inside presentational widgets.
6. **Component Sandbox Prototyping (`previews/`)**:
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
| `borderFocus` | `rgba(255, 255, 255, 0.16)` | `rgba(0, 0, 0, 0.16)` | Active or focused borders, active tab indicator |
| `accentCapture` | `#10B981` (Emerald) | `#059669` | Active recording, haptic confirmation, queue health |
| `accentAction` | `#3B82F6` (Electric Blue) | `#2563EB` | Primary buttons, active screen tab, calendar sync |
| `accentAI` | `#8B5CF6` (Violet) | `#7C3AED` | AI style re-writer, LLM synthesis indicators |
| `accentWarning` | `#F59E0B` (Amber) | `#D97706` | Missing permissions, pending background warnings |
| `accentError` | `#EF4444` (Rose Red) | `#DC2626` | Failed queue items, retry triggers, delete destructive actions |
| `captureCardBg` | `#16161A` (Neutral Dark) | `#FFFFFF` (Pure White) | Default Capture card background |
| `stateEnqueuedBg` | `#26200A` (Amber / Yellow) | `#FEF3C7` (Pastel Yellow) | Pending processing capture card background (Yellow) |
| `stateProcessedBg` | `#111827` (Electric Blue Tint) | `#DBEAFE` (Soft Blue) | STT & language corrected capture card background (Blue) |
| `stateSynthesizedBg` | `#0B231A` (Emerald / Mint Tint) | `#DCFCE7` (Soft Green) | Synthesis completed capture card background (Green) |
| `stateFailedBg` | `#271111` (Deep Red) | `#FEE2E2` (Soft Red) | Failed processing thought card background (Red) |
| `numberBadgeBg` | `rgba(255, 255, 255, 0.06)` | `rgba(0, 0, 0, 0.06)` | Daily sequence counter badge background (`#01`, `#02`) |
| `numberBadgeText` | `#9CA3AF` (Muted Mono) | `#4B5563` | Daily sequence counter text |
| `unreadDot` | `#60A5FA` (Electric Blue) | `#3B82F6` | Unread/unreviewed thought indicator dot |
| `textPrimary` | `#F9FAFB` | `#111827` | Headings, primary thought body text |
| `textSecondary` | `#9CA3AF` | `#6B7280` | Timestamps, session lengths, metadata chips |
| `textTertiary` | `#6B7280` | `#9CA3AF` | Inactive hints, micro-copy, drag handles |

### B. Typography Scale (Inter / System Sans)

| Style Name | Size | Weight | Tracking | Line Height | Usage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `Display Title` | 24sp | SemiBold (600) | -0.5px | 1.2 | App logo, hero headers |
| `Screen Title` | 20sp | SemiBold (600) | -0.3px | 1.3 | Top AppBar title |
| `Navigation Tab` | 13sp | Medium (500) | +0.2px | 1.2 | Top primary stage tab switcher (`Capture`, `Synthesis`...) |
| `Section Title` | 11sp | Bold (700) | +1.0px | 1.4 | Section headers (`TODAY (#01 - #14)`, `SESSION STATS`) |
| `Thought Body` | 15sp | Regular (400) | 0.0px | 1.5 | Cleaned speech text content |
| `Sequence Badge` | 12sp | Bold (700) | +0.5px | 1.0 | Monospace daily sequence number (`#01`, `#02`, `#S-01`) |
| `Badge / Pill` | 11sp | SemiBold (600) | +0.2px | 1.2 | Raw count pill, urgency chips, status badges |
| `Metadata` | 11sp | Medium (500) | +0.4px | 1.3 | Timestamps (`DD/MM  HH:MM AM/PM`), session durations |
| `Timer / Mono` | 24sp | Bold (700) | +1.0px | 1.0 | Audio recording elapsed timer (`RobotoMono`) |

### C. Spacing, Corner Radii & Elevation Rules

- **Base Spacing Grid**: 4dp / 8dp system.
  - Screen Horizontal Padding: `20dp`
  - Screen Top/Bottom Padding: `12dp`
  - Vertical Gap between Cards: `12dp` to `16dp`
  - Card Inner Padding: `16dp` to `18dp`
- **Corner Radii (`BorderRadius`)**:
  - Cards & Feed Items: `18dp`
  - Bottom Sheets & Modals: `28dp` (top corners)
  - Navigation Switcher Container: `14dp`
  - Sequence Badges & Status Chips: `8dp`
  - Audio Playback Pills: `20dp` (full capsule)
  - Action & Style Preset Buttons: `10dp` to `12dp`
- **Glassmorphism Blur Tokens**:
  - Backdrop Filter: `sigmaX: 16`, `sigmaY: 16` (Overlays: `sigmaX: 24`, `sigmaY: 24`)
  - Border Stroke: `1px solid rgba(255, 255, 255, 0.08)`
- **Accessibility & Touch Target Standards**:
  - Minimum interactive touch target: `48 x 48 dp`.
  - Always provide a `Material` ancestor for ink ripple splashes.
  - Verify layout adaptability down to narrow `360dp` viewport width without `RenderFlex` overflows.

---

## 3. Four-Stage Navigation Architecture & Screen Naming

### A. The Paradigm Shift: From Category Folders to Thought Maturation
In the previous UX design, category folder pills (`Work`, `Ideas`, `Todos`, `Journal`) occupied the global top bar of the home screen. In the revised architecture:
- **Global top folders are relocated**: The app-level header now hosts the persistent 4-stage segmented bar (**`Capture`**, **`Synthesis`**, **`Insights`**, **`Action`**).
- **Predefined Folder Taxonomy is preserved inside `Synthesis`**: The structured folder system (`Work`, `Ideas`, `Todos`, `Journal`, `Uncategorized`) lives directly within the **Synthesis** screen via a sleek **Folder Filter Dropdown** (e.g. `[ 📁 Filter: All Folders ▾ ]`) and card reassignment dropdowns. This eliminates heavy horizontal carousels while preserving strict Single-Folder Discipline and preventing uncontrolled, chaotic auto-tag explosion.
- The 4 stages of thought maturation:
  1. **Capture**: Immediate, unfiltered voice captures. Speech-to-Text + grammar/filler cleanup only. Zero classification or color coding.
  2. **Synthesis**: Clustered and classified thoughts. Disjointed thoughts recorded in a single session or semantically related are synthesized into unified notes and assigned to one of the defined folders, with a compact folder filter dropdown.
  3. **Insights**: High-level macro views, emotion climate heatmaps, project density heatmaps, and recurring pattern dashboards.
  4. **Action**: Execution engine extracting todos, commitments, calendar time-blocks, and calendar synchronizations.

### B. Adopted Screen Naming Architecture

The canonical naming contract for Eudemonia:

$$\mathbf{Capture} \longrightarrow \mathbf{Synthesis} \longrightarrow \mathbf{Insights} \longrightarrow \mathbf{Action}$$

| Stage | Canonical Screen Name | Rationale & User Mental Model |
| :--- | :--- | :--- |
| **Stage 1** | **Capture** | Emphasizes instant, zero-latency physical hardware key capture and immediate playback of unfiltered, cleaned speech. |
| **Stage 2** | **Synthesis** | Communicates that on-device AI has clustered fragmented session captures (e.g. morning walk thoughts) and synthesized them into cohesive notes. |
| **Stage 3** | **Insights** | Reflects macro-level intelligence: emotional climate heatmaps, cognitive energy distribution, topic load, and recurrent habit loops. |
| **Stage 4** | **Action** | Conveys clear execution momentum: extracting commitments into actionable todos, calendar time-blocking, and external calendar synchronization. |

### C. Top Persistent Navigation Bar & Mind Pipeline Architecture

The global top navigation shell clearly separates **AI Machine Processing** from **Human Cognitive Consumption**:

1. **Top AI Status Pill (`[ ⚡ X in Pipeline ▾ ]` / `[ 🌿 In Sync ▾ ]`)**:
   - Represents the aggregate state of the on-device AI pipeline.
   - When jobs are active or queued: Vibrant amber/cyan pill with bolt icon: `[ ⚡ 3 in Pipeline ▾ ]`.
   - When pipeline is fully caught up: Subtle emerald pill: `[ 🌿 In Sync ▾ ]`.
   - **Interactive Pipeline HUD (Tap to Open)**: Tapping this pill opens an interactive modal sheet detailing machine tasks across all 4 stages:
     - **Capture**: Audio files currently awaiting STT & grammar cleanup (`#06 transcribing`).
     - **Synthesis**: Blue capture notes ready to cluster (`2 raw thoughts ready`) + manual `[ ⚡ Synthesize Now ]` button.
     - **Insights**: Periodic refresh countdown (`Next daily refresh in 14h`).
     - **Action**: Synthesized notes awaiting action extraction (`All current sessions extracted`).

2. **Tab Headers with Zero-Suppression Numbers (Human Attention Currency)**:
   - Numbers on tabs strictly denote **unconsumed human value** (unread items or open commitments), eliminating ambiguous dots:
     - `Capture`: Unread raw thoughts (e.g. `Capture (2)`).
     - `Synthesis`: Unread synthesized notes (e.g. `Synthesis (1)`).
     - `Insights`: Unreviewed behavioral pattern alerts or mood shifts (e.g. `Insights (1)`).
     - `Action`: Incomplete / open to-do commitments (e.g. `Action (3)`).
   - **Zero-Suppression Contract**: When a stage has `0` unread/pending items, **the number is omitted entirely** (e.g. `Synthesis` instead of `Synthesis (0)`). This prevents visual clutter and draws the user's eye only to stages requiring attention.

### Visual ASCII Wireframe

```
┌────────────────────────────────────────────────────────┐
│  Eudemonia               [ ⚡ 3 in Pipeline ▾ ]  [ ⚙ ]  │ ◄── Logo + AI Pipeline Pill + Settings
├────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │ ◄── Persistent 4-Stage Segmented Bar
│  │ [Capture (2)] Synthesis (1) Insights (1) Action(3│  │     (Numbers = Unconsumed Value only;
│  └──────────────────────────────────────────────────┘  │      0-count stages show clean label)
│                                                        │
│  (Tapping [ ⚡ 3 in Pipeline ▾ ] opens Pipeline HUD:)   │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 🧠 AI PIPELINE STATUS                     [ ✕ ]  │  │
│  │ • Capture:   1 audio transcribing (#06)          │  │
│  │ • Synthesis: 2 blue notes ready to cluster       │  │
│  │              [ ⚡ Synthesize Now ]                │  │ ◄── Instant manual override
│  │ • Insights:  Next daily refresh in 14h           │  │ ◄── Periodic compute protection
│  │ • Action:    All current notes extracted         │  │
│  └──────────────────────────────────────────────────┘  │
```

---

## 4. UI/UX Modification SDLC & Sandbox Architecture

```
previews/
├── main_preview.dart                 # Preview sandbox runner: flutter run -t previews/main_preview.dart
├── mock_data.dart                    # Typed mock thoughts, audio durations, daily counters, clusters
├── gallery_shell.dart                # Interactive screen gallery & scenario switcher
└── screens/
    ├── capture_screen_preview.dart   # Screen 1: Capture (Daily #01, [▶ Audio], • Unread, Cleaned text)
    ├── synthesis_screen_preview.dart # Screen 2: Synthesis (Clubbed notes, #S-01, Session metrics, Ejection)
    ├── insights_screen_preview.dart  # Screen 3: Insights (Emotion heatmap, Topic treemap, Recurrent loops)
    ├── action_screen_preview.dart    # Screen 4: Action Engine (Commitments todo, Calendar time-blocking)
    ├── capture_hud_preview.dart      # Instant Audio Capture HUD (<5ms hardware trigger)
    ├── style_rewriter_preview.dart   # AI Style Context Prompt Bottom Sheet
    ├── note_ejection_preview.dart    # Disaggregate / Reassign Raw Note Modal
    ├── settings_preview.dart         # Settings & Diagnostics (Calendar Sync config, Inactivity TTL)
    └── permissions_modal_preview.dart# Dual Background Onboarding Sheet
```

---

## 5. Screen 1: Capture — Instant Voice Stream & Unfiltered Feed

### Screen Overview
The default landing screen. Displays all captured thoughts in reverse-chronological order. 
- **AI Processing Scope**: Strictly **Speech-to-Text (STT)** and **basic language cleanup** (grammar correction, filler word removal, punctuation) via local LLM.
- **Card State Color Accents (Processing Pipeline Transparency)**:
  - Cards do not carry folder tags (folders live under Synthesis), but indicate cognitive state via **background and border color coding**:
    - **Yellow (`stateEnqueuedBg` / Amber `#F59E0B`)**: Pending audio queue processing / STT transcription.
    - **Blue (`stateProcessedBg` / Electric Blue `#3B82F6`)**: Post-STT and language cleanup completed; raw thought ready for synthesis.
    - **Green (`stateSynthesizedBg` / Emerald `#10B981`)**: Synthesis completed (this raw thought has been clubbed into a synthesized session).
    - **Red (`stateFailedBg` / Rose `#EF4444`)**: Processing failed (with 1-tap retry button).
- **Compact Dual Dropdown Filter Bar**:
  - Located directly above the feed to preserve vertical space and maintain visual uniformity with the Synthesis screen's dropdown controls:
    - **Triage Filter Dropdown**: `[ 👁️ All Triage ▾ ]` (`All`, `Unread`, `Read`).
    - **Status Filter Dropdown**: `[ ⚡ All Statuses ▾ ]` (`All Statuses`, `Processing`, `Processed`, `Synthesized`, `Failed`).
- **Daily Sequence Numbering**: Every raw note receives a daily number (`#01`, `#02`, `#03`...). The counter **resets to `#01` every day** at midnight.
- **Permanent Numbering On Delete**: If a note is deleted, later notes **retain their assigned number** (e.g., deleting `#02` leaves `#01`, `#03`, `#04`). Gaps are intentional to preserve citation and voice audio permanence.
- **Card Heading Layout Contract**:
  - Exact element ordering: **`[# Number]`** $\longrightarrow$ **`[ ▶ Audio Playback ]`** $\longrightarrow$ **`[ • Unread Dot ]`** $\longrightarrow$ **`[ 🗑️ Delete Action ]`**.
  - Placing the playback button immediately after the sequence badge guarantees that note numbers and audio controls remain in **identical, uninterrupted horizontal alignment** across all cards, whether read or unread. When read, the unread dot is simply hidden without causing layout jitter or a "missing content" gap between the number and player.
- **Card Bottom Section**:
  - Formatted strictly as **Date then Time**: `DD/MM  HH:MM AM/PM` (e.g. `05/11  09:42 AM`).
  - Followed by action trigger: `[ ✎ Edit ]`. (Raw capture is strictly STT and grammatical cleanup; high-level AI Style Re-writing operates on the final synthesized note in the Synthesis screen).
- **Interactive Floating Capture Trigger**:
  - Prominent, high-contrast floating capsule hovering at the bottom center of the screen, elevated above the scrolling list.
  - Large mic icon (`20sp`), visual `"/"` slash separator, and explicit hint text:
    `[ 🎙️  /  Press Vol Up + Down to Capture ]`
  - **Clickable Soft Trigger**: Tapping this floating pill starts recording immediately (providing an in-app soft trigger alternative to physical volume buttons).
  - **Interactive Waveform & Loader**: When recording is initiated, the button dynamically transforms: the mic icon and text are replaced by a **live pulsating audio waveform / listening loader bar** inside the button itself, with elapsed timer (`00:04`). Tapping the button again stops recording, immediately dismisses the waveform, and enqueues the note as a Yellow pending card in the feed with clean, concise SnackBar feedback: `"Captured a new note [#0X]"` (free of internal implementation or debug filler text).
- **Text Modification Options**:
  - **Manual Edit**: Inline or bottom sheet text editor to correct any transcript details manually.

### Visual ASCII Wireframe

```
┌────────────────────────────────────────────────────────┐
│  Eudemonia                    [ ⚡ 1 pending ]  [ ⚙ ]  │ ◄── Header & Live Queue
├────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │  [ Capture (6) ]  Synthesis   Insights   Action  │  │ ◄── Stage Switcher (Capture Active)
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  FILTERS:                                              │
│  [ 👁️ All Triage ▾ ]    [ ⚡ All Statuses ▾ ]           │ ◄── Compact Dropdown Filters (replaces chip rows)
│                                                        │
│  TODAY — 05/11 (#01 - #06)                             │ ◄── Daily Grouping & Reset Counter
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │ ◄── 🟡 Yellow Card (Pending Processing)
│  │ [#06]  [ ▶ 00:05 ]  •                    [ 🗑️ ] │  │
│  │ ⏳ Transcribing audio and cleaning speech...     │  │
│  │ ──────────────────────────────────────────────── │  │
│  │ 05/11  10:15 AM                   [ Processing ] │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │ ◄── 🔵 Blue Card (STT + Language Cleaned)
│  │ [#04]  [ ▶ 00:08 ]  •                    [ 🗑️ ] │  │     (Awaiting session synthesis)
│  │ "Need to verify whether the accessibility key    │  │
│  │  debouncer works properly when device is locked" │  │
│  │ ──────────────────────────────────────────────── │  │
│  │ 05/11  09:42 AM                         [ ✎ Edit ]│ │ ◄── Date then Time: "DD/MM  HH:MM", Manual Edit
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │ ◄── 🟢 Green Card (Synthesized into #S-02)
│  │ [#01]  [ ▶ 00:04 ]                       [ 🗑️ ] │  │
│  │ "Idea about splitting raw & processed notes..."  │  │
│  │ ──────────────────────────────────────────────── │  │
│  │ 05/11  07:10 AM  • Synthesized in #S-02          │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │ ◄── 🔴 Red Card (Processing Failed)
│  │ [#02]  [ ▶ 00:02 ]                       [ 🗑️ ] │  │
│  │ ⚠️ No speech detected in audio recording         │  │
│  │ ──────────────────────────────────────────────── │  │
│  │ 05/11  07:40 AM                     [ ↻ Retry ]  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│     ┌────────────────────────────────────────────┐     │ ◄── FLOATING CLICKABLE TRIGGER (Sticky)
│     │   🎙️   /   Press Vol Up + Down to Capture   │     │     (Tap to start recording / or use Vol keys)
│     └────────────────────────────────────────────┘     │
│       (When Recording: [ ⏹  |||||||||||  00:04 ])      │ ◄── Morphing listening waveform loader inside button
└────────────────────────────────────────────────────────┘
```

### Component Contract & Sandbox
- **Sandbox File**: [`previews/screens/capture_screen_preview.dart`](file:///Users/harshmavani/Documents/Eudemonia/previews/screens/capture_screen_preview.dart)
- **Production Target**: `lib/features/capture/presentation/capture_screen.dart`
- **Key Parameters**:
  - `String activeTriageFilter`: Selected triage dropdown value (`all`, `unread`, `read`).
  - `String activeStatusFilter`: Selected status dropdown value (`all`, `processing`, `processed`, `synthesized`, `failed`).
  - `List<RawNoteItem> notes`: Ordered list of raw notes containing:
    - `String id`: Unique persistent ID.
    - `int dailySequenceNumber`: `#01`, `#02`, `#03` (calculated relative to capture date, immutable on deletion of sibling notes).
    - `DateTime timestamp`: Precise time of capture. Formatted at card footer as `intl.DateFormat('dd/MM  hh:mm a').format(timestamp)`.
    - `String audioFilePath`: Path to local PCM/WAV recording.
    - `Duration audioDuration`: Recording duration.
    - `String cleanedText`: STT transcript with grammar and filler cleanup.
    - `bool isUnread`: Toggles electric blue unread indicator dot (`unreadDot`).
  - Callbacks:
    - `onSelectTriageFilter(filter)`: Updates triage dropdown filter.
    - `onSelectStatusFilter(status)`: Updates status dropdown filter.
    - `onPlayAudio(noteId)`: Toggles playback of raw voice.
    - `onDeleteNote(noteId)`: Removes note permanently (without renumbering later notes).
    - `onManualEdit(noteId, newText)`: Updates text manually.
    - `onToggleReadStatus(noteId)`: Clears unread indicator dot.

---

## 6. Screen 2: Synthesis — Clustered & Synthesized Sessions

### Screen Overview
The second screen in the application. Thoughts captured in close proximity or sharing strong semantic similarity are automatically clustered and synthesized into structured notes.
- **Compact Dual Dropdown Filter Bar**:
  - Located directly in the sub-header row, mirroring Capture's ergonomics:
    - **Triage Filter Dropdown**: `[ 👁️ All Triage ▾ ]` (`All`, `Unread`, `Read`). Filters new vs reviewed synthesized sessions.
    - **Folder Filter Dropdown**: `[ 📁 All Folders ▾ ]` (`All Folders`, `Work`, `Ideas`, `Todos`, `Journal`, `Uncategorized`).
  - Strict **Single-Folder Discipline**: Synthesized notes are strictly assigned to one of the predefined folders. Unconstrained auto-tagging or arbitrary tag generation is prohibited to prevent tag explosion and naming chaos.
- **Card State Color Accents (Pipeline Maturation Transparency)**:
  - Synthesis cluster cards reflect lifecycle state via border and background color accents:
    - **Yellow (`stateEnqueuedBg` / Amber `#F59E0B`)**: Currently re-synthesizing / regenerating (e.g. after style change or raw note ejection).
    - **Blue (`stateProcessedBg` / Electric Blue `#3B82F6`)**: Synthesized narrative ready; action extraction pass queued / pending.
    - **Green (`stateSynthesizedBg` / Emerald `#10B981`)**: Action extraction pass completed (promoted to Action stage).
      > [!IMPORTANT]
      > **The Zero-Action Rule**: Green represents **Action Extraction Pass Completed**, not "has tasks". If a reflective or journal entry yields 0 action items, it still turns Green once the LLM extraction pass concludes, confirming the thought is fully processed and closed.
- **Unread Indicator Dot (`• Unread`)**:
  - Each cluster card hosts an electric blue unread dot when newly synthesized. Tapping or inspecting the card marks it as read, decrementing the `Synthesis (X)` header count.
- **Pending Batch Synthesis Banner & Manual Override**:
  - When unprocessed Blue capture notes exist in the queue, a quiet banner appears above the cluster list:
    `[ 🧩 3 raw thoughts ready to cluster • [ ⚡ Synthesize Now ] ]`
  - Allows users to bypass the automatic batch threshold ($X$ capture messages or $Y$ minutes of quiet) to cluster thoughts on demand immediately.
- **Clustering Mechanics**:
  - **Session Timestamp Proximity**: Captures occurring within a contiguous activity window (e.g., 20–45 minute morning walk, meeting, or commute).
  - **Semantic Vector Similarity**: On-device embedding / LLM similarity clustering disjointed fragments on the same topic.
- **Clubbed Note Attributes**:
  - **Sequential Synthesis Identifier**: e.g., `#S-01`, `#S-02` (Synthesis Session #).
  - **Card Folder Reassignment Dropdown**: Displays assigned folder badge (e.g. `[ 💡 Ideas ▾ ]`, `[ 💼 Work ▾ ]`). Tapping opens a 1-tap quick-picker to reassign the note among the defined folders.
  - **AI Style Re-Writer (`[ ✨ Style ▾ ]`)**:
    - Embedded on each synthesized cluster card, as this is where final structured text is consolidated.
    - Tapping opens the Style Re-Writer modal offering preset context prompts applied on-device.
    - **Active Style Checkmark**: The currently active style preset is highlighted with an explicit checkmark (`Icons.check`).
    - **Yellow Re-Processing State**: When a user selects a different style, that synthesized note is flagged for re-generation and its card color transitions to **Yellow (`stateEnqueuedBg`)** while the local LLM runs inference.
  - **Explicit Synthesis Note Merging (`[ 🔗 Merge ]`)**:
    - Embedded alongside Style and Edit actions on each cluster card.
    - Tapping opens the `NoteMergeModal` listing other synthesized sessions (`#S-01`, `#S-02`, etc.) with sequence labels and content previews.
    - Selecting a target session transfers all origin raw notes into the target cluster, removes the source cluster, and transitions the target cluster to **Yellow (`stateEnqueuedBg` / `isReprocessing = true`)** for consolidated re-synthesis with clean feedback: `"Merged #S-02 into #S-01"`.
  - **Consolidated Synthesis**: A cohesive narrative written by the LLM merging all fragments.
  - **Active Session Horizon & 2D Domain Clustering Architecture**:
    - **2D Routing (`Time Window ∩ Target Folder`)**: Captures within the active session window are strictly segregated by target folder. A Work thought and a Journal thought never merge together into the same cluster.
    - **Sliding Inactivity Window ($Y=45$m)**: The session remains open and receptive to incoming notes until 45 minutes of quiet elapse.
    - **Hard Session Ceiling ($T_{max}=2$ hours)**: Prevents runaway infinite clusters across full-day captures by automatically capping the cluster at 2 hours from its first note.
    - **Delta Synthesis**: Integrating new notes into an active cluster passes the existing summary + delta thoughts (<300 tokens), preventing full-context re-computation.
    - **Delta Action Extraction & Task Immutability**: Appending new notes triggers an additive action extraction pass. Existing completed and pending action items in Isar are immutable and never duplicated or reset.
  - **Footer Metadata**:
    - Creation date and time span formatted as date then times (e.g., `05/11  07:10 AM - 07:45 AM`).
    - Session duration (e.g., `⏱️ 35m session`).
    - **Raw Notes Count Pill** (e.g. `[ 🧩 3 Raw Notes ▾ ]`): **Clickable and expandable** to inspect included raw notes.
- **Raw Note Ejection / Reorganization**:
  - **Single Note Guard**: If a synthesized cluster has only 1 origin note (`originNotes.length <= 1`), the `[ ⤢ Move Out ]` action is **hidden / disabled**. Ejecting the only note would leave an orphaned cluster.
  - When a cluster has 2 or more origin notes, each origin note displays `[ ⤢ Move Out ]`.
  - Tapping `[ ⤢ Move Out ]` opens the Reassign Raw Note sheet with two clean options (free of repetitive debug/instructional filler text):
    1. **Move to another clubbed note**: Opens an interactive target picker listing existing clubbed sessions (`#S-01`, `#S-02`, etc.) with their sequence numbers and summaries.
       - *State Transition*: When confirmed, the raw note is detached from the source cluster and appended to the target cluster. Both source and target clubbed notes turn Yellow (`stateEnqueuedBg` / pending re-processing) for LLM re-synthesis.
    2. **Make it an independent note**: Detaches the raw note into its own standalone synthesized session.
       - *State Transition*: The source clubbed note turns Yellow (`stateEnqueuedBg`) to trigger re-synthesis, and a new independent synthesized session is created.

### Visual ASCII Wireframe

```
┌────────────────────────────────────────────────────────┐
│  Eudemonia               [ ⚡ 3 in Pipeline ▾ ]  [ ⚙ ]  │
├────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │   Capture (2)  [ Synthesis (1) ] Insights Action │  │ ◄── Stage Switcher (Synthesis Active)
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  FILTERS:                                              │
│  [ 👁️ All Triage ▾ ]    [ 📁 All Folders ▾ ]           │ ◄── Compact Dual Dropdowns (Triage + Folder)
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │ ◄── Pending Batch Banner with Override
│  │ 🧩 2 raw thoughts ready to cluster  [Synthesize] │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │ ◄── 🟢 Green Card (Fully processed into Action)
│  │ [#S-02]  •  [ 💡 Ideas ▾ ] [ ✨ Style ▾] [ 🔗 Merge ] [ ✎ Edit ] │ ◄── Sequence, Unread dot, Folder, Style, Merge, Edit
│  │                                                  │  │
│  │ "Consolidated architectural roadmap for local    │  │ ◄── LLM Synthesis of Morning Walk Captures
│  │  speech clustering. Decided to separate raw      │  │
│  │  inbox from synthesized notes to prevent clutter.│  │
│  │  Will implement SQLite vector indices."          │  │
│  │                                                  │  │
│  │ ──────────────────────────────────────────────── │  │
│  │ 📅 05/11  07:10 AM - 07:45 AM • ⏱️ 35m session   │  │ ◄── Date then Time Span & Duration
│  │                                                  │  │
│  │ [ 🧩 3 Raw Notes Included (Tap to Expand) ▲ ]    │  │ ◄── Expandable Origin Pill (Expanded)
│  │ ┌──────────────────────────────────────────────┐ │  │
│  │ │ • [#01] "Idea about splitting raw & processed"│ │  │ ◄── Origin Raw Note #01
│  │ │   [ ▶ 00:04 ]            [ ⤢ Move Out ]      │ │  │     Audio + Move Out Trigger
│  │ │ • [#02] "Need local embeddings for walk notes"│ │  │
│  │ │   [ ▶ 00:08 ]            [ ⤢ Move Out ]      │ │  │
│  │ │ • [#04] "Performance should stay under 50ms"  │ │  │
│  │ │   [ ▶ 00:06 ]            [ ⤢ Move Out ]      │ │  │
│  │ └──────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │ ◄── 🔵 Blue Card (Awaiting Action Extraction)
│  │ [#S-01]     [ 💼 Work ▾ ]  [ ✨ Style ▾] [ 🔗 Merge ] [ ✎ Edit ] │ ◄── Read, Awaiting action pass
│  │ "Prepare quarterly deliverables before 3 PM sync"│  │
│  │ ──────────────────────────────────────────────── │  │
│  │ 📅 04/11  04:15 PM - 04:27 PM • ⏱️ 12m session   │  │
│  │ [ 🧩 1 Raw Note Included (Tap to Expand) ▼ ]     │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

### Synthesis Note Merge Modal Wireframe
When tapping `[ 🔗 Merge ]` on any synthesis session card:

```
┌────────────────────────────────────────────────────────┐
│               ••••  DRAG INDICATOR                     │
│                                                        │
│  🔗 Merge Session [#S-02]                              │
│  Select target session to consolidate raw notes into:  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [#S-01] 💼 Work                                  │  │ ◄── Target Session Option
│  │ "Prepare quarterly deliverables before 3 PM sync"│  │
│  │ ⏱️ 12m session • 1 raw note                       │  │
│  │ [ Select to Merge ➔ ]                            │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  [ Cancel ]                                            │
└────────────────────────────────────────────────────────┘
```

### Raw Note Ejection Modal Wireframe
When tapping `[ ⤢ Move Out ]` on an origin note inside the expanded drawer:

```
┌────────────────────────────────────────────────────────┐
│               ••••  DRAG INDICATOR                     │
│                                                        │
│  Reassign Raw Note [#02]                               │
│  "Need local embeddings for walk notes"                │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 📂 Move to Another Clubbed Note                  │  │ ◄── Option 1: Attach to another session
│  │    Choose target clubbed note:                   │  │
│  │    ○ [#S-01] Work ("Prepare quarterly deliverables")│
│  │    ○ [#S-03] Journal ("Morning reflection...")   │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 📄 Make It An Independent Note                   │  │ ◄── Option 2: Promote to standalone note
│  │    Detach and generate a separate synthesized note│  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  [ Cancel ]                                            │
└────────────────────────────────────────────────────────┘
```

### AI Style Re-Writer Preset Options
When the user taps `[ ✨ Style ▾ ]` on any synthesis card, a bottom modal appears with preset context prompts applied on-device. The currently selected preset displays a checkmark (`Icons.check`). Selecting a new preset turns the card Yellow (`stateEnqueuedBg` / pending re-processing):

| Preset Name | Icon | Prompt Injected to On-Device LLM | Output Format |
| :--- | :--- | :--- | :--- |
| **Concise & Direct** | ⚡ | *"Distill this thought into a punchy, 1-2 sentence core insight without fluff."* | 1-2 sentences |
| **Bullet Points** | 📋 | *"Convert this thought into a structured, clear bulleted list highlighting key ideas."* | Markdown bullets |
| **Professional** | 💼 | *"Rewrite this thought in polished, professional business language suitable for work."* | Formal prose |
| **Journal / Reflective** | 🌿 | *"Rewrite with introspective, thoughtful prose preserving personal sentiment and nuances."* | Reflective narrative |
| **Actionable / Next Steps**| 🎯 | *"Extract the concrete actionable intent and format as immediate clear next steps."* | Action steps |
| **Casual / Conversational**| 💬 | *"Rewrite as a friendly, natural speaking-style personal note."* | Conversational |

### Component Contract & Sandbox
- **Sandbox File**: [`previews/screens/synthesis_screen_preview.dart`](file:///Users/harshmavani/Documents/Eudemonia/previews/screens/synthesis_screen_preview.dart)
- **Production Target**: `lib/features/synthesis/presentation/synthesis_screen.dart`
- **Key Parameters**:
  - `String activeFolderFilter`: Selected filter from dropdown (`all`, `work`, `ideas`, `todos`, `journal`, `uncategorized`).
  - `List<String> availableFolders`: Defined folders list (`['All Folders', 'Work', 'Ideas', 'Todos', 'Journal']`).
  - `List<SynthesisClusterItem> clusters`:
    - `String clusterId`: Unique cluster ID.
    - `String clusterSequenceNumber`: e.g. `#S-01`, `#S-02`.
    - `String folder`: Predefined folder (`Work`, `Ideas`, `Todos`, `Journal`, `Uncategorized`).
    - `String appliedStyleId`: Currently selected style preset ID (default: `'concise'`).
    - `bool isReprocessing`: Toggles Yellow pending state accent when style is changed or cluster is modified.
    - `String synthesizedContent`: Unified synthesis text.
    - `DateTime sessionStart`, `DateTime sessionEnd`: Session boundary timestamps.
    - `Duration sessionDuration`: Elapsed session length.
    - `List<RawNoteItem> originNotes`: Complete list of origin raw notes.
    - `bool isExpanded`: Controls expansion of included raw notes drawer.
  - Callbacks:
    - `onSelectFolderFilter(folder)`: Filters synthesized sessions by folder via dropdown.
    - `onReassignFolder(clusterId, newFolder)`: Updates folder category via 1-tap card dropdown.
    - `onApplyStyleRewrite(clusterId, presetId)`: Regenerates cluster text in chosen style and sets `isReprocessing = true`.
    - `onToggleExpand(clusterId)`: Expands/collapses included raw notes list.
    - `onPlayRawAudio(rawNoteId)`: Plays individual audio snippet.
    - `onMoveRawNoteToCluster(rawNoteId, targetClusterId)`: Transfers raw note to another session.
    - `onMakeRawNoteIndependent(rawNoteId)`: Promotes raw note to a standalone synthesized note.
    - `onEditSynthesis(clusterId, newText)`: Manual edit of the consolidated summary.

---

## 7. Screen 3: Insights — Higher-Order Cognitive Dashboards

### Screen Overview
The macro-intelligence hub of Eudemonia. Organizes synthesized thoughts across time, emotional valence, topic density, and recurrent behavioral patterns.
- **View Selector (Segmented Chips)**:
  1. **Thematic Synthesis**: Clustered cards grouped by overarching projects or life domains.
  2. **Emotional Climate Heatmap**: Weekly/Monthly emotional valence curve (-1.0 to +1.0) and cognitive energy derived locally from reflective thoughts.
  3. **Topic & Work Heatmap**: Visual density matrix displaying cognitive load and time invested across work vs. personal topics.
  4. **Recurrent Patterns & Habits**: Surfaces recurring blockers, recurring chores, and repetitive thought loops detected by LLM over time.

### Visual ASCII Wireframe

```
┌────────────────────────────────────────────────────────┐
│  Eudemonia                                      [ ⚙ ]  │
├────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │   Capture (4)  Synthesis  [ Insights ]   Action  │  │ ◄── Stage Switcher (Insights Active)
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  VIEW SELECTOR                                         │
│  ┌──────────────┐ ┌──────────────┐ ┌────────────────┐  │
│  │ • Emotion Map│ │ Topic Density│ │ Recurrent Loop │  │ ◄── Sub-View Switcher
│  └──────────────┘ └──────────────┘ └────────────────┘  │
│                                                        │
│  WEEKLY EMOTIONAL VALENCE & CLIMATE                    │
│  Dominant State: Focused & Constructive (+0.6 Valence) │
│                                                        │
│  Mon   Tue   Wed   Thu   Fri   Sat   Sun               │
│  [🟢]  [🟢]  [🟡]  [🟢]  [🟣]  [🟢]  [🟢]              │ ◄── Daily Valence Chips:
│  +0.7  +0.5   0.0  +0.8  -0.4  +0.6  +0.9              │     🟢 Constructive / Flow
│                                                        │     🟡 Pondering / Neutral
│  COGNITIVE ENERGY BREAKDOWN                            │     🟣 Depleted / Blocked
│  ┌──────────────────────────────────────────────────┐  │
│  │ 💡 58% Creative Architecture (High Energy)       │  │
│  │ 💼 28% Logistics & Work Coordination             │  │
│  │ 🌿 14% Rest & Somatic Reflection                 │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  RECURRENT THOUGHT PATTERNS DETECTED                   │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 🔁 "Memory optimization on low-end Android"      │  │ ◄── Cross-session recurrent pattern
│  │    Mentioned 4 times across 3 different sessions │  │
│  │    [ View Linked Notes (4) ➔ ]                   │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  [ 🧘 2-Minute Coherence Breath (Haptic Reset) ]       │ ◄── Somatic Reset Button
└────────────────────────────────────────────────────────┘
```

### Component Contract & Sandbox
- **Sandbox File**: [`previews/screens/insights_screen_preview.dart`](file:///Users/harshmavani/Documents/Eudemonia/previews/screens/insights_screen_preview.dart)
- **Production Target**: `lib/features/insights/presentation/insights_screen.dart`
- **Key Parameters**:
  - `String activeSubView`: `emotionMap`, `topicDensity`, `recurrentLoops`.
  - `List<DayValence> weeklyValence`: Daily average valence scores (-1.0 to +1.0) and dominant cognitive states.
  - `Map<String, double> topicDistribution`: Percentage distribution across life/work domains.
  - `List<RecurrentPatternItem> recurrentPatterns`: Recurring themes, frequency counts, and linked note IDs.
  - Callbacks: `onSelectSubView(view)`, `onSelectDay(day)`, `onStartCoherenceBreath()`, `onInspectPattern(patternId)`.

---

## 8. Screen 4: Action — Commitments Engine & Calendar Time-Blocking

### Screen Overview
Converts passive voice reflections into intentional momentum. Surfaces actionable commitments extracted automatically by the on-device LLM from synthesized notes.
- **Core Capabilities**:
  1. **Commitments Todo List**: Checkbox list of commitments categorized by urgency (High, Normal, Low) with explicit time anchors and source note links.
  2. **Calendar Time-Block Preview**: Visual timeline showing suggested schedule blocks to execute captured tasks.
  3. **Calendar Synchronization**:
     - System Calendar / Google Calendar integration setup is configured in **Settings**.
     - Action Screen displays current sync status (e.g. `Synced with Google Calendar (work@gmail.com)` or `Local Only`).
     - Includes a 1-tap `[ 📅 Push to Calendar ]` action to export time blocks directly to the device calendar.

### Visual ASCII Wireframe

```
┌────────────────────────────────────────────────────────┐
│  Eudemonia                    [ 📅 Synced ]     [ ⚙ ]  │
├────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │   Capture (4)  Synthesis   Insights   [ Action ] │  │ ◄── Stage Switcher (Action Active)
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  CALENDAR INTEGRATION STATUS                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 📅 Device Calendar: Connected (Personal)         │  │ ◄── Calendar Sync Status Card
│  │    Next sync: Auto on task completion [Settings] │  │     (Configured in Settings)
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ACTION COMMITMENTS (3 PENDING)                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [ ] Verify accessibility debouncer on locked phone│  │ ◄── Extracted Action Item
│  │     📅 05/11  02:00 PM  •  ⚡ High Urgency        │  │     Date/Time anchor & urgency
│  │     Source: Synthesis [#S-02] App Ideas          │  │     Direct link to origin session
│  │     [ 📅 Schedule Time Block ]                   │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [ ] Buy replacement guitar strings (.010 gauge)  │  │
│  │     📅 06/11  10:00 AM  •  Normal Urgency        │  │
│  │     Source: Synthesis [#S-01] Music Session      │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  SCHEDULE TIME-BLOCKS (TODAY)                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 14:00 - 15:00  [ App Ideas: Accessibility Test ] │  │ ◄── Proposed Time Block
│  │ [ Push 1 Block to Calendar ➔ ]                   │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  COMPLETED TODAY (1)                                   │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [✓] Review PR for background keep-alive service   │  │ ◄── Strikethrough Completed Item
│  │     Finished at 05/11  08:30 AM                  │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

### Component Contract & Sandbox
- **Sandbox File**: [`previews/screens/action_screen_preview.dart`](file:///Users/harshmavani/Documents/Eudemonia/previews/screens/action_screen_preview.dart)
- **Production Target**: `lib/features/action/presentation/action_screen.dart`
- **Key Parameters**:
  - `List<ActionItem> pendingActions`: List of extracted commitments with description, time anchor, urgency level, and origin cluster ID.
  - `List<ActionItem> completedActions`: List of completed tasks with completion timestamps.
  - `List<TimeBlockItem> suggestedTimeBlocks`: Generated calendar blocks with start/end times.
  - `bool isCalendarSyncEnabled`: True if calendar provider is connected in Settings.
  - `String connectedCalendarAccount`: e.g. "Google Calendar (work@gmail.com)".
  - Callbacks:
    - `onToggleAction(actionId)`: Checks/unchecks action item.
    - `onEditAction(actionId, newDesc)`: Edits description or urgency.
    - `onScheduleBlock(actionId, timeSlot)`: Creates a time-block.
    - `onExportBlocksToCalendar()`: Pushes blocks to native device calendar via Android Intent/API.
    - `onOpenCalendarSettings()`: Jumps to Calendar configuration section in Settings.

---

## 9. Screen 5: Instant Audio Capture HUD & Waveform Sheet

### Screen Overview
Triggered instantaneously (<5ms) upon dual-volume button hardware press or lock screen capture action. Displays a dark translucent glassmorphic HUD with a pulsating emerald recording indicator, elapsed duration timer, and dynamic soundwave visualizer. Dismisses immediately on button release, enqueuing audio into the background worker.

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
  - `List<double> soundwaveAmplitudes`: Normalized audio amplitude levels (0.0 to 1.0).
  - `bool isLocked`: Indicates whether capture occurred from device lock screen.
  - Callbacks: `onCancel`, `onStopAndSave`.

---

## 10. Screen 6: Settings, Calendar Sync & Diagnostics Console

### Screen Overview
Controls background resilience, physical hardware button listener status, synthesis batching thresholds, calendar synchronization setup, audio retention policies, model lifecycle memory telemetry, and real-time rotating diagnostic logs.

### Visual ASCII Wireframe

```
┌────────────────────────────────────────────────────────┐
│  [ ‹ Back ]       Settings & Diagnostics               │
├────────────────────────────────────────────────────────┤
│  HARDWARE & BACKGROUND PERMISSIONS                     │
│  Accessibility Interceptor:        [ ENABLED (Green) ] │ ◄── Hardware button listener
│  Battery Optimization Exemption:   [ ENABLED (Green) ] │ ◄── Prevent OS Doze
│  Keep Alive Foreground Service:    [ Toggle ON ]       │
│                                                        │
│  AUTOMATIC SYNTHESIS TRIGGER & BATCHING                │ ◄── Mobile Compute & Battery Safeguards
│  Trigger after X captures:         [ 3 notes ▾ ]       │ ◄── Accumulation threshold (1–10)
│  Trigger after Y minutes of quiet: [ 15 mins ▾ ]       │ ◄── Session inactivity window (5–60m)
│  Unprocessed Thoughts in Buffer:   2 notes ready       │
│  [ ⚡ Synthesize Buffer Now ]                           │ ◄── Manual batch override
│                                                        │
│  FOLDER MANAGEMENT & SEMANTIC MANIFESTOS               │ ◄── Project-level contextual categorization
│  "Folder descriptions guide on-device AI classification│
│   to distinguish between different apps and projects." │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 💼 Work (4 notes)                                │  │
│  │ "Flutter app development, technical architecture"│  │
│  │ 🏷️ flutter, riverpod, isar, debouncer • [ Edit ] │  │
│  ├──────────────────────────────────────────────────┤  │
│  │ 💡 Ideas (2 notes)                               │  │
│  │ "Creative concepts and startup brainstorms"      │  │
│  │ 🏷️ voice-first, ai-hud, mobile • [ Edit ]        │  │
│  └──────────────────────────────────────────────────┘  │
│  [ + Add Custom Folder ]                               │ ◄── Create new custom folder
│                                                        │
│  CALENDAR SYNCHRONIZATION                              │
│  Sync Action Items with Calendar:  [ Toggle ON ]       │ ◄── Calendar Sync Toggle
│  Active Calendar Provider:         [ Google Calendar ▾]│ ◄── Provider Dropdown
│  Target Calendar:                  [ Personal (Default)│
│  Auto-Sync on Task Extraction:     [ Toggle ON ]       │
│                                                        │
│  AUDIO CAPTURE STORAGE                                 │
│  Keep Raw WAV Audio Files:         [ Toggle ON ]       │
│                                                        │
│  DEVICE THERMAL & INFERENCE GATING                     │
│  Thermal Headroom: 84% (Nominal)   Status: NORMAL      │
│                                                        │
│  ON-DEVICE AI MEMORY TELEMETRY                         │
│  Model State: READY  •  RAM: 1.58 GB                   │ ◄── Live RAM Telemetry Gauge
│  Inactivity Eviction Countdown: 02:44 (to <60MB)       │
│  [ Evict Models Now (<60 MB) ]                         │ ◄── Manual memory reclamation
│                                                        │
│  DIAGNOSTIC LOGGING (2MB ROTATING)                     │
│  [ 👁️ View Live Logs ]  [ 📋 Copy Dump ]  [ 🗑️ Clear ] │
└────────────────────────────────────────────────────────┘
```

### Component Contract & Sandbox
- **Sandbox File**: [`previews/screens/settings_preview.dart`](file:///Users/harshmavani/Documents/Eudemonia/previews/screens/settings_preview.dart)
- **Production Target**: [`lib/features/settings/settings_screen.dart`](file:///Users/harshmavani/Documents/Eudemonia/lib/features/settings/settings_screen.dart)
- **Key Parameters**:
  - `bool isAccessibilityGranted`: Controls Accessibility status badge.
  - `bool isBatteryExemptGranted`: Controls Battery Exemption status badge.
  - `int synthesisNoteThreshold`: Accumulated note count trigger (default: 3).
  - `int synthesisInactivityMinutes`: Inactivity timeout trigger (default: 15).
  - `int unprocessedCaptureCount`: Number of capture notes ready for synthesis.
  - `bool isCalendarSyncEnabled`: Controls calendar sync master toggle.
  - `String selectedCalendarProvider`: e.g. "Google Calendar", "Device Local Calendar".
  - `String modelLifecycleState`: `Unloaded`, `Loading`, or `Ready`.
  - `String activeRamFootprint`: e.g. `< 60 MB` (idle) or `~1.58 GB` (active).
  - Callbacks: `onToggleCalendarSync`, `onSelectCalendarProvider`, `onUpdateSynthesisThresholds`, `onTriggerSynthesisNow`, `onEvictModels`, `onViewLogs`.

---

## 11. Screen 7: Background Permissions Dual-Onboarding Sheet

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
- **Key Parameters**:
  - `bool isAccessibilityGranted`: Visual checkmark for Step 1.
  - `bool isBatteryExemptGranted`: Visual checkmark for Step 2.
  - Callbacks: `onRequestAccessibility`, `onRequestBatteryExempt`, `onDismiss`.

---

## 12. Screen 8: Persistent Lock Screen Notification Capture Controller

### Screen Overview
Enables instant zero-friction thought recording directly from the lock screen, Always-On Display (AOD), or status bar shade without unlocking the device. Managed seamlessly by `EudemoniaForegroundService`.

### Visual ASCII Wireframe

```
┌────────────────────────────────────────────────────────┐
│  COLLAPSED NOTIFICATION (Lock Screen / Shade)          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 🎙️ Eudemonia • Background Service Ready          │  │
│  │ Double-volume keys active • Standby              │  │
│  │                                                  │  │
│  │            [ 🎙️ Record Thought ]                 │  │ ◄── 1-Tap Trigger (Zero Unlock)
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ACTIVE RECORDING NOTIFICATION                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 🔴 Recording Thought...                00:07.4   │  │ ◄── Live Timer
│  │ Speak freely • Tap to finish                     │  │
│  │                                                  │  │
│  │            [ ⏹ Stop & Save ]                     │  │ ◄── Immediate Handoff to Queue
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

### Component Contract & Sandbox
- **Sandbox File**: [`previews/screens/notification_preview.dart`](file:///Users/harshmavani/Documents/Eudemonia/previews/screens/notification_preview.dart)
- **Production Target**: `android/app/src/main/kotlin/com/eudemonia/eudemonia/EudemoniaForegroundService.kt`
- **Key Parameters**:
  - `bool isRecording`: Toggles between standby capture button and active timer/stop button.
  - `String elapsedDuration`: Active recording timer string (`00:07.4`).
  - Actions: `ACTION_START_CAPTURE`, `ACTION_STOP_CAPTURE`.
