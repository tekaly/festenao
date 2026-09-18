import 'quizz_text.dart';

/// The timing of a step (pre, question, pause...): a start and an end in
/// epoch milliseconds, optionally paused.
class QuizProgressController {
  /// The start, epoch ms.
  final int? startMs;

  /// The end, epoch ms.
  final int? endMs;

  /// The duration.
  int get durationMs => endMs! - startMs!;

  /// The pause time, epoch ms, null if not paused.
  final int? pausedMs;

  /// The elapsed time if paused.
  int get elapedMs => pausedMs! - startMs!;

  /// True if both start and end are set.
  bool get isValid => endMs != null && startMs != null;

  /// True if paused.
  bool get isPaused => pausedMs != null;

  /// The progress (0 to 1) if paused.
  double get pausedProgress => pausedProgressMs / durationMs;

  /// The elapsed time if paused.
  int get pausedProgressMs => pausedMs! - startMs!;

  /// The progress (0 to 1) at [timestampMs] if playing.
  double getPlayingProgress(int timestampMs) =>
      startMs == null ? 0 : (timestampMs - startMs!) / durationMs;

  /// The remaining time at [timestampMs] if playing.
  int getPlayingRemainingMs(int timestampMs) => endMs! - timestampMs;

  /// The progress (0 to 1) at [timestampMs], paused or playing.
  double getProgress(int timestampMs) =>
      isPaused ? pausedProgress : getPlayingProgress(timestampMs);

  /// Creates a controller.
  QuizProgressController({
    required this.startMs,
    required this.endMs,
    this.pausedMs,
  });

  /// An invalid controller.
  factory QuizProgressController.invalid() =>
      QuizProgressController(startMs: null, endMs: null);

  @override
  String toString() => isValid
      ? '${quizzFormatMs(startMs!)} - ${quizzFormatMs(endMs!)}${isPaused ? ' (${quizzFormatMs(pausedMs!)})' : ''}'
      : '-- not valid --';

  /// The remaining time at [timestampMs], paused or playing.
  int getRemainingMs(int timestampMs) =>
      isPaused ? pausedRemainingMs : getPlayingRemainingMs(timestampMs);

  /// The remaining time if paused.
  int get pausedRemainingMs => durationMs - pausedProgressMs;
}

bool _matchProgress(double progress1, double progress2) {
  if (progress2 == 0) {
    return _matchRatio(progress1);
  } else {
    return _matchRatio(progress1 / progress2);
  }
}

bool _matchRatio(double ratio) {
  if ((ratio - 1).abs() < 0.001) {
    return true;
  }
  return false;
}

/// True if two controllers have the same progress at [ms], to avoid
/// re-emitting an equivalent controller.
bool progressControllersMatch(
  int ms,
  QuizProgressController? controller1,
  QuizProgressController? controller2,
) {
  if (controller1 == null) {
    if (controller2 == null) {
      return true;
    } else {
      return false;
    }
  } else {
    if (controller2 == null) {
      return false;
    } else {
      if (controller1.isPaused) {
        if (controller2.isPaused) {
          var progress1 = controller1.pausedProgress;
          var progress2 = controller2.pausedProgress;
          return _matchProgress(progress1, progress2);
        } else {
          return false;
        }
      } else {
        if (controller2.isPaused) {
          return false;
        }
        var progress1 = controller1.getPlayingProgress(ms);
        var progress2 = controller2.getPlayingProgress(ms);
        return _matchProgress(progress1, progress2);
      }
    }
  }
}
