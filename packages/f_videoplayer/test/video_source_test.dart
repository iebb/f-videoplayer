import 'package:flutter_test/flutter_test.dart';
import 'package:f_videoplayer/f_videoplayer.dart';
import 'package:video_player/video_player.dart';

void main() {
  group('FVideoSource', () {
    test('network source retains request and playback configuration', () {
      final captions = Future<ClosedCaptionFile>.value(
        _EmptyClosedCaptionFile(),
      );
      final options = VideoPlayerOptions(mixWithOthers: false);
      final source = FVideoSource.network(
        'https://media.example/video.mp4',
        httpHeaders: const {'Authorization': 'Bearer test-token'},
        closedCaptionFile: captions,
        videoPlayerOptions: options,
      );

      expect(source.kind, FVideoSourceKind.network);
      expect(source.location, 'https://media.example/video.mp4');
      expect(source.thumbnailLocation, source.location);
      expect(source.httpHeaders, {'Authorization': 'Bearer test-token'});
      expect(source.closedCaptionFile, same(captions));
      expect(source.videoPlayerOptions, same(options));
    });

    test('asset source retains package and has no thumbnail location', () {
      const source = FVideoSource.asset(
        'videos/intro.mp4',
        package: 'feature_assets',
      );

      expect(source.kind, FVideoSourceKind.asset);
      expect(source.package, 'feature_assets');
      expect(source.thumbnailLocation, isNull);
    });

    test('URI factory distinguishes file and remote sources', () {
      final fileUri = Uri.file('/tmp/My Video.mp4');
      final file = FVideoSource.uri(fileUri);
      final remote = FVideoSource.uri(
        Uri.parse('https://media.example/video.mp4?quality=high'),
        httpHeaders: const {'X-Playback-Token': 'test'},
      );

      expect(file.kind, FVideoSourceKind.file);
      expect(file.location, fileUri.toFilePath());
      expect(remote.kind, FVideoSourceKind.network);
      expect(remote.location, 'https://media.example/video.mp4?quality=high');
      expect(remote.httpHeaders, {'X-Playback-Token': 'test'});
    });

    test('equivalent sources compare equally regardless of header order', () {
      const first = FVideoSource.network(
        'https://media.example/video.mp4',
        httpHeaders: {'A': '1', 'B': '2'},
      );
      const second = FVideoSource.network(
        'https://media.example/video.mp4',
        httpHeaders: {'B': '2', 'A': '1'},
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        first,
        isNot(const FVideoSource.network('https://media.example/other.mp4')),
      );
    });
  });
}

class _EmptyClosedCaptionFile extends ClosedCaptionFile {
  @override
  List<Caption> get captions => const [];
}
