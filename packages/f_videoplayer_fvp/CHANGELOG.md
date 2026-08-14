## 0.5.1

- Coordinated the adapter with the core player's cross-platform built-in
  surface-control interaction fix.

## 0.5.0

- Coordinated the adapter dependency and source-only FVP override with the
  standalone player's additive host-integration release.

## 0.4.2

- Made the FVP Apple Swift package a static product and removed redundant
  explicit Flutter framework linker settings; Flutter's generated
  `FlutterFramework` product now supplies engine symbols exactly once on both
  iOS and macOS.
- Validated the `0.37.3+fvideo.3` FVP fork and added a packaging regression
  check for the linker contract.

## 0.4.1

- Published the standalone adapter against the matching `f_videoplayer`
  release tag and the integrity-pinned FVP fork.

## 0.1.0

- Added explicit, one-time FVP backend registration for every Flutter engine.
- Added typed platform, latency, decoder, size, and advanced libmdk options.
- Added a reusable macOS packaging helper and host integration contract that
  remove MDK's Homebrew and local FFmpeg search paths before final app signing.
- Kept FVP optional so the core player does not force native FVP binaries into
  applications that use only official `video_player` implementations.
- Documented per-engine/process-wide initialization rules and the repository's
  validated `0.37.3+fvideo.1` Apple Swift Package Manager override.
