/// Status of the player
enum FestenaoYoutubePlayerStatus {
  /// The player is in an error state.
  error,

  /// The player is in an unknown state.
  unknown,

  /// The player is loading
  loading,

  /// The player is ready to play.
  ready,

  /// The player is playing the video.
  playing,

  /// The player is paused.
  paused,

  /// The player is buffering.
  buffering,

  /// The player has ended playback.
  ended,
}

/// State
class FestenaoYoutubePlayerState {
  /// Enum state
  final FestenaoYoutubePlayerStatus status;

  /// Position of the video
  final Duration position;

  /// Duration of the video
  final Duration duration;

  /// Playback rate
  final double playbackRate;

  /// Constructor for FestenaoYoutubePlayerState.
  FestenaoYoutubePlayerState({
    required this.status,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playbackRate = 1.0,
  });

  /// Clone a state
  FestenaoYoutubePlayerState copyWith({
    FestenaoYoutubePlayerStatus? status,
    Duration? position,
    Duration? duration,
    double? playbackRate,
  }) {
    return FestenaoYoutubePlayerState(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playbackRate: playbackRate ?? this.playbackRate,
    );
  }
}
