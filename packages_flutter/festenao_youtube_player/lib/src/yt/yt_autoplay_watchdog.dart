import 'dart:async';

/// What [YtAutoplayWatchdog] sees of the player when it looks.
enum YtAutoplayProbe {
  /// The video advances: all is well.
  playing,

  /// Still loading (buffering, or no news yet): too early to tell.
  loading,

  /// Not playing and not loading (unstarted, cued, paused): the browser
  /// refused to play.
  stopped,
}

/// Watches a play request the browser may refuse without a word: a request
/// that has not taken effect after a while is reported through [onBlocked].
///
/// A video is not refused just because it is slow to start, so the watchdog
/// only decides on a settled state: while the player is still loading it
/// looks again, until [arm]'s `maxWait` runs out, and then lets it be.
class YtAutoplayWatchdog {
  /// What the player is doing right now.
  final YtAutoplayProbe Function() probe;

  /// Called once when the request is found refused.
  final Future<void> Function() onBlocked;

  Timer? _timer;
  var _generation = 0;

  /// A watchdog over [probe].
  YtAutoplayWatchdog({required this.probe, required this.onBlocked});

  /// True while a request is watched.
  bool get armed => _timer != null;

  /// Look after [firstCheck]; while still loading, look again every
  /// [recheck] until [maxWait] has passed since the arming.
  ///
  /// A new [arm] replaces the previous watch.
  void arm({
    required Duration firstCheck,
    Duration recheck = const Duration(seconds: 1),
    required Duration maxWait,
  }) {
    cancel();
    var generation = ++_generation;
    var waited = Duration.zero;
    void schedule(Duration delay) {
      _timer = Timer(delay, () async {
        _timer = null;
        if (generation != _generation) {
          return;
        }
        waited += delay;
        switch (probe()) {
          case YtAutoplayProbe.playing:
            return;
          case YtAutoplayProbe.loading:
            if (waited + recheck <= maxWait) {
              schedule(recheck);
            }
            return;
          case YtAutoplayProbe.stopped:
            await onBlocked();
            return;
        }
      });
    }

    schedule(firstCheck);
  }

  /// Stop watching (the request took effect, or was superseded).
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _generation++;
  }
}
