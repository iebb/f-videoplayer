import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Decodes single video frames with the FFmpeg runtime that MDK bundles.
///
/// Only stable public FFmpeg entry points are called. The single structure
/// read directly is the leading `data`/`linesize` arrays of `AVFrame`, whose
/// layout has not changed since FFmpeg's first public releases, so an MDK
/// update to a newer FFmpeg does not need a matching rebuild here.
final class FfmpegThumbnailer {
  FfmpegThumbnailer(this.libraryPath);

  /// Path of the FFmpeg shared library to load in each decoding isolate.
  final String libraryPath;

  /// MDK's FFmpeg inside a Flutter Linux bundle, or null when it is absent.
  static String? bundledLinuxLibrary() {
    if (!Platform.isLinux) return null;
    final bundle = File(Platform.resolvedExecutable).parent.path;
    final library = File('$bundle/lib/libffmpeg.so.9');
    return library.existsSync() ? library.path : null;
  }

  /// Whether [libraryPath] loads and exports every function the decoder uses.
  static bool supports(String libraryPath) {
    try {
      _Ffmpeg(DynamicLibrary.open(libraryPath));
      return true;
    } on Object {
      return false;
    }
  }

  /// A BMP image of the key frame at or before [position], at most [maxWidth]
  /// pixels wide, or null when decoding yields no frame. A position beyond the
  /// end gives the last key frame. Throws [FfmpegException] for an unreadable
  /// file or one without video.
  ///
  /// Decoding runs on a short-lived isolate so seeking never blocks the UI.
  Future<Uint8List?> generate({
    required String path,
    required Duration position,
    required int maxWidth,
  }) {
    final library = libraryPath;
    return Isolate.run(
      () => decodeFrame(library, path, position: position, maxWidth: maxWidth),
    );
  }
}

/// Synchronously decodes one frame as a BMP image. Used by
/// [FfmpegThumbnailer.generate] on a background isolate.
Uint8List? decodeFrame(
  String libraryPath,
  String videoPath, {
  required Duration position,
  required int maxWidth,
}) {
  if (maxWidth <= 0) {
    throw ArgumentError.value(maxWidth, 'maxWidth', 'must be positive');
  }
  final ffmpeg = _Ffmpeg(DynamicLibrary.open(libraryPath));
  return using((arena) {
    final graphSlot = arena<Pointer<Void>>();
    final frameSlot = arena<Pointer<Void>>();
    graphSlot.value = ffmpeg.graphAlloc();
    if (graphSlot.value == nullptr) return null;
    try {
      final graph = graphSlot.value;
      Pointer<Void> filter(String type, Map<String, String> options) {
        final definition = ffmpeg.getByName(
          type.toNativeUtf8(allocator: arena),
        );
        if (definition == nullptr) {
          throw FfmpegException('FFmpeg has no $type filter');
        }
        final context = ffmpeg.allocFilter(
          graph,
          definition,
          type.toNativeUtf8(allocator: arena),
        );
        if (context == nullptr) {
          throw FfmpegException('could not allocate the $type filter');
        }
        // Options are set individually rather than through a filter
        // description, so paths need no filtergraph escaping.
        for (final MapEntry(:key, :value) in options.entries) {
          ffmpeg.check(
            ffmpeg.optSet(
              context,
              key.toNativeUtf8(allocator: arena),
              value.toNativeUtf8(allocator: arena),
              _avOptSearchChildren,
            ),
            'set $type $key',
          );
        }
        ffmpeg.check(ffmpeg.initStr(context, nullptr), 'initialize $type');
        return context;
      }

      final chain = [
        filter('movie', {
          'filename': videoPath,
          // The demuxer seeks to the key frame at or before this point.
          if (position > Duration.zero)
            'seek_point': (position.inMicroseconds / 1e6).toString(),
        }),
        filter('scale', {'w': 'min($maxWidth,iw)', 'h': '-2'}),
        filter('format', {'pix_fmts': 'bgr24'}),
        filter('buffersink', const {}),
      ];
      for (var index = 1; index < chain.length; index++) {
        ffmpeg.check(
          ffmpeg.link(chain[index - 1], 0, chain[index], 0),
          'link the thumbnail filters',
        );
      }
      ffmpeg.check(ffmpeg.graphConfig(graph, nullptr), 'configure filters');

      final frame = frameSlot.value = ffmpeg.frameAlloc();
      if (frame == nullptr) return null;
      final sink = chain.last;
      // A negative status is the end of the stream before any frame, such as
      // a position past the duration; that has no thumbnail.
      if (ffmpeg.sinkGetFrame(sink, frame) < 0) return null;
      final width = ffmpeg.sinkWidth(sink);
      final height = ffmpeg.sinkHeight(sink);
      // AVFrame begins with uint8_t *data[8] followed by int linesize[8].
      final pixels = frame.cast<Pointer<Uint8>>().value;
      final stride = (frame.cast<Uint8>() + 8 * sizeOf<Pointer<Void>>())
          .cast<Int32>()
          .value;
      if (pixels == nullptr ||
          width <= 0 ||
          height <= 0 ||
          stride < width * 3) {
        return null;
      }
      return encodeBgr24Bmp(
        pixels.asTypedList((height - 1) * stride + width * 3),
        width: width,
        height: height,
        stride: stride,
      );
    } finally {
      if (frameSlot.value != nullptr) ffmpeg.frameFree(frameSlot);
      ffmpeg.graphFree(graphSlot);
    }
  });
}

/// Wraps top-down BGR24 rows in an uncompressed BMP, which Flutter decodes
/// without an image-encoding dependency.
Uint8List encodeBgr24Bmp(
  Uint8List pixels, {
  required int width,
  required int height,
  required int stride,
}) {
  const headerSize = 54;
  final rowSize = (width * 3 + 3) & ~3;
  final image = Uint8List(headerSize + rowSize * height);
  ByteData.sublistView(image)
    ..setUint8(0, 0x42) // 'B'
    ..setUint8(1, 0x4d) // 'M'
    ..setUint32(2, image.length, Endian.little)
    ..setUint32(10, headerSize, Endian.little)
    ..setUint32(14, 40, Endian.little) // BITMAPINFOHEADER
    ..setInt32(18, width, Endian.little)
    ..setInt32(22, height, Endian.little) // positive: rows stored bottom-up
    ..setUint16(26, 1, Endian.little)
    ..setUint16(28, 24, Endian.little)
    ..setUint32(34, rowSize * height, Endian.little);
  for (var row = 0; row < height; row++) {
    final from = (height - 1 - row) * stride;
    final to = headerSize + row * rowSize;
    image.setRange(to, to + width * 3, pixels, from);
  }
  return image;
}

class FfmpegException implements Exception {
  const FfmpegException(this.message);

  final String message;

  @override
  String toString() => 'FfmpegException: $message';
}

const _avOptSearchChildren = 1;

final class _Ffmpeg {
  _Ffmpeg(DynamicLibrary library)
    : graphAlloc = library
          .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
            'avfilter_graph_alloc',
          ),
      graphFree = library
          .lookupFunction<
            Void Function(Pointer<Pointer<Void>>),
            void Function(Pointer<Pointer<Void>>)
          >('avfilter_graph_free'),
      getByName = library
          .lookupFunction<
            Pointer<Void> Function(Pointer<Utf8>),
            Pointer<Void> Function(Pointer<Utf8>)
          >('avfilter_get_by_name'),
      allocFilter = library
          .lookupFunction<
            Pointer<Void> Function(Pointer<Void>, Pointer<Void>, Pointer<Utf8>),
            Pointer<Void> Function(Pointer<Void>, Pointer<Void>, Pointer<Utf8>)
          >('avfilter_graph_alloc_filter'),
      optSet = library
          .lookupFunction<
            Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>, Int32),
            int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>, int)
          >('av_opt_set'),
      initStr = library
          .lookupFunction<
            Int32 Function(Pointer<Void>, Pointer<Utf8>),
            int Function(Pointer<Void>, Pointer<Utf8>)
          >('avfilter_init_str'),
      link = library
          .lookupFunction<
            Int32 Function(Pointer<Void>, Uint32, Pointer<Void>, Uint32),
            int Function(Pointer<Void>, int, Pointer<Void>, int)
          >('avfilter_link'),
      graphConfig = library
          .lookupFunction<
            Int32 Function(Pointer<Void>, Pointer<Void>),
            int Function(Pointer<Void>, Pointer<Void>)
          >('avfilter_graph_config'),
      sinkGetFrame = library
          .lookupFunction<
            Int32 Function(Pointer<Void>, Pointer<Void>),
            int Function(Pointer<Void>, Pointer<Void>)
          >('av_buffersink_get_frame'),
      sinkWidth = library
          .lookupFunction<
            Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('av_buffersink_get_w'),
      sinkHeight = library
          .lookupFunction<
            Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('av_buffersink_get_h'),
      frameAlloc = library
          .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
            'av_frame_alloc',
          ),
      frameFree = library
          .lookupFunction<
            Void Function(Pointer<Pointer<Void>>),
            void Function(Pointer<Pointer<Void>>)
          >('av_frame_free'),
      _strerror = library
          .lookupFunction<
            Int32 Function(Int32, Pointer<Utf8>, Size),
            int Function(int, Pointer<Utf8>, int)
          >('av_strerror');

  final Pointer<Void> Function() graphAlloc;
  final void Function(Pointer<Pointer<Void>>) graphFree;
  final Pointer<Void> Function(Pointer<Utf8>) getByName;
  final Pointer<Void> Function(Pointer<Void>, Pointer<Void>, Pointer<Utf8>)
  allocFilter;
  final int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>, int) optSet;
  final int Function(Pointer<Void>, Pointer<Utf8>) initStr;
  final int Function(Pointer<Void>, int, Pointer<Void>, int) link;
  final int Function(Pointer<Void>, Pointer<Void>) graphConfig;
  final int Function(Pointer<Void>, Pointer<Void>) sinkGetFrame;
  final int Function(Pointer<Void>) sinkWidth;
  final int Function(Pointer<Void>) sinkHeight;
  final Pointer<Void> Function() frameAlloc;
  final void Function(Pointer<Pointer<Void>>) frameFree;
  final int Function(int, Pointer<Utf8>, int) _strerror;

  void check(int status, String action) {
    if (status >= 0) return;
    final message = using((arena) {
      final buffer = arena<Uint8>(128).cast<Utf8>();
      return _strerror(status, buffer, 128) < 0
          ? 'error $status'
          : buffer.toDartString();
    });
    throw FfmpegException('could not $action: $message');
  }
}
