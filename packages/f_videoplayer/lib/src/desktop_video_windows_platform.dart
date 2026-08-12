import 'package:flutter/foundation.dart';

import 'desktop_video_window_arguments.dart';

abstract interface class FVideoDesktopWindowsPlatform {
  bool get isSupported;

  FVideoDesktopWindowErrorHandler? get onError;
  set onError(FVideoDesktopWindowErrorHandler? value);

  Set<int> get activeWindowIds;
  ValueListenable<bool> get currentWindowFullscreen;
  ValueListenable<int> get currentWindowCloseRevision;

  Future<FVideoDesktopWindowArguments?> initialize(
    List<String> arguments, {
    required String windowType,
  });

  Future<int?> open(
    FVideoDesktopWindowArguments arguments, {
    FVideoDesktopWindowClosed? onClosed,
    required Duration timeout,
  });

  Future<void> configureCurrentWindow({
    required String title,
    int? videoWidth,
    int? videoHeight,
  });

  Future<bool> focus(int windowId);
  Future<void> focusCurrentWindow();
  Future<void> hideCurrentWindow();
  Future<void> closeCurrentWindow();
  Future<void> close(int windowId);
  Future<void> closeAll();
  Future<bool> setCurrentWindowFullscreen(bool fullscreen);
  Future<void> toggleCurrentWindowFullscreen();
}
