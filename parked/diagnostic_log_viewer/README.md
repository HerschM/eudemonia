# Parked: diagnostic log viewer (Settings)

## What it is

The "DIAGNOSTIC LOGGING (2MB ROTATING)" section that used to sit in Settings:

- **View System Logs** opens a sheet with the last 80 log lines.
- **Copy Diagnostic Log Dump** copies the whole log to the clipboard.
- **Clear Logs** truncates the log file.

`diagnostic_logging_section.dart` is the section as one widget, `DiagnosticLoggingSection`, moved
over unchanged from `lib/features/settings/settings_screen.dart` (keys, wording and behaviour as
they were). `diagnostic_logging_section_test.dart` holds its widget tests, including the
assertions the Settings screen test used to make about it.

## Why it is parked

Removed from the first release on the user's decision of 2026-11-26. `AppLogger`
(`lib/core/logger/app_logger.dart`) is untouched and the app still writes its 2 MB rotating log
file; only the way to read, copy and clear it from inside the app is gone.

This folder is outside `lib/` and `test/`, and `analysis_options.yaml` excludes `parked/**`, so
none of it is compiled, analysed or run.

## Last commit it worked in

`073c1d8`. At that commit the section was inline in `lib/features/settings/settings_screen.dart`
(the block commented `Section 7: Diagnostic Logging`).

## How to bring it back

1. Copy `diagnostic_logging_section.dart` to `lib/features/settings/presentation/`.
2. In `lib/features/settings/settings_screen.dart`, add the import
   `presentation/diagnostic_logging_section.dart` and put `DiagnosticLoggingSection()` in the
   `ListView`, with a `SizedBox(height: 20)` above it. Place it just above `PermissionsSection`
   (or wherever the product wants it; it was between the memory section and About before).
3. Copy `diagnostic_logging_section_test.dart` to `test/features/settings/` and add a check to
   the section-order test in `production_settings_screen_test.dart`.
4. Run `~/flutter/bin/dart analyze` and `~/flutter/bin/flutter test test/features/settings`.
   The section depends only on `appLoggerProvider`, `SettingsSectionHeader` (in
   `presentation/settings_card.dart`) and `AppColors`.
