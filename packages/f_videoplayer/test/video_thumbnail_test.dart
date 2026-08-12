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

    expect(bytes, Uint8List.fromList(const [1, 2, 3]));
    expect(received?.method, 'saveThumbnailToBytes');
    expect(received?.arguments['srcFile'], r'C:\media\clip.mp4');
    expect(received?.arguments['srcFileUri'], isFalse);
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
