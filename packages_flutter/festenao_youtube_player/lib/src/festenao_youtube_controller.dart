import 'package:festenao_common_flutter/common_utils.dart';
import 'package:festenao_youtube_player/player.dart';

/// Festenao Youtube Player options
class FesteneaoYoutubeOptions {
  /// The video ID of the YouTube video to be played.
  final String videoId;

  /// Whether to automatically play the video when the player is ready.
  final bool autoPlay;

  /// Whether to show the video controls.
  final bool showControls;

  /// Constructor for FestenaoYoutubeOptions.
  FesteneaoYoutubeOptions({
    required this.videoId,
    this.autoPlay = false,
    this.showControls = true,
  });
}

/// Base controller helper
abstract class FestenaoYoutubeControllerBase extends AutoDisposerableBase
    implements FestenaoYoutubeController {
  late final _stateSubject = audiAddBehaviorSubject(
    BehaviorSubject<FestenaoYoutubePlayerState>.seeded(
      FestenaoYoutubePlayerState(status: FestenaoYoutubePlayerStatus.unknown),
    ),
  );

  /// Current state of the Youtube player.
  FestenaoYoutubePlayerState get state => _stateSubject.value;
  @override
  ValueStream<FestenaoYoutubePlayerState> get stateStream =>
      _stateSubject.stream;

  /// Add a state from the implementation
  void addState(FestenaoYoutubePlayerState state) {
    _stateSubject.add(state);
  }
}

/// Abstract class for the Festenao Youtube controller.
abstract class FestenaoYoutubeController implements AutoDisposable {
  /// The options for the Youtube player.
  FesteneaoYoutubeOptions get options;
  // Add your controller properties and methods here

  /// Trigger the play action
  void play() {
    // Logic to play the video
  }

  /// Trigger the pause action
  void pause() {
    // Logic to pause the video
  }

  /// Trigger the stop action
  void stop() {
    // Logic to stop the video
  }

  /// state stream
  Stream<FestenaoYoutubePlayerState> get stateStream;

  /// Constructor for FestenaoYoutubeController.
  factory FestenaoYoutubeController({
    required FesteneaoYoutubeOptions options,
  }) {
    return festenaoYoutubePlayerService.newController(options: options);
  }

  /// Seek to a specific position in the video.
  ///
  /// allowSeekAhead: If true, the player may seek ahead to a position that is not yet buffered.
  void seekTo(Duration duration, {bool allowSeekAhead = false});
}
