import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'yt_playlist_entry.dart';
import 'yt_source.dart';

/// Everything the ui needs to know about the media currently playing.
@immutable
class YtPlaybackState {
  /// How far into the video playback is.
  final Duration position;

  /// How long the video is, or [Duration.zero] while it is unknown.
  final Duration duration;

  /// Whether the video is currently advancing.
  final bool playing;

  /// Whether the player is waiting on data.
  final bool buffering;

  /// Whether the sound is off.
  final bool muted;

  /// Set once the browser has been seen refusing to play this with sound.
  final bool soundBlocked;

  /// The real aspect ratio of the media, when the backend knows it.
  final double? aspectRatio;

  /// How fast the video plays, `1.0` being normal speed.
  final double playbackRate;

  /// Constructor for [YtPlaybackState].
  const YtPlaybackState({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.muted = false,
    this.soundBlocked = false,
    this.aspectRatio,
    this.playbackRate = 1.0,
  });

  /// Clone a state.
  YtPlaybackState copyWith({
    Duration? position,
    Duration? duration,
    bool? playing,
    bool? buffering,
    bool? muted,
    bool? soundBlocked,
    double? aspectRatio,
    double? playbackRate,
  }) => YtPlaybackState(
    position: position ?? this.position,
    duration: duration ?? this.duration,
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    muted: muted ?? this.muted,
    soundBlocked: soundBlocked ?? this.soundBlocked,
    aspectRatio: aspectRatio ?? this.aspectRatio,
    playbackRate: playbackRate ?? this.playbackRate,
  );

  @override
  String toString() =>
      'YtPlaybackState($position/$duration, playing: $playing, '
      'buffering: $buffering, muted: $muted)';
}

/// What a link expanded to.
@immutable
class YtResolvedPlaylist {
  /// The videos to play, in the playlist's own order.
  final List<YtPlaylistEntry> entries;

  /// The playlist name, when there is one.
  final String? title;

  /// Where playback should start, honouring the `v=`/`index=` of the link.
  final int startIndex;

  /// Constructor for [YtResolvedPlaylist].
  const YtResolvedPlaylist({
    required this.entries,
    this.title,
    this.startIndex = 0,
  });
}

/// How a [YtPlayerBackend] should behave.
@immutable
class YtPlayerBackendOptions {
  /// Whether the platform player draws its own controls.
  ///
  /// Off by default, which is what a playlist app wants: it draws its own.
  /// Turning it off also takes the pointer and the keyboard away from the web
  /// player, so flutter keeps the focus and the arrow keys reach the app.
  final bool showControls;

  /// Constructor for [YtPlayerBackendOptions].
  const YtPlayerBackendOptions({this.showControls = false});
}

/// The platform half of a youtube player.
///
/// Desktop and mobile resolve the media urls themselves and hand them to
/// media_kit; the web drives youtube's own iframe player because the browser
/// cannot reach the media urls (nor youtube's pages) across origins.
///
/// A backend only ever knows about one video at a time. Playlist ordering
/// (shuffle, repeat, next/previous) belongs to the caller, which is what makes
/// it behave identically on every platform.
///
/// Get one with `createYtPlayerBackend()`.
abstract class YtPlayerBackend {
  /// Ticking playback position/duration/state.
  ValueListenable<YtPlaybackState> get playback;

  /// Emits once every time the current video reaches its end.
  Stream<void> get completions;

  /// Called whenever late arriving metadata for an entry becomes known.
  void Function(YtPlaylistEntry entry)? onEntryMetadata;

  /// Called when playback fails after [open] has already returned.
  void Function(String message)? onPlaybackError;

  /// Starts the underlying player. Call once, before anything else.
  Future<void> initialize();

  /// Expands a link into the list of videos to play.
  ///
  /// Throws [YtResolveException] when it cannot.
  Future<YtResolvedPlaylist> resolve(YtSource source);

  /// Loads [entry], and starts playing it unless [autoPlay] is off.
  Future<void> open(YtPlaylistEntry entry, {bool autoPlay = true});

  /// Resumes playback.
  Future<void> play();

  /// Holds playback where it is.
  Future<void> pause();

  /// Jumps to [position].
  Future<void> seek(Duration position);

  /// Turns the sound off or back on.
  Future<void> setMuted(bool muted);

  /// The video surface. It fills whatever box the caller gives it, which is
  /// already sized to the wanted aspect ratio.
  Widget buildVideoView(BuildContext context);

  /// Tears the player down. The backend is unusable afterwards.
  Future<void> dispose();
}

/// Thrown when a link cannot be expanded.
class YtResolveException implements Exception {
  /// What went wrong, in a form that can be shown to the user.
  final String message;

  /// Constructor for [YtResolveException].
  YtResolveException(this.message);

  @override
  String toString() => message;
}
