import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

import 'youtube_playlist_page.dart';
import 'yt_player_backend.dart';
import 'yt_playlist_entry.dart';
import 'yt_source.dart';
import 'yt_stream_choice.dart';

/// The youtube player backend for desktop and mobile.
YtPlayerBackend createYtPlayerBackend({YtPlayerBackendOptions? options}) =>
    YtMediaKitBackend(options: options ?? const YtPlayerBackendOptions());

/// Youtube on desktop and mobile: youtube_explode_dart digs out the media urls
/// and media_kit (mpv) plays them.
class YtMediaKitBackend implements YtPlayerBackend {
  /// Youtube caps playlists at 200 entries in its own ui too.
  static const _maxPlaylistEntries = 200;

  /// How this backend should behave.
  final YtPlayerBackendOptions options;

  /// Constructor for [YtMediaKitBackend].
  YtMediaKitBackend({this.options = const YtPlayerBackendOptions()});

  late final Player _player;
  late final VideoController _videoController;
  final _yt = yt.YoutubeExplode();
  final _playlistPage = YoutubePlaylistPage();
  final _streamChooser = YtStreamChooser();

  final _playback = ValueNotifier(const YtPlaybackState());
  final _completions = StreamController<void>.broadcast();
  final _subscriptions = <StreamSubscription<void>>[];

  @override
  void Function(YtPlaylistEntry entry)? onEntryMetadata;

  @override
  void Function(String message)? onPlaybackError;

  @override
  ValueListenable<YtPlaybackState> get playback => _playback;

  @override
  Stream<void> get completions => _completions.stream;

  @override
  Future<void> initialize() async {
    MediaKit.ensureInitialized();
    _player = Player();
    // Left at the defaults on purpose: media_kit renders through its own
    // `vo=libmpv` into a flutter texture, and forcing `vo`/`hwdec` from here
    // takes that away from it and playback never starts.
    _videoController = VideoController(_player);

    final stream = _player.stream;
    _subscriptions.addAll([
      stream.position.listen(
        (p) => _playback.value = _playback.value.copyWith(position: p),
      ),
      stream.duration.listen(
        (d) => _playback.value = _playback.value.copyWith(duration: d),
      ),
      stream.playing.listen(
        (p) => _playback.value = _playback.value.copyWith(playing: p),
      ),
      stream.buffering.listen(
        (b) => _playback.value = _playback.value.copyWith(buffering: b),
      ),
      stream.volume.listen(
        (v) => _playback.value = _playback.value.copyWith(muted: v == 0),
      ),
      stream.rate.listen(
        (r) => _playback.value = _playback.value.copyWith(playbackRate: r),
      ),
      stream.width.listen((_) => _updateAspectRatio()),
      stream.height.listen((_) => _updateAspectRatio()),
      stream.completed.where((done) => done).listen((_) {
        if (!_completions.isClosed) _completions.add(null);
      }),
      stream.error.listen((message) {
        debugPrint('media_kit: $message');
        onPlaybackError?.call(message);
      }),
    ]);
  }

  @override
  Future<YtResolvedPlaylist> resolve(YtSource source) async {
    try {
      return switch (source) {
        YtVideoSource(:final videoId) => YtResolvedPlaylist(
          entries: [_toEntry(await _yt.videos.get(videoId))],
        ),
        YtPlaylistSource() => await _resolvePlaylist(source),
      };
    } on yt.VideoUnplayableException catch (e) {
      throw YtResolveException('Video unplayable: ${e.message}');
    } on yt.YoutubeExplodeException catch (e) {
      throw YtResolveException(e.message);
    }
  }

  Future<YtResolvedPlaylist> _resolvePlaylist(YtPlaylistSource source) async {
    final listing = await _playlistPage.fetch(
      source.playlistId,
      max: _maxPlaylistEntries,
    );
    if (listing.entries.isEmpty) {
      // A `watch?v=..&list=..` link on an unreadable mix still has a video.
      final startVideoId = source.startVideoId;
      if (startVideoId != null) {
        return YtResolvedPlaylist(
          entries: [_toEntry(await _yt.videos.get(startVideoId))],
        );
      }
      throw YtResolveException(
        'Could not read playlist ${source.playlistId}. It may be private, '
        'empty, or a generated mix.',
      );
    }

    return YtResolvedPlaylist(
      entries: listing.entries,
      title: listing.title,
      startIndex: _startIndexOf(source, listing.entries),
    );
  }

  static int _startIndexOf(
    YtPlaylistSource source,
    List<YtPlaylistEntry> entries,
  ) {
    final startVideoId = source.startVideoId;
    if (startVideoId != null) {
      final found = entries.indexWhere((e) => e.videoId == startVideoId);
      if (found >= 0) return found;
    }
    final startIndex = source.startIndex;
    if (startIndex != null && startIndex < entries.length) return startIndex;
    return 0;
  }

  static YtPlaylistEntry _toEntry(yt.Video video) => YtPlaylistEntry(
    videoId: video.id.value,
    title: video.title,
    author: video.author,
    duration: video.duration,
  );

  @override
  Future<void> open(YtPlaylistEntry entry, {bool autoPlay = true}) async {
    final manifest = await _yt.videos.streamsClient.getManifest(entry.videoId);
    final streams = await _streamChooser.choose(manifest);
    if (streams == null) {
      throw YtResolveException('No playable stream for ${entry.videoId}');
    }

    await _player.open(Media(streams.videoUrl.toString()), play: autoPlay);
    // Reset the track explicitly: a muxed stream following an adaptive one
    // must not keep the previous video's external audio.
    final audioUrl = streams.audioUrl;
    await _player.setAudioTrack(
      audioUrl == null
          ? AudioTrack.auto()
          : AudioTrack.uri(audioUrl.toString()),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) async {
    // See the web backend: keeps a fast chain of arrow taps accurate.
    _playback.value = _playback.value.copyWith(position: position);
    await _player.seek(position);
  }

  @override
  Future<void> setMuted(bool muted) => _player.setVolume(muted ? 0 : 100);

  @override
  Future<void> setPlaybackRate(double rate) => _player.setRate(rate);

  void _updateAspectRatio() {
    final width = _player.state.width;
    final height = _player.state.height;
    if (width == null || height == null || width <= 0 || height <= 0) return;
    _playback.value = _playback.value.copyWith(aspectRatio: width / height);
  }

  @override
  Widget buildVideoView(BuildContext context) => Video(
    controller: _videoController,
    // `NoVideoControls` is an untyped `null`, which strict-casts will not let
    // through a conditional, so say null outright.
    controls: options.showControls ? AdaptiveVideoControls : null,
    fill: const Color(0xFF000000),
  );

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _completions.close();
    _playlistPage.close();
    _streamChooser.close();
    _yt.close();
    await _player.dispose();
    _playback.dispose();
  }
}
