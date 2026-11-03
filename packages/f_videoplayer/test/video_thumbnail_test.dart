import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:f_videoplayer/f_videoplayer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('thumbnail request validates reusable provider parameters', () {
    const request = FVideoThumbnailRequest(
      source: FVideoSource.network('https://example.invalid/video.mp4'),
      position: Duration(seconds: 12),
      maxWidth: 320,
      quality: 80,
    );

    expect(request.source.location, endsWith('video.mp4'));
    expect(request.position, const Duration(seconds: 12));
    expect(request.maxWidth, 320);
    expect(request.quality, 80);
  });

  test('legacy API recognizes Windows drive paths as native files', () async {
    const channel = MethodChannel('fc_native_video_thumbnail');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return Uint8List.fromList(const [1, 2, 3]);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final bytes = await FVideoThumbnail.generate(
      source: r'C:\media\clip.mp4',
      position: Duration.zero,
    );

    if (Platform.isLinux) {
      expect(bytes, isNull);
      expect(received, isNull);
      return;
    }
    expect(bytes, Uint8List.fromList(const [1, 2, 3]));
    expect(received?.method, 'saveThumbnailToBytes');
    expect(received?.arguments['srcFile'], r'C:\media\clip.mp4');
    expect(received?.arguments['srcFileUri'], isFalse);
  });

  test('platform provider serves valid requests only', () async {
    final requests = <FVideoThumbnailRequest>[];
    FVideoThumbnail.platformProvider = (request) async {
      requests.add(request);
      return Uint8List.fromList(const [9]);
    };
    addTearDown(() => FVideoThumbnail.platformProvider = null);

    final bytes = await FVideoThumbnail.generate(
      source: '/media/clip.mp4',
      position: const Duration(seconds: 3),
      maxWidth: 120,
    );

    expect(bytes, Uint8List.fromList(const [9]));
    expect(requests.single.source.location, '/media/clip.mp4');
    expect(requests.single.position, const Duration(seconds: 3));
    expect(requests.single.maxWidth, 120);
    expect(
      () => FVideoThumbnail.generateRequest(
        const FVideoThumbnailRequest(
          source: FVideoSource.file('/media/clip.mp4'),
          position: Duration(seconds: -1),
        ),
      ),
      throwsArgumentError,
    );
    expect(requests, hasLength(1));
  });

  test('thumbnail request rejects invalid release-mode parameters', () {
    expect(
      () => FVideoThumbnail.generateRequest(
        const FVideoThumbnailRequest(
          source: FVideoSource.asset('video.mp4'),
          position: Duration(seconds: -1),
        ),
      ),
      throwsArgumentError,
    );
  });
}
