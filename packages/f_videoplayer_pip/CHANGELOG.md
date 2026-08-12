## 0.4.1

- Kept Android PiP session identity alive while an active stop waits for the
  operating-system exit callback, so Dart receives exactly one final stop and
  later sessions can start normally.
- Added native lifecycle-state regression tests to the Android CI lane.

## 0.4.0

- Extracted Android, iOS, and macOS system Picture-in-Picture sessions from
  Mithka into a reusable Flutter plugin.
- Preserves position, play state, speed, mute, and fractional volume across
  handoff and restoration.
- Supports Swift Package Manager and CocoaPods on Apple platforms.
- Requires Flutter 3.44 and Dart 3.12 and uses Android's built-in Kotlin
  support instead of applying the legacy Kotlin Gradle plugin.
