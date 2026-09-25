import 'package:flutter/foundation.dart';

/// A YouTube link (or bare id) resolved into something we know how to play.
@immutable
sealed class YtSource {
  /// Const constructor for subclasses.
  const YtSource();
}

/// A single video.
@immutable
class YtVideoSource extends YtSource {
  /// The 11 character video id.
  final String videoId;

  /// Where to start, the `t=` (or `start=`) of the link.
  final Duration? start;

  /// Constructor for [YtVideoSource].
  const YtVideoSource(this.videoId, {this.start});

  @override
  String toString() =>
      'YtVideoSource($videoId${start == null ? '' : ', start: $start'})';
}

/// A playlist, optionally starting on a given video or 0 based index.
@immutable
class YtPlaylistSource extends YtSource {
  /// The `list=` of the link.
  final String playlistId;

  /// The `v=` of a `watch?v=...&list=...` link, when there was one.
  final String? startVideoId;

  /// The `index=` of the link, converted to 0 based.
  final int? startIndex;

  /// Where to start in the start video, the `t=` of the link.
  final Duration? start;

  /// Constructor for [YtPlaylistSource].
  const YtPlaylistSource(
    this.playlistId, {
    this.startVideoId,
    this.startIndex,
    this.start,
  });

  @override
  String toString() =>
      'YtPlaylistSource($playlistId, startVideoId: $startVideoId, '
      'startIndex: $startIndex)';
}

final _videoIdRegExp = RegExp(r'^[A-Za-z0-9_-]{11}$');
final _playlistIdRegExp = RegExp(r'^[A-Za-z0-9_-]{12,}$');

/// Playlist ids all start with one of these (`PL` user playlists, `UU`/`UL`
/// channel uploads, `LL` likes, `RD` mixes, `OL`/`FL`/`TL` misc).
const _playlistIdPrefixes = ['PL', 'UU', 'UL', 'LL', 'RD', 'OL', 'FL', 'TL'];

bool _looksLikePlaylistId(String text) =>
    _playlistIdRegExp.hasMatch(text) &&
    _playlistIdPrefixes.any(text.startsWith);

final _startTimeRegExp = RegExp(r'^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s?)?$');

/// Parse a youtube start time: `90`, `90s`, `1m30s`, `1h2m3s`.
///
/// Returns null when [text] is not one, or is zero.
Duration? parseYtStartTime(String? text) {
  if (text == null || text.isEmpty) return null;
  final match = _startTimeRegExp.firstMatch(text.trim());
  if (match == null) return null;
  final hours = int.tryParse(match.group(1) ?? '') ?? 0;
  final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
  final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
  final duration = Duration(hours: hours, minutes: minutes, seconds: seconds);
  return duration == Duration.zero ? null : duration;
}

/// Path segments that are followed by a video id, as in `/shorts/<id>`.
const _videoIdPathPrefixes = ['shorts', 'embed', 'live', 'v'];

/// Parses anything the user may paste: a watch/playlist/youtu.be/shorts url,
/// or a bare video or playlist id.
///
/// A link carrying both a `v=` and a `list=` resolves to the playlist, starting
/// on that video, which is what youtube itself does.
YtSource? parseYtSource(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;

  if (!text.contains('/') && !text.contains('?') && !text.contains('&')) {
    if (_videoIdRegExp.hasMatch(text)) return YtVideoSource(text);
    if (_looksLikePlaylistId(text)) return YtPlaylistSource(text);
    return null;
  }

  final uri = Uri.tryParse(
    text.startsWith('http://') || text.startsWith('https://')
        ? text
        : 'https://$text',
  );
  if (uri == null) return null;

  final host = uri.host.toLowerCase();
  final isShortLink = host == 'youtu.be';
  if (!isShortLink && !host.endsWith('youtube.com')) return null;

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  var videoId = uri.queryParameters['v'];
  if (videoId == null && isShortLink && segments.isNotEmpty) {
    videoId = segments.first;
  }
  if (videoId == null && segments.length >= 2) {
    if (_videoIdPathPrefixes.contains(segments[segments.length - 2])) {
      videoId = segments.last;
    }
  }
  if (videoId != null && !_videoIdRegExp.hasMatch(videoId)) videoId = null;

  final start = parseYtStartTime(
    uri.queryParameters['t'] ?? uri.queryParameters['start'],
  );
  final playlistId = uri.queryParameters['list'];
  if (playlistId != null && playlistId.isNotEmpty) {
    final index = int.tryParse(uri.queryParameters['index'] ?? '');
    return YtPlaylistSource(
      playlistId,
      startVideoId: videoId,
      // Youtube's `index` is 1 based.
      startIndex: index != null && index > 0 ? index - 1 : null,
      start: start,
    );
  }
  return videoId == null ? null : YtVideoSource(videoId, start: start);
}
