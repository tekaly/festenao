import 'package:flutter/foundation.dart';

/// One video in a loaded playlist.
///
/// Everything but [videoId] is optional: on the web the ids arrive from the
/// iframe player long before the titles can be looked up.
@immutable
class YtPlaylistEntry {
  /// The 11 character video id.
  final String videoId;

  /// The video title, when it is known.
  final String? title;

  /// The channel name, when it is known.
  final String? author;

  /// The runtime, when it is known.
  final Duration? duration;

  /// Constructor for [YtPlaylistEntry].
  const YtPlaylistEntry({
    required this.videoId,
    this.title,
    this.author,
    this.duration,
  });

  /// The title, falling back to the id while the metadata is still loading.
  String get displayTitle => title ?? videoId;

  /// Youtube's own thumbnail for this video.
  Uri get thumbnailUri =>
      Uri.parse('https://i.ytimg.com/vi/$videoId/mqdefault.jpg');

  /// Fills in whatever [other] knows and we don't.
  YtPlaylistEntry mergedWith(YtPlaylistEntry other) => YtPlaylistEntry(
    videoId: videoId,
    title: other.title ?? title,
    author: other.author ?? author,
    duration: other.duration ?? duration,
  );

  @override
  String toString() => 'YtPlaylistEntry($videoId, $title)';
}
