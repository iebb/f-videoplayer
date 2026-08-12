# f_videoplayer_pip

Native Picture-in-Picture sessions for F Video Player.

The Dart API is backend-neutral and carries source URI, playback position,
speed, normalized volume, mute state, video size, source rectangle, and
localized play/pause labels. Session callbacks report entry, restoration,
remote play/pause actions, and final position.

## Support

- Android 8+: the existing activity and Flutter texture enter system PiP.
- iOS: AVKit uses the active FVP player when available, otherwise a synchronized
  AVPlayer session for the same URI.
- macOS: AVKit uses a synchronized AVPlayer session.
- Web, Windows, and Linux: `isSupported()` returns false. Hosts can implement
  browser PiP or an always-on-top mini-player through the core presentation
  callbacks without misrepresenting it as this native contract.

## Protected content

v0.5.0 does not configure FairPlay, Widevine, PlayReady, license challenges, or
protected offline keys. Protected-content PiP therefore requires a future
DRM-capable active backend and a positive runtime capability decision; the URI
fallback alone is not a DRM handoff.

## Android host integration

Set `android:supportsPictureInPicture="true"` on the Flutter activity. Forward
the following activity callbacks to `FVideoPictureInPicturePlugin`:

- `onStart`, `onResume`, `onPause`, `onStop`, and `onDestroy`
- `onUserLeaveHint`
- `onPictureInPictureRequested`
- `onPictureInPictureModeChanged`

The repository example contains the complete Kotlin implementation. Android
12+ uses auto-enter parameters; Android 8–11 use the forwarded leave/request
callbacks. The plugin verifies the system feature and AppOps permission before
advertising support.

## Start a session

```dart
final started = await FVideoPictureInPicture.start(
  id: 'episode-42',
  uri: Uri.parse('https://media.example/episode-42.m3u8'),
  position: controller.value.position,
  speed: controller.value.playbackSpeed,
  volume: controller.value.volume,
  muted: controller.value.volume == 0,
  playing: controller.value.isPlaying,
  videoSize: controller.value.size,
  playerId: controller.playerId,
  onActionRequested: (action) async {
    switch (action) {
      case FVideoPictureInPictureAction.play:
        await controller.play();
      case FVideoPictureInPictureAction.pause:
        await controller.pause();
    }
  },
  onRestoreRequested: (snapshot) async {
    await controller.seekTo(snapshot.position);
    await controller.setPlaybackSpeed(snapshot.speed);
    await controller.setVolume(snapshot.muted ? 0 : snapshot.volume);
    return true;
  },
);
```

Call `updatePrepared` as state changes when using prewarming, and call
`cancelPrepared` when a route or media item is disposed.

## Apple capabilities

iOS applications must enable the Audio, AirPlay, and Picture in Picture
background mode. The AVPlayer fallback needs a URI that the native player can
open with the same authorization; applications with short-lived or custom
authorization should prefer an injected/active backend or provide a signed
playback URI.

## License

BSD-3-Clause. See the repository notice for optional FVP/libmdk terms.
