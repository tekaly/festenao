import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'yt_player_backend.dart';
import 'yt_playlist_entry.dart';
import 'yt_source.dart';

/// The youtube player backend for the web.
YtPlayerBackend createYtPlayerBackend({YtPlayerBackendOptions? options}) =>
    YtIframeBackend(options: options ?? const YtPlayerBackendOptions());

/// Youtube on the web.
///
/// The browser cannot reach youtube's pages or media urls across origins, so
/// neither youtube_explode_dart nor a plain `<video>` can work here. Instead we
/// drive youtube's own iframe player: it expands the playlist for us and we
/// read the ids back out of it with `getPlaylist()`, then queue the videos one
/// by one so shuffle/repeat behave exactly like they do on desktop.
class YtIframeBackend implements YtPlayerBackend {
  /// The iframe api never returns more than 200 entries.
  static const _maxPlaylistEntries = 200;

  /// How this backend should behave.
  final YtPlayerBackendOptions options;

  /// Constructor for [YtIframeBackend].
  YtIframeBackend({this.options = const YtPlayerBackendOptions()});

  /// How long to wait for the iframe to expand a cued playlist.
  static const _playlistTimeout = Duration(seconds: 15);

  /// How long a single `getPlaylist()` round trip is given before retrying.
  static const _playlistPollTimeout = Duration(milliseconds: 1200);

  /// Parallel oembed lookups while filling in the playlist titles.
  static const _metadataConcurrency = 6;

  /// Wait before asking for the duration: the package fires two bridge calls
  /// of its own the moment playback starts, and concurrent calls key their
  /// replies on the current millisecond, so they answer each other.
  static const _durationProbeDelay = Duration(milliseconds: 400);

  /// Give up asking for a duration after this many tries.
  static const _durationProbeAttempts = 5;

  /// Autoplay with sound is blocked unless the page earned the right to it.
  /// If a play request has not taken effect after this, retry it muted.
  static const _autoplayGracePeriod = Duration(milliseconds: 1500);

  late final YoutubePlayerController _controller;

  final _playback = ValueNotifier(const YtPlaybackState());
  final _completions = StreamController<void>.broadcast();
  final _http = http.Client();

  StreamSubscription<YoutubePlayerValue>? _valueSubscription;
  StreamSubscription<YoutubeVideoState>? _videoStateSubscription;
  PlayerState _lastPlayerState = PlayerState.unknown;
  Timer? _autoplayWatchdog;
  Timer? _durationProbe;
  var _durationProbesLeft = 0;

  /// Bumped on every [resolve] so the background title lookups of an
  /// abandoned playlist cannot write into the new one.
  int _resolveGeneration = 0;

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
    // Without youtube's own controls the iframe gets neither the pointer nor
    // the keyboard, so flutter keeps the focus and the arrow keys reach the
    // app rather than being swallowed by the player.
    final showControls = options.showControls;
    _controller = YoutubePlayerController(
      params: YoutubePlayerParams(
        showControls: showControls,
        showFullscreenButton: false,
        enableCaption: showControls,
        enableKeyboard: showControls,
        pointerEvents: showControls ? PointerEvents.auto : PointerEvents.none,
        strictRelatedVideos: true,
      ),
    );
    _valueSubscription = _controller.stream.listen(_onValue);
    _videoStateSubscription = _controller.videoStateStream.listen((state) {
      _playback.value = _playback.value.copyWith(position: state.position);
    });
  }

  void _onValue(YoutubePlayerValue value) {
    final state = value.playerState;
    // Deliberately not taking the duration from `value.metaData`: it lands
    // late, if at all, and still holds the previous video right after a
    // switch. [_scheduleDurationProbe] is the only thing that sets it.
    _playback.value = _playback.value.copyWith(
      playing: state == PlayerState.playing,
      buffering: state == PlayerState.buffering,
      playbackRate: value.playbackRate,
    );

    // Only actually playing clears the watchdog: a blocked autoplay still
    // reports buffering on its way back to unstarted.
    if (state == PlayerState.playing) {
      _autoplayWatchdog?.cancel();
      _autoplayWatchdog = null;
    }

    // The duration never arrives on its own here, see [_scheduleDurationProbe].
    if (state == PlayerState.playing &&
        _playback.value.duration == Duration.zero) {
      _scheduleDurationProbe();
    }

    final metaData = value.metaData;
    if (metaData.videoId.isNotEmpty) {
      onEntryMetadata?.call(
        YtPlaylistEntry(
          videoId: metaData.videoId,
          title: metaData.title.isEmpty ? null : metaData.title,
          author: metaData.author.isEmpty ? null : metaData.author,
          duration: metaData.duration > Duration.zero
              ? metaData.duration
              : null,
        ),
      );
    }

    if (value.error != YoutubeError.none) {
      onPlaybackError?.call('Youtube player error: ${value.error.name}');
    }

    if (state == PlayerState.ended && _lastPlayerState != PlayerState.ended) {
      if (!_completions.isClosed) _completions.add(null);
    }
    _lastPlayerState = state;
  }

  @override
  Future<YtResolvedPlaylist> resolve(YtSource source) async {
    final generation = ++_resolveGeneration;
    switch (source) {
      case YtVideoSource(:final videoId):
        final entry = YtPlaylistEntry(videoId: videoId);
        unawaited(_fillMetadata([entry], generation));
        return YtResolvedPlaylist(entries: [entry]);
      case YtPlaylistSource():
        return _resolvePlaylist(source, generation);
    }
  }

  Future<YtResolvedPlaylist> _resolvePlaylist(
    YtPlaylistSource source,
    int generation,
  ) async {
    // Cueing (rather than loading) expands the playlist inside the iframe
    // without starting playback.
    await _cuePlaylistById(source.playlistId);
    final ids = await _readPlaylistIds();
    if (ids.isEmpty) {
      final startVideoId = source.startVideoId;
      if (startVideoId != null) {
        final entry = YtPlaylistEntry(videoId: startVideoId);
        unawaited(_fillMetadata([entry], generation));
        return YtResolvedPlaylist(entries: [entry]);
      }
      throw YtResolveException(
        'Could not read playlist ${source.playlistId}. It may be private, '
        'empty, or not embeddable.',
      );
    }

    final entries = [
      for (final id in ids.take(_maxPlaylistEntries))
        YtPlaylistEntry(videoId: id),
    ];
    final startIndex = _startIndexOf(source, entries);

    // Drop the iframe's own queue so it never auto-advances behind our back:
    // from here on we hand it one video at a time.
    await _controller.cueVideoById(videoId: entries[startIndex].videoId);

    unawaited(_fillMetadata(entries, generation));
    return YtResolvedPlaylist(
      entries: entries,
      title: await _playlistTitle(source.playlistId),
      startIndex: startIndex,
    );
  }

  /// The packaged `cuePlaylist` sends `list` as a one element array, which the
  /// iframe api expects to be the playlist id string, so call it by hand.
  Future<void> _cuePlaylistById(String playlistId) async {
    // Any bridged call resolves once the iframe player is ready; the raw
    // javascript below does not wait on its own.
    await _controller.playerState;
    final args = jsonEncode({'list': playlistId, 'listType': 'playlist'});
    await _controller.webViewController.runJavaScript(
      'player.cuePlaylist($args);',
    );
  }

  /// Polls the iframe until it has expanded the cued playlist.
  ///
  /// `getPlaylist()` answers `undefined` until the playlist is in, and the
  /// bridge drops an `undefined` result instead of replying, so a call made
  /// too early never comes back at all: every poll needs its own timeout.
  Future<List<String>> _readPlaylistIds() async {
    final deadline = DateTime.now().add(_playlistTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final ids = await _controller.playlist.timeout(
        _playlistPollTimeout,
        onTimeout: () => const <String>[],
      );
      if (ids.isNotEmpty) return ids;
    }
    return const [];
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

  /// Youtube's oembed endpoint is the one youtube url a browser is allowed to
  /// read: it answers with `access-control-allow-origin`. It gives us a title
  /// and an author, but no duration.
  Future<Map<String, dynamic>?> _oEmbed(String youtubeUrl) async {
    final uri = Uri.https('www.youtube.com', '/oembed', {
      'url': youtubeUrl,
      'format': 'json',
    });
    try {
      final response = await _http.get(uri);
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on Exception {
      return null;
    }
  }

  Future<String?> _playlistTitle(String playlistId) async {
    final json = await _oEmbed(
      'https://www.youtube.com/playlist?list=$playlistId',
    );
    return json?['title'] as String?;
  }

  /// Fills in the entry titles in the background, a few at a time.
  Future<void> _fillMetadata(
    List<YtPlaylistEntry> entries,
    int generation,
  ) async {
    for (var start = 0; start < entries.length; start += _metadataConcurrency) {
      if (generation != _resolveGeneration) return;
      final chunk = entries.skip(start).take(_metadataConcurrency);
      await Future.wait(
        chunk.map((entry) => _fillEntryMetadata(entry, generation)),
      );
    }
  }

  Future<void> _fillEntryMetadata(YtPlaylistEntry entry, int generation) async {
    final json = await _oEmbed(
      'https://www.youtube.com/watch?v=${entry.videoId}',
    );
    if (json == null || generation != _resolveGeneration) return;
    onEntryMetadata?.call(
      YtPlaylistEntry(
        videoId: entry.videoId,
        title: json['title'] as String?,
        author: json['author_name'] as String?,
      ),
    );
  }

  @override
  Future<void> open(YtPlaylistEntry entry, {bool autoPlay = true}) async {
    _durationProbe?.cancel();
    _durationProbe = null;
    _durationProbesLeft = _durationProbeAttempts;
    _playback.value = _playback.value.copyWith(
      position: Duration.zero,
      duration: Duration.zero,
      buffering: true,
    );
    if (autoPlay) {
      await _controller.loadVideoById(videoId: entry.videoId);
      _armAutoplayWatchdog();
    } else {
      await _controller.cueVideoById(videoId: entry.videoId);
    }
  }

  /// Asks the player how long the video is.
  ///
  /// The package would normally publish this as part of its metadata, but it
  /// reads the duration and the video data in parallel and the two replies get
  /// mixed up, so neither lands. Ask for it on its own instead.
  void _scheduleDurationProbe() {
    if (_durationProbe != null || _durationProbesLeft <= 0) return;
    _durationProbesLeft--;
    _durationProbe = Timer(_durationProbeDelay, () async {
      _durationProbe = null;
      final seconds = await _controller.duration.timeout(
        _playlistPollTimeout,
        onTimeout: () => 0,
      );
      if (seconds <= 0) {
        if (_playback.value.playing) _scheduleDurationProbe();
        return;
      }
      _playback.value = _playback.value.copyWith(
        duration: Duration(milliseconds: (seconds * 1000).round()),
      );
    });
  }

  @override
  Future<void> play() async {
    await _controller.playVideo();
    _armAutoplayWatchdog();
  }

  /// Browsers refuse to start an unmuted video without a user gesture in the
  /// iframe itself. When that happens nothing moves and no error is raised, so
  /// fall back to muted playback and let the ui offer an unmute button.
  void _armAutoplayWatchdog() {
    _autoplayWatchdog?.cancel();
    _autoplayWatchdog = Timer(_autoplayGracePeriod, () async {
      _autoplayWatchdog = null;
      if (_playback.value.muted) return;
      if (await _controller.playerState == PlayerState.playing) return;
      await setMuted(true);
      await _controller.playVideo();
    });
  }

  @override
  Future<void> pause() async {
    _autoplayWatchdog?.cancel();
    _autoplayWatchdog = null;
    await _controller.pauseVideo();
  }

  @override
  Future<void> seek(Duration position) async {
    // Reflect the jump right away: a fast chain of arrow taps measures the
    // next step from here, and the ticking position only lands every 100ms.
    _playback.value = _playback.value.copyWith(position: position);
    // Not `_controller.seekTo`: that one hands the iframe an object where the
    // youtube api wants plain seconds, and the player quietly rewinds to 0.
    await _controller.webViewController.runJavaScript(
      'player.seekTo(${position.inMilliseconds / 1000});',
    );
  }

  @override
  Future<void> setMuted(bool muted) async {
    _autoplayWatchdog?.cancel();
    _autoplayWatchdog = null;
    if (muted) {
      await _controller.mute();
      _playback.value = _playback.value.copyWith(muted: true);
      return;
    }

    final wasPlaying = _playback.value.playing;
    await _controller.unMute();
    _playback.value = _playback.value.copyWith(muted: false);
    if (wasPlaying) _armSoundWatchdog();
  }

  /// Recovers from an unmute the browser will not allow.
  ///
  /// A video that only got to play because it was muted stops dead the moment
  /// the sound comes back on, and no `playVideo()` revives it: the iframe
  /// needs a click of its own, which it never gets because the flutter side
  /// owns the pointer. Put the sound back off and carry on playing rather than
  /// leaving a frozen picture behind.
  void _armSoundWatchdog() {
    _autoplayWatchdog = Timer(_autoplayGracePeriod, () async {
      _autoplayWatchdog = null;
      if (await _controller.playerState == PlayerState.playing) return;
      await _controller.mute();
      _playback.value = _playback.value.copyWith(
        muted: true,
        soundBlocked: true,
      );
      await _controller.playVideo();
    });
  }

  @override
  Widget buildVideoView(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // The caller already sized the box for the wanted fit, so hand the
      // iframe that exact ratio instead of letting it letterbox again.
      final sized =
          constraints.maxWidth.isFinite &&
          constraints.maxHeight.isFinite &&
          constraints.maxHeight > 0;
      return YoutubePlayer(
        controller: _controller,
        aspectRatio: sized
            ? constraints.maxWidth / constraints.maxHeight
            : 16 / 9,
        autoFullScreen: false,
        enableFullScreenOnVerticalDrag: false,
      );
    },
  );

  @override
  Future<void> dispose() async {
    _autoplayWatchdog?.cancel();
    _durationProbe?.cancel();
    await _valueSubscription?.cancel();
    await _videoStateSubscription?.cancel();
    await _completions.close();
    await _controller.close();
    _http.close();
    _playback.dispose();
  }
}
