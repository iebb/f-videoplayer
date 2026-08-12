import 'dart:io';

import 'package:fvp/fvp.dart' as fvp;
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'android_alpha_webm_video_player_platform.dart';

bool get isAvailableOnCurrentPlatform =>
    Platform.isAndroid ||
    Platform.isIOS ||
    Platform.isLinux ||
    Platform.isMacOS ||
    Platform.isWindows;

void register(Map<String, Object> options) {
  fvp.registerWith(options: options);
}

void registerAndroidAlphaWebmDecoder() {
  if (!Platform.isAndroid) return;
  final primary = VideoPlayerPlatform.instance;
  fvp.registerWith(
    options: <String, Object>{
      'platforms': <String>['android'],
      'video.decoders': <String>['FFmpeg'],
      'maxWidth': 512,
      'maxHeight': 512,
    },
  );
  final alphaWebm = VideoPlayerPlatform.instance;
  VideoPlayerPlatform.instance = AndroidAlphaWebmVideoPlayerPlatform(
    primaryBackend: primary,
    alphaWebmBackend: alphaWebm,
  );
}
