import 'package:fake_async/fake_async.dart';
import 'package:festenao_youtube_player/src/yt/yt_autoplay_watchdog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late YtAutoplayProbe probe;
  var blocked = 0;
  late YtAutoplayWatchdog watchdog;

  setUp(() {
    probe = YtAutoplayProbe.loading;
    blocked = 0;
    watchdog = YtAutoplayWatchdog(
      probe: () => probe,
      onBlocked: () async => blocked++,
    );
  });

  void arm() => watchdog.arm(
    firstCheck: const Duration(seconds: 2),
    recheck: const Duration(seconds: 1),
    maxWait: const Duration(seconds: 5),
  );

  test('a stopped player is reported at the first check', () {
    fakeAsync((async) {
      probe = YtAutoplayProbe.stopped;
      arm();
      async.elapse(const Duration(milliseconds: 1999));
      expect(blocked, 0);
      expect(watchdog.armed, isTrue);
      async.elapse(const Duration(milliseconds: 1));
      expect(blocked, 1);
      expect(watchdog.armed, isFalse);
      // Reported once.
      async.elapse(const Duration(seconds: 10));
      expect(blocked, 1);
    });
  });

  test('a slow start is given time', () {
    fakeAsync((async) {
      arm();
      async.elapse(const Duration(seconds: 3));
      expect(blocked, 0);
      expect(watchdog.armed, isTrue);
      probe = YtAutoplayProbe.playing;
      async.elapse(const Duration(seconds: 1));
      expect(blocked, 0);
      expect(watchdog.armed, isFalse);
    });
  });

  test('stopped after loading is reported', () {
    fakeAsync((async) {
      arm();
      async.elapse(const Duration(seconds: 3));
      probe = YtAutoplayProbe.stopped;
      async.elapse(const Duration(seconds: 1));
      expect(blocked, 1);
    });
  });

  test('still loading at the end of the wait is let be', () {
    fakeAsync((async) {
      arm();
      async.elapse(const Duration(seconds: 5));
      expect(watchdog.armed, isFalse);
      probe = YtAutoplayProbe.stopped;
      async.elapse(const Duration(seconds: 10));
      expect(blocked, 0);
    });
  });

  test('cancel and re-arm', () {
    fakeAsync((async) {
      probe = YtAutoplayProbe.stopped;
      arm();
      async.elapse(const Duration(seconds: 1));
      watchdog.cancel();
      expect(watchdog.armed, isFalse);
      async.elapse(const Duration(seconds: 5));
      expect(blocked, 0);
      arm();
      async.elapse(const Duration(seconds: 1));
      // Re-armed before the check: the clock restarts.
      arm();
      async.elapse(const Duration(seconds: 1));
      expect(blocked, 0);
      async.elapse(const Duration(seconds: 1));
      expect(blocked, 1);
    });
  });
}
