import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

/// What to hand mpv for one video.
class YtChosenStreams {
  /// The stream carrying the picture.
  final Uri videoUrl;

  /// Set when the video stream carries no audio of its own.
  final Uri? audioUrl;

  /// Constructor for [YtChosenStreams].
  const YtChosenStreams({required this.videoUrl, this.audioUrl});

  /// Whether picture and sound come from two separate streams.
  bool get isAdaptive => audioUrl != null;
}

/// Picks the streams of a video that mpv will actually be able to play.
///
/// Muxed streams never go beyond 360p, so an adaptive video stream plus a
/// separate audio track is worth a lot. The catch is that youtube now answers
/// some adaptive streams with a `403` unless the request asks for a bounded
/// byte range — and mpv opens a url with `Range: bytes=0-`. Nothing in the
/// manifest says which streams are affected, so ask for them exactly the way
/// mpv will and fall back to the muxed stream when they are.
class YtStreamChooser {
  /// Youtube goes up to 4k, which is a lot of decoding for a window this size
  /// and murder without working hardware decode.
  final int maxVideoHeight;

  final HttpClient _client;
  final bool _ownsClient;

  /// Constructor for [YtStreamChooser].
  YtStreamChooser({HttpClient? client, this.maxVideoHeight = 1080})
    : _client = client ?? HttpClient(),
      _ownsClient = client == null;

  /// Returns null when the video has nothing playable at all.
  Future<YtChosenStreams?> choose(yt.StreamManifest manifest) async {
    final video = _pickVideoStream(manifest);
    final audio = manifest.audioOnly.isEmpty
        ? null
        : manifest.audioOnly.withHighestBitrate();

    if (video != null && audio != null) {
      final serves = await Future.wait([
        servesOpenEndedRange(video.url),
        servesOpenEndedRange(audio.url),
      ]);
      if (!serves.contains(false)) {
        return YtChosenStreams(videoUrl: video.url, audioUrl: audio.url);
      }
    }

    if (manifest.muxed.isEmpty) return null;
    return YtChosenStreams(videoUrl: manifest.muxed.withHighestBitrate().url);
  }

  /// The highest stream up to [maxVideoHeight], preferring h264 since that is
  /// the one codec everything can decode in hardware.
  yt.VideoOnlyStreamInfo? _pickVideoStream(yt.StreamManifest manifest) {
    final candidates = manifest.videoOnly.sortByVideoQuality();
    if (candidates.isEmpty) return null;
    final affordable = candidates
        .where((s) => s.videoResolution.height <= maxVideoHeight)
        .toList();
    if (affordable.isEmpty) return candidates.last;
    return affordable.firstWhere(
      (s) => s.videoCodec.startsWith('avc1'),
      orElse: () => affordable.first,
    );
  }

  /// Whether youtube serves [url] to a request shaped like mpv's.
  Future<bool> servesOpenEndedRange(Uri url) async {
    try {
      final request = await _client.getUrl(url);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
      final response = await request.close();
      // Never read the body: the range is open ended, so that is the whole
      // file. Dropping the subscription closes the connection instead.
      await response.listen(null, cancelOnError: true).cancel();
      return response.statusCode < HttpStatus.badRequest;
    } on Exception {
      return false;
    }
  }

  /// Closes the http client, unless one was passed in.
  void close() {
    if (_ownsClient) _client.close(force: true);
  }
}
