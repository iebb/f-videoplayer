## 0.4.0

- Extracted Android, iOS, and macOS system Picture-in-Picture sessions from
  Mithka into a reusable Flutter plugin.
- Preserves position, play state, speed, mute, and fractional volume across
  handoff and restoration.
- Supports Swift Package Manager and CocoaPods on Apple platforms.
- Requires Flutter 3.44 and Dart 3.12 and uses Android's built-in Kotlin
support instead of applying the legacy Kotlin Gradle plugin.
