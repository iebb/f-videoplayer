import 'dart:io';
import 'dart:typed_data';

import 'package:f_videoplayer_fvp/src/ffmpeg_thumbnailer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BMP encoder writes a bottom-up 24-bit image with padded rows', () {
    // Two 3x1 rows (width 3 -> 9 bytes, padded to 12), stride 10.
    final pixels = Uint8List(10 + 9)
      ..setRange(0, 9, List.generate(9, (i) => 10 + i))
      ..setRange(10, 19, List.generate(9, (i) => 50 + i));

    final bmp = encodeBgr24Bmp(pixels, width: 3, height: 2, stride: 10);
    final data = ByteData.sublistView(bmp);

    expect(bmp.length, 54 + 12 * 2);
    expect(String.fromCharCodes(bmp.sublist(0, 2)), 'BM');
    expect(data.getUint32(2, Endian.little), bmp.length);
    expect(data.getUint32(10, Endian.little), 54);
    expect(data.getInt32(18, Endian.little), 3);
    expect(data.getInt32(22, Endian.little), 2);
    expect(data.getUint16(28, Endian.little), 24);
    // The bottom image row (source row 1) is stored first.
    expect(bmp.sublist(54, 63), List.generate(9, (i) => 50 + i));
    expect(bmp.sublist(63, 66), [0, 0, 0]);
    expect(bmp.sublist(66, 75), List.generate(9, (i) => 10 + i));
  });

  test('decoder rejects a non-positive width before loading FFmpeg', () {
    expect(
      () => decodeFrame(
        '/does/not/exist.so',
        '/video.mp4',
        position: Duration.zero,
        maxWidth: 0,
      ),
      throwsArgumentError,
    );
  });

  // Needs a Linux FFmpeg runtime such as MDK's libffmpeg.so.9 and a sample
  // video, so it only runs when both are provided:
  //   FFMPEG_THUMBNAIL_LIBRARY=/path/libffmpeg.so.9 \
  //   FFMPEG_THUMBNAIL_VIDEO=/path/clip.mp4 flutter test
  final library = Platform.environment['FFMPEG_THUMBNAIL_LIBRARY'];
  final video = Platform.environment['FFMPEG_THUMBNAIL_VIDEO'];
  final skipReason = library == null || video == null
      ? 'FFMPEG_THUMBNAIL_LIBRARY and FFMPEG_THUMBNAIL_VIDEO are not set'
      : null;

  test('decodes a real frame', () async {
    expect(FfmpegThumbnailer.supports(library!), isTrue);
    final thumbnailer = FfmpegThumbnailer(library);

    final first = await thumbnailer.generate(
      path: video!,
      position: Duration.zero,
      maxWidth: 64,
    );
    final later = await thumbnailer.generate(
      path: video,
      position: const Duration(seconds: 1),
      maxWidth: 64,
    );
    final past = await thumbnailer.generate(
      path: video,
      position: const Duration(hours: 5),
      maxWidth: 64,
    );

    for (final bmp in [first, later]) {
      expect(bmp, isNotNull);
      final data = ByteData.sublistView(bmp!);
      expect(String.fromCharCodes(bmp.sublist(0, 2)), 'BM');
      expect(data.getInt32(18, Endian.little), lessThanOrEqualTo(64));
      expect(data.getInt32(22, Endian.little), greaterThan(0));
    }
    expect(first, isNot(later), reason: 'the seek point must change the frame');
    // FFmpeg seeks to the last key frame for a position beyond the end.
    expect(
      past == null || String.fromCharCodes(past.sublist(0, 2)) == 'BM',
      isTrue,
    );
    await expectLater(
      thumbnailer.generate(
        path: '/no/such/video.mp4',
        position: Duration.zero,
        maxWidth: 64,
      ),
      throwsA(isA<FfmpegException>()),
    );
  }, skip: skipReason);
}
