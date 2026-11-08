import 'dart:io';

import 'package:f_videoplayer/f_videoplayer.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'android_alpha_webm_video_player_platform.dart';
import 'ffmpeg_thumbnailer.dart';

bool get isAvailableOnCurrentPlatform =>
    Platform.isAndroid ||
    Platform.isIOS ||
    Platform.isLinux ||
    Platform.isMacOS ||
    Platform.isWindows ||
    Platform.operatingSystem == 'ohos';

void register(Map<String, Object> options) {
  fvp.registerWith(options: options);
  installLinuxThumbnailer();
}

/// Serves Linux thumbnails from MDK's bundled FFmpeg.
///
/// f_videoplayer has no native Linux thumbnailer, and the upstream plugin
/// linked the build host's system FFmpeg instead. A provider installed by the
/// host application is left in place.
void installLinuxThumbnailer() {
  if (!Platform.isLinux || FVideoThumbnail.platformProvider != null) return;
  final library = FfmpegThumbnailer.bundledLinuxLibrary();
  if (library == null || !FfmpegThumbnailer.supports(library)) return;
  final thumbnailer = FfmpegThumbnailer(library);
  FVideoThumbnail.platformProvider = (request) async {
    if (request.source.kind != FVideoSourceKind.file) return null;
    try {
      return await thumbnailer.generate(
        path: request.source.location,
        position: request.position,
        maxWidth: request.maxWidth,
      );
    } on Object {
      // An unreadable or undecodable file must not interrupt seeking.
      return null;
    }
  };
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
