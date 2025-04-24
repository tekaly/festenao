import 'package:festenao_common_flutter/common_utils_flutter.dart';
import 'package:festenao_youtube_player/player.dart';
import 'package:flutter/material.dart';
import 'package:y_player/y_player.dart';

/// Y Player controller for Festenao
class FestenaoYPlayerController extends FestenaoYoutubeControllerBase {
  @override
  final FesteneaoYoutubeOptions options;
  final _completer = Completer<void>();

  /// The video ID of the YouTube video to be played.
  String get videoId => options.videoId;
  YPlayerController? _yPlayerController;

  /// The native controller for the Youtube player
  YPlayerController? get yPlayerController => _yPlayerController;
  set yPlayerController(YPlayerController? value) {
    _yPlayerController = value;
    _completer.complete();
    // devPrint('New FestenaoYPlayerController');
  }

  /// Any second call will crash
  late FestenaoYPlayer player;

  /// Constructor for FestenaoYPlayerController.
  FestenaoYPlayerController({required this.options}) {
    if (options.autoPlay) {
      ready.then((_) {
        yPlayerController?.play();
      });
    }
  }

  @override
  void play() {
    yPlayerController?.play();
    // Logic to play the video
  }

  @override
  void pause() {
    yPlayerController?.pause();
    // Logic to pause the video
  }

  @override
  void stop() {
    yPlayerController?.stop();
    // Logic to stop the video
  }

  /// ready
  Future<void> get ready async {
    await _completer.future;
  }

  /// Called by the player
  void onProgressChanged(Duration position, Duration duration) {
    addState(state.copyWith(duration: duration, position: position));

    // print('Progress: ${position.inMilliseconds}/${duration.inMilliseconds}');
  }

  static const _statusMap = {
    YPlayerStatus.initial: FestenaoYoutubePlayerStatus.unknown,
    YPlayerStatus.loading: FestenaoYoutubePlayerStatus.loading,
    YPlayerStatus.playing: FestenaoYoutubePlayerStatus.playing,
    YPlayerStatus.paused: FestenaoYoutubePlayerStatus.paused,
    YPlayerStatus.stopped: FestenaoYoutubePlayerStatus.ended,
    YPlayerStatus.error: FestenaoYoutubePlayerStatus.error,
  };

  /// Called by the player
  void onStateChanged(YPlayerStatus status) {
    addState(
      state.copyWith(
        status: _statusMap[status] ?? FestenaoYoutubePlayerStatus.unknown,
      ),
    );
    // print('Player Status: $status');
  }

  @override
  void seekTo(Duration duration, {bool allowSeekAhead = false}) {
    /*yPlayerController?.stop()seekTo(
      duration: duration,
      allowSeekAhead: allowSeekAhead,
    );*/
  }
}

/// Y Player for Festenao
class FestenaoYPlayer extends StatefulWidget {
  /// The controller for the Youtube player.
  final FestenaoYoutubeController controller;

  /// Constructor for FestenaoYPlayer.
  FestenaoYPlayer({super.key, required this.controller}) {
    (controller as FestenaoYPlayerController?)?.player = this;
  }

  @override
  State<FestenaoYPlayer> createState() => _FestenaoYPlayerState();
}

class _FestenaoYPlayerState extends AutoDisposeBaseState<FestenaoYPlayer> {
  FestenaoYPlayerController get yController =>
      widget.controller as FestenaoYPlayerController;
  @override
  Widget build(BuildContext context) {
    return YPlayer(
      onControllerReady: (controller) {
        yController.yPlayerController = controller;
        // print('Controller is ready!');
      },
      // videoId
      youtubeUrl: 'https://www.youtube.com/watch?v=${yController.videoId}',
      onStateChanged: (status) {
        yController.onStateChanged(status);
        // print('Player Status: $status');
      },
      onProgressChanged: (position, duration) {
        yController.onProgressChanged(position, duration);
        // print('Progress: ${position.inSeconds}/${duration.inSeconds}');
      },
    );
  }
}

class _FestenaoYoutubeYPlayerService extends FestenaoYoutubePlayerService {
  @override
  FestenaoYoutubeController newController({
    required FesteneaoYoutubeOptions options,
  }) {
    return FestenaoYPlayerController(options: options);
  }

  @override
  Widget newPlayer({Key? key, required FestenaoYoutubeController controller}) {
    return FestenaoYPlayer(key: key, controller: controller);
  }
}

/// Festenao Youtube Player Service using y_player
FestenaoYoutubePlayerService festenaoYoutubeYPlayerService =
    _FestenaoYoutubeYPlayerService();
