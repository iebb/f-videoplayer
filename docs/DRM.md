# DRM architecture and roadmap

DRM is possible, but secure playback is a backend capability rather than a UI
feature. The shared player can keep the same chrome, playlists, fullscreen,
volume, captions, and presentation APIs while selecting a protected native
surface for encrypted sources.

v0.4.1 does not claim DRM playback support.

## Platform plan

| Platform | Primary system | Planned secure backend |
| --- | --- | --- |
| Android / Android TV | Widevine; ClearKey for tests; PlayReady on supported TV devices | Media3 ExoPlayer |
| iOS / macOS | FairPlay Streaming | AVFoundation and `AVContentKeySession` |
| Web | Browser-dependent Widevine, PlayReady, FairPlay, or ClearKey | EME-backed web adapter, initially Shaka Player |
| Windows | PlayReady natively; Widevine through a licensed browser/CDM path | Windows Media Protection plus an optional web-backed adapter |
| Linux | Widevine only through a licensed browser/CDM distribution | Browser-backed mode; no native claim initially |

Widevine is not a single portable library that can be redistributed inside an
open Flutter plugin. Production license services, Apple FairPlay credentials,
PlayReady client rights, CDMs, and proprietary SDKs remain outside this
repository and outside its BSD license.

## Proposed source contract

```dart
FVideoSource.network(
  manifestUri,
  drm: FVideoDrmSet([
    FWidevineDrm(licenseUri: widevineLicenseUri),
    FFairPlayDrm(
      certificateUri: fairPlayCertificateUri,
      licenseUri: fairPlayLicenseUri,
    ),
    FPlayReadyDrm(licenseUri: playReadyLicenseUri),
  ]),
);
```

The implementation must also expose:

- asynchronous binary challenge/response callbacks so authentication stays in
  the application and service secrets never enter the package;
- runtime capabilities for key systems, CENC/CBCS, security level, secure
  decoders, persistent licenses, HDCP/output restrictions, PiP, casting, and
  external displays;
- streaming and opaque offline-license handles without exposing raw keys;
- key rotation, renewal, release, expiration, provisioning, and sanitized
  failures that never log challenges, responses, tokens, headers, device IDs,
  certificates, or license bodies.

Protected sources will select a secure native backend automatically. FVP and
FFmpeg remain unprotected-media backends unless a future licensed integration
can prove a platform's complete secure decode and output path.

## Feature consequences

License policy can prohibit PiP, screenshots, casting, external displays, or
non-secure decoders. Controls must respond to runtime capabilities and disable
unavailable actions. Scrub previews must use provider-supplied sprites, image
tracks, WebVTT thumbnails, or a separate unprotected preview asset rather than
reading protected decoded frames.

DRM verification requires physical devices and real service credentials. A
simulator or widget test cannot validate Widevine security levels, FairPlay
keys, PlayReady hardware protection, HDCP, renewal, offline licenses, or output
restrictions.

## Primary references

- Android Media3 DRM: https://developer.android.com/media/media3/exoplayer/drm
- Apple FairPlay Streaming: https://developer.apple.com/streaming/fps/
- Apple `AVContentKeySession`: https://developer.apple.com/documentation/avfoundation/avcontentkeysession
- W3C Encrypted Media Extensions: https://www.w3.org/TR/encrypted-media-2/
- Google Widevine overview: https://developers.google.com/widevine/drm/overview
- Microsoft PlayReady for Windows apps: https://learn.microsoft.com/windows/uwp/audio-video-camera/playready-client-sdk
- Shaka Player DRM matrix: https://github.com/shaka-project/shaka-player#drm-support-matrix
