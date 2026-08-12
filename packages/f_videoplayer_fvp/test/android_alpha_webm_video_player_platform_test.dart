import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:f_videoplayer_fvp/src/android_alpha_webm_video_player_platform.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  test('recognizes local WebM files for the optional alpha decoder', () {
    expect(
      isAndroidAlphaWebmDataSource(
        _fileSource('/data/user/0/com.example.app/files/animations/123.webm'),
      ),
      isTrue,
    );
    expect(
      isAndroidAlphaWebmDataSource(
        _fileSource('/data/user/0/com.example.app/files/videos/123.webm'),
      ),
      isTrue,
    );
    expect(
      isAndroidAlphaWebmDataSource(
        _fileSource('/data/user/0/com.example.app/files/animations/123.mp4'),
      ),
      isFalse,
    );
    expect(
      isAndroidAlphaWebmDataSource(
        DataSource(
          sourceType: DataSourceType.network,
          uri: 'https://example.test/animations/123.webm',
        ),
      ),
      isFalse,
    );
  });

  test('routes WebM and regular player operations independently', () async {
    final primary = _FakeVideoPlayerPlatform('primary');
    final alphaWebm = _FakeVideoPlayerPlatform('alphaWebm');
    final platform = AndroidAlphaWebmVideoPlayerPlatform(
      primaryBackend: primary,
      alphaWebmBackend: alphaWebm,
    );

    await platform.init();
    final regularId = await platform.createWithOptions(
      VideoCreationOptions(
        dataSource: _fileSource('/data/user/0/com.example.app/video.mp4'),
        viewType: VideoViewType.platformView,
      ),
    );
    final alphaWebmId = await platform.createWithOptions(
      VideoCreationOptions(
        dataSource: _fileSource(
          '/data/user/0/com.example.app/files/animations/123.webm',
        ),
        viewType: VideoViewType.textureView,
      ),
    );

    expect(regularId, isNot(alphaWebmId));
    expect(primary.created, hasLength(1));
    expect(primary.created.single.viewType, VideoViewType.platformView);
    expect(alphaWebm.created, hasLength(1));
    expect(alphaWebm.created.single.viewType, VideoViewType.textureView);

    await platform.play(regularId!);
    await platform.play(alphaWebmId!);
    expect(primary.played, [primary.backendPlayerId]);
    expect(alphaWebm.played, [alphaWebm.backendPlayerId]);

    expect(
      (platform.buildView(regularId) as SizedBox).key,
      ValueKey<String>('primary-${primary.backendPlayerId}'),
    );
    expect(
      (platform.buildView(alphaWebmId) as SizedBox).key,
      ValueKey<String>('alphaWebm-${alphaWebm.backendPlayerId}'),
    );

    await platform.dispose(regularId);
    await platform.dispose(alphaWebmId);
    expect(primary.disposed, [primary.backendPlayerId]);
    expect(alphaWebm.disposed, [alphaWebm.backendPlayerId]);
  });
}

DataSource _fileSource(String path) =>
    DataSource(sourceType: DataSourceType.file, uri: Uri.file(path).toString());

final class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  _FakeVideoPlayerPlatform(this.name);

  final String name;
  final int backendPlayerId = 7;
  final List<VideoCreationOptions> created = <VideoCreationOptions>[];
  final List<int> played = <int>[];
  final List<int> disposed = <int>[];

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    created.add(options);
    return backendPlayerId;
  }

  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      const Stream<VideoEvent>.empty();

  @override
  Future<void> play(int playerId) async {
    played.add(playerId);
  }

  @override
  Widget buildView(int playerId) =>
      SizedBox(key: ValueKey<String>('$name-$playerId'));
}
