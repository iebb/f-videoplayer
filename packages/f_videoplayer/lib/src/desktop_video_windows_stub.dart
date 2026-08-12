import 'package:flutter/foundation.dart';

import 'desktop_video_window_arguments.dart';
import 'desktop_video_windows_platform.dart';

FVideoDesktopWindowsPlatform createDesktopWindowsPlatform() =>
    _UnsupportedDesktopVideoWindows();

class _UnsupportedDesktopVideoWindows implements FVideoDesktopWindowsPlatform {
  final ValueNotifier<bool> _currentWindowFullscreen = ValueNotifier(false);
  final ValueNotifier<int> _currentWindowCloseRevision = ValueNotifier(0);

  @override
  bool get isSupported => false;

  @override
  FVideoDesktopWindowErrorHandler? onError;

  @override
  Set<int> get activeWindowIds => const {};

  @override
  ValueListenable<bool> get currentWindowFullscreen => _currentWindowFullscreen;

  @override
  ValueListenable<int> get currentWindowCloseRevision =>
      _currentWindowCloseRevision;

  @override
  Future<FVideoDesktopWindowArguments?> initialize(
    List<String> arguments, {
    required String windowType,
  }) async => null;

  @override
  Future<int?> open(
    FVideoDesktopWindowArguments arguments, {
    FVideoDesktopWindowClosed? onClosed,
    required Duration timeout,
  }) async {
    if (onClosed != null) {
      try {
        await onClosed();
      } on Object catch (error, stackTrace) {
        try {
          onError?.call(
            FVideoDesktopWindowException('onClosed', error),
            stackTrace,
          );
        } on Object {
          // Unsupported-platform cleanup remains a non-throwing no-op.
        }
      }
    }
    return null;
  }

  @override
  Future<void> configureCurrentWindow({
    required String title,
    int? videoWidth,
    int? videoHeight,
  }) async {}

  @override
  Future<bool> focus(int windowId) async => false;

  @override
  Future<void> focusCurrentWindow() async {}

  @override
  Future<void> hideCurrentWindow() async {}

  @override
  Future<void> closeCurrentWindow() async {}

  @override
  Future<void> close(int windowId) async {}

  @override
  Future<void> closeAll() async {}

  @override
  Future<bool> setCurrentWindowFullscreen(bool fullscreen) async => false;

  @override
  Future<void> toggleCurrentWindowFullscreen() async {}
}
