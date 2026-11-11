import 'dart:async';

import 'package:festenao_common/festenao_quizz.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_api.dart';

/// A server whose clock is [offset] from the local one, answering after
/// [roundTrip].
class _TestTimestampProvider implements TkCmsTimestampProvider {
  final Duration offset;
  final Duration roundTrip;

  _TestTimestampProvider({required this.offset, required this.roundTrip});

  @override
  Future<DateTime> fetchNow() async {
    await Future<void>.delayed(roundTrip);
    return DateTime.timestamp().add(offset).subtract(roundTrip ~/ 2);
  }
}

void main() {
  group('QuizzTimeService', () {
    /// The offset found against a slow server, null when none was found.
    Future<int?> fixOffset(Duration offset) async {
      var timeService = QuizzTimeService(
        timestampProvider: _TestTimestampProvider(
          offset: offset,
          roundTrip: const Duration(milliseconds: 1200),
        ),
      );
      try {
        await timeService.fixTimestamp().timeout(const Duration(seconds: 6));
        return timeService.offsetFromServerTimestampMs;
      } on TimeoutException {
        return null;
      } finally {
        // Stops the retry loop.
        timeService.dispose();
      }
    }

    test('local', () async {
      var timeService = QuizzTimeService.local();
      await timeService.fixedOnce;
      expect(timeService.offsetFromServerTimestampMs, 0);
      timeService.dispose();
    });

    test('server ahead, slow round trip', () async {
      var offset = await fixOffset(const Duration(hours: 1));
      expect(offset, closeTo(const Duration(hours: 1).inMilliseconds, 2000));
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('no timer left after dispose', () async {
      var timers = <Timer>[];
      late QuizzTimeService timeService;
      runZoned(
        () {
          timeService = QuizzTimeService(
            timestampProvider: _TestTimestampProvider(
              offset: Duration.zero,
              roundTrip: Duration.zero,
            ),
          )..run();
        },
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, callback) {
            var timer = parent.createTimer(zone, duration, callback);
            timers.add(timer);
            return timer;
          },
        ),
      );
      await timeService.fixedOnce;
      // The hourly sync sleep and the 1s clock check are pending.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(timers.where((timer) => timer.isActive), isNotEmpty);
      timeService.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(timers.where((timer) => timer.isActive), isEmpty);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('fixedOnce when disposed first', () async {
      var timeService = QuizzTimeService(
        timestampProvider: _TestTimestampProvider(
          offset: Duration.zero,
          roundTrip: Duration.zero,
        ),
      );
      timeService.dispose();
      await expectLater(
        timeService.fixedOnce,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('disposed'),
          ),
        ),
      );
      // Setting a known offset after dispose is ignored.
      timeService.offsetFromServer = 1000;
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('fixedOnce pending when disposed', () async {
      var timeService = QuizzTimeService(
        timestampProvider: _TestTimestampProvider(
          offset: Duration.zero,
          roundTrip: const Duration(seconds: 10),
        ),
      );
      var future = timeService.fixedOnce;
      unawaited(timeService.fixTimestamp());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      timeService.dispose();
      await expectLater(
        future.timeout(const Duration(seconds: 2)),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('disposed'),
          ),
        ),
      );
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('server behind, slow round trip', () async {
      var offset = await fixOffset(const Duration(hours: -1));
      expect(offset, isNotNull);
      expect(offset, closeTo(const Duration(hours: -1).inMilliseconds, 2000));
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}
