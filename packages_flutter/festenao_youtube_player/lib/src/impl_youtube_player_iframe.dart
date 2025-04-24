import 'package:festenao_common_flutter/common_utils_flutter.dart';
import 'package:festenao_youtube_player/player.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Festenao Youtube Player i frame controller
class FestenaoYoutubeIframePlayerController
    extends FestenaoYoutubeControllerBase {
  /// Options
  @override
  final FesteneaoYoutubeOptions options;

  /// The video ID of the YouTube video to be played.
  String get videoId => options.videoId;

  /// The initial duration
  Duration duration = Duration.zero;

  /// The native controller for the Youtube player
  late final controller = YoutubePlayerController.fromVideoId(
    videoId: videoId,
    params: YoutubePlayerParams(
      showControls: options.showControls,
      showFullscreenButton: false,
    ),
  );

  static const _statusMap = {
    PlayerState.unknown: FestenaoYoutubePlayerStatus.playing, // ? to report
    PlayerState.unStarted: FestenaoYoutubePlayerStatus.loading,
    PlayerState.ended: FestenaoYoutubePlayerStatus.ended,
    PlayerState.playing: FestenaoYoutubePlayerStatus.playing,
    PlayerState.paused: FestenaoYoutubePlayerStatus.paused,
    PlayerState.buffering: FestenaoYoutubePlayerStatus.buffering,
    PlayerState.cued: FestenaoYoutubePlayerStatus.ready,
  };

  /// Constructor for FestenaoYoutubeIframePlayerController.
  FestenaoYoutubeIframePlayerController({required this.options}) {
    audiAddStreamSubscription(
      controller.stream.listen((event) {
        var playbackRate = event.playbackRate;
        var state = event.playerState;
        var status = _statusMap[state] ?? FestenaoYoutubePlayerStatus.unknown;
        /*print('state: $state');
        print('invalid duration: ${event.metaData.duration}');
        print('duration: $duration');
        print('playback rate: ${event.playbackRate}');*/
        // devPrint('YoutubePlayerIframePlayerController: $event');
        addState(
          this.state.copyWith(status: status, playbackRate: playbackRate),
        );
      }),
    );
    controller.videoStateStream.listen((event) {
      var position = event.position;
      addState(state.copyWith(position: position));
      // devPrint('videoStateStream: ${event.position}');
    });
    if (options.autoPlay) {
      ready.then((_) async {
        // devPrint('AutoPlay');
        await controller.playVideo();
      });
    }
  }

  /// Any second call will crash

  // Add your controller properties and methods here

  @override
  void play() {
    // devPrint("play ${controller}");
    controller.playVideo();
    // Logic to play the video
  }

  @override
  void pause() {
    //devPrint("pause ${webController.position}");
    controller.pauseVideo();
    // Logic to pause the video
  }

  /// Set to false during drag and true on release
  @override
  void seekTo(Duration duration, {bool allowSeekAhead = false}) {
    controller.seekTo(
      seconds: duration.inMilliseconds / 1000,
      allowSeekAhead: allowSeekAhead,
    );
    // Logic to seek to a specific time in the video
  }

  @override
  void stop() {
    controller.stopVideo();
    // Logic to stop the video
  }

  /// True when ready
  Future<void> get ready async {
    await controller.stream.firstWhere((event) {
      // print('ready: $event');
      if (event.playerState == PlayerState.cued) {
        return true;
      }
      return false;
    });
    duration = Duration(
      milliseconds: ((await controller.duration) * 1000).toInt(),
    );
    addState(state.copyWith(duration: duration));
    // Logic to prepare the player
  }
}

/// Festenao Youtube Iframe Player
class FestenaoYoutubeIframePlayer extends StatefulWidget {
  /// controller
  final FestenaoYoutubeController controller;

  /// Constructor for FestenaoYoutubeIframePlayer.
  const FestenaoYoutubeIframePlayer({super.key, required this.controller});

  @override
  State<FestenaoYoutubeIframePlayer> createState() =>
      _FestenaoYoutubeIframePlayerState();
}

class _FestenaoYoutubeIframePlayerState
    extends AutoDisposeBaseState<FestenaoYoutubeIframePlayer> {
  FestenaoYoutubeIframePlayerController get _controller =>
      widget.controller as FestenaoYoutubeIframePlayerController;

  // Declare a controller for interacting with the YouTube video player
  YoutubePlayerController get _implController => _controller.controller;

  @override
  void initState() {
    // Add a listener to track changes in video playback position
    //_implController.addListener(_positionListener);
    // Call the superclass method to ensure proper initialization
    super.initState();
  }

  @override
  void dispose() {
    // Remove the listener when the widget is disposed to avoid memory leaks
    //_implController.removeListener(_positionListener);
    // Call the superclass method to ensure proper disposal
    super.dispose();
  }

  // Listener method that prints the current video playback position to the console
  // ignore: unused_element
  void _positionListener() {
    //print("position: ${_implController!.position}");
  }

  @override
  Widget build(BuildContext context) {
    return PlayerWidget(controller: _implController);
  }
}

/// Empbedded player
class PlayerWidget extends StatelessWidget {
  /// The Youtube player controller.
  final YoutubePlayerController controller;

  ///
  const PlayerWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(controller: controller);
  }
}

class _FestenaoYoutubePlayerIframeService extends FestenaoYoutubePlayerService {
  @override
  FestenaoYoutubeController newController({
    required FesteneaoYoutubeOptions options,
  }) {
    return FestenaoYoutubeIframePlayerController(options: options);
  }

  @override
  Widget newPlayer({Key? key, required FestenaoYoutubeController controller}) {
    return FestenaoYoutubeIframePlayer(key: key, controller: controller);
  }
}

/// Festenao Youtube Player Iframe Service
FestenaoYoutubePlayerService festenaoYoutubePlayerIframeService =
    _FestenaoYoutubePlayerIframeService();
