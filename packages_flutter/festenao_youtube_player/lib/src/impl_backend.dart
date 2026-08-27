import 'package:festenao_common_flutter/common_utils_flutter.dart';
import 'package:festenao_youtube_player/player.dart';
import 'package:festenao_youtube_player/yt_player.dart';
import 'package:flutter/material.dart';

/// A [FestenaoYoutubeController] backed by a [YtPlayerBackend].
///
/// One implementation for every platform: the backend is the thing that knows
/// whether it is driving media_kit or youtube's iframe player.
class FestenaoBackendYoutubeController extends FestenaoYoutubeControllerBase {
  @override
  final FesteneaoYoutubeOptions options;

  /// The platform player underneath.
  late final YtPlayerBackend backend = createYtPlayerBackend(
    options: YtPlayerBackendOptions(showControls: options.showControls),
  );

  final _readyCompleter = Completer<void>();
  var _disposed = false;

  /// The video id being played.
  String get videoId => options.videoId;

  /// Completes once the video is loaded and the player can be driven, or once
  /// loading it has failed.
  Future<void> get ready => _readyCompleter.future;

  /// Constructor for [FestenaoBackendYoutubeController].
  FestenaoBackendYoutubeController({required this.options}) {
    // One disposer for the whole backend: the listener has to come off before
    // the backend tears its notifier down, and audiDisposeAll runs the
    // functions in the order they were added.
    audiAddFunction(() {
      backend.playback.removeListener(_onPlayback);
      unawaited(backend.dispose());
    });
    unawaited(_start());
  }

  Future<void> _start() async {
    _publish(state.copyWith(status: FestenaoYoutubePlayerStatus.loading));
    try {
      await backend.initialize();
      if (_disposed) return;
      backend.onPlaybackError = (_) =>
          _publish(state.copyWith(status: FestenaoYoutubePlayerStatus.error));
      backend.playback.addListener(_onPlayback);
      audiAddStreamSubscription(
        backend.completions.listen(
          (_) => _publish(
            state.copyWith(status: FestenaoYoutubePlayerStatus.ended),
          ),
        ),
      );

      await backend.open(
        YtPlaylistEntry(videoId: videoId),
        autoPlay: options.autoPlay,
      );
      if (_disposed) return;
      _publish(state.copyWith(status: FestenaoYoutubePlayerStatus.ready));
    } on Object catch (e) {
      debugPrint('festenao_youtube_player: $e');
      _publish(state.copyWith(status: FestenaoYoutubePlayerStatus.error));
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  /// Adds a state, unless the controller is on its way out and the subject
  /// behind [addState] is already closed.
  void _publish(FestenaoYoutubePlayerState state) {
    if (_disposed) return;
    addState(state);
  }

  /// Republishes the backend state, keeping the
  /// [FestenaoYoutubePlayerStatus.ended] and [FestenaoYoutubePlayerStatus.error]
  /// the transport itself knows nothing about.
  void _onPlayback() {
    final playback = backend.playback.value;
    final status = switch (state.status) {
      FestenaoYoutubePlayerStatus.error ||
      FestenaoYoutubePlayerStatus.ended => state.status,
      _ when playback.buffering => FestenaoYoutubePlayerStatus.buffering,
      _ when playback.playing => FestenaoYoutubePlayerStatus.playing,
      // Nothing has been loaded yet, so this is not a pause.
      FestenaoYoutubePlayerStatus.unknown ||
      FestenaoYoutubePlayerStatus.loading => state.status,
      _ => FestenaoYoutubePlayerStatus.paused,
    };
    _publish(
      state.copyWith(
        status: status,
        position: playback.position,
        duration: playback.duration,
        playbackRate: playback.playbackRate,
      ),
    );
  }

  @override
  void play() {
    // A video that ran to the end is playable again, so drop the `ended`.
    if (state.status == FestenaoYoutubePlayerStatus.ended) {
      _publish(state.copyWith(status: FestenaoYoutubePlayerStatus.playing));
    }
    unawaited(backend.play());
  }

  @override
  void pause() => unawaited(backend.pause());

  @override
  void stop() {
    unawaited(() async {
      await backend.pause();
      await backend.seek(Duration.zero);
    }());
  }

  @override
  void seekTo(Duration duration, {bool allowSeekAhead = false}) {
    // `allowSeekAhead` is an iframe api notion: it says whether the player may
    // ask youtube for a part it has not buffered. Both backends always may, so
    // there is nothing to honour here.
    unawaited(backend.seek(duration));
  }

  @override
  void selfDispose() {
    _disposed = true;
    super.selfDispose();
  }
}

/// The player widget of [FestenaoBackendYoutubeController].
class FestenaoBackendYoutubePlayer extends StatelessWidget {
  /// The controller for the Youtube player.
  final FestenaoYoutubeController controller;

  /// Constructor for [FestenaoBackendYoutubePlayer].
  const FestenaoBackendYoutubePlayer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) =>
      (controller as FestenaoBackendYoutubeController).backend.buildVideoView(
        context,
      );
}

class _FestenaoBackendYoutubePlayerService
    extends FestenaoYoutubePlayerService {
  @override
  FestenaoYoutubeController newController({
    required FesteneaoYoutubeOptions options,
  }) => FestenaoBackendYoutubeController(options: options);

  @override
  Widget newPlayer({Key? key, required FestenaoYoutubeController controller}) =>
      FestenaoBackendYoutubePlayer(key: key, controller: controller);
}

/// Festenao Youtube Player Service, on top of [YtPlayerBackend].
FestenaoYoutubePlayerService festenaoYoutubeBackendPlayerService =
    _FestenaoBackendYoutubePlayerService();
