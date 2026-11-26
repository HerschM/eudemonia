# Parked: dual volume-button capture trigger

The Accessibility Service trigger (press Volume Up + Volume Down together to start or
stop a capture) is deferred until after the first public release. Shipping it needs a
Play Accessibility declaration and review, plus testing across phones, which would delay
the release. Until then capture starts from the notification, the home-screen widget and
the in-app button.

This folder is not a Gradle source set, so nothing here is compiled, tested or packaged.
The files are the last working version (commit `63aaec4`):

- `kotlin/`: `ButtonInterceptorService`, `VolumeButtonCoordinator`, `RecordingStateTracker`,
  `TriggerDebouncer`
- `test/`: their JUnit tests
- `res/xml/accessibility_service_config.xml`
- `AndroidManifest.snippet.xml`: the removed `<service>` entry
- `strings.snippet.xml`: the removed accessibility description string

## Reviving it

1. Move `kotlin/*` back to `app/src/main/kotlin/com/eudemonia/eudemonia/`, `test/*` to
   `app/src/test/kotlin/com/eudemonia/eudemonia/` and `res/xml/` to `app/src/main/res/xml/`.
2. Restore the manifest snippet inside `<application>` and the string in
   `res/values/strings.xml`.
3. Change the interceptor's trigger: instead of the old `HARDWARE_TRIGGER` broadcast, start
   `EudemoniaForegroundService` with `ForegroundServiceCoordinator.ACTION_START_CAPTURE` or
   `ACTION_STOP_CAPTURE`. The interceptor runs in its own `:interceptor` process and cannot
   read `CaptureCore` state directly, so it needs that state sent to it or a toggle action
   on the service. Recording, haptics and the
   notification now live in the native capture core, so the interceptor's own haptic and
   `RecordingStateTracker` broadcast are no longer needed.
