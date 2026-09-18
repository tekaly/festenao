import 'package:festenao_common/festenao_api.dart';

import 'import.dart';

/// A clock synchronized with the server, so every device (tv, controller,
/// players) agrees on the quiz timing.
///
/// The offset with the server time is measured through
/// [TkCmsTimestampProvider.fetchNow] (an api service is one) and refreshed
/// regularly once [run] is called; without provider the local time is used.
class QuizzTimeService {
  final TkCmsTimestampProvider? _timestampProviderOrNull;
  final _offsetSubject = BehaviorSubject<int>();

  /// Creates a time service, local only when [timestampProvider] is null.
  QuizzTimeService({TkCmsTimestampProvider? timestampProvider})
    : _timestampProviderOrNull = timestampProvider {
    if (timestampProvider == null) {
      _needFix = false;
      _offsetSubject.add(0);
    }
  }

  /// A local only time service.
  factory QuizzTimeService.local() => QuizzTimeService();

  /// The offset changes (server - local, in ms).
  Stream<int> get offsetStream => _offsetSubject.stream;

  /// The current server time.
  DateTime get timestamp => DateTime.timestamp().add(
    Duration(milliseconds: offsetFromServerTimestampMs),
  );

  /// The current server time in epoch ms.
  int get timestampMs => timestamp.millisecondsSinceEpoch;

  /// Completes once the offset has been measured at least once.
  Future<void> get fixedOnce async => await _offsetSubject.first;

  var _needFix = true;
  final _lock = Lock();
  var _running = false;
  var _disposed = false;

  /// The offset with the server (server - local, in ms), can be restored
  /// from prefs in offline mode.
  var offsetFromServerTimestampMs = 0;

  /// Sets a known offset (restored from prefs).
  set offsetFromServer(int offsetMs) {
    offsetFromServerTimestampMs = offsetMs;
    _offsetSubject.add(offsetMs);
  }

  /// Starts the periodic synchronization (no-op without provider).
  void run() {
    if (_running || _timestampProviderOrNull == null) {
      return;
    }
    _running = true;
    // Auto sync every minutes
    () async {
      while (!_disposed) {
        await fixTimestamp();
        if (_needFix) {
          await sleep(10000);
        } else {
          await sleep(60 * 60 * 1000);
        }
      }
    }().unawait();

    // Check time change every seconds
    () async {
      while (!_disposed) {
        var before = DateTime.timestamp();
        await sleep(1000);
        var after = DateTime.timestamp();
        var diff = after.difference(before).inMilliseconds;
        if (diff.abs() > 5000) {
          _needFix = true;
          await fixTimestamp();
        }
      }
    }().unawait();
  }

  /// Measures the offset once (no-op if already measuring or without
  /// provider).
  Future<void> fixTimestamp() async {
    if (_timestampProviderOrNull == null) {
      return;
    }
    if (!_lock.locked) {
      await _lock.synchronized(() async {
        await _fixTimestamp();
      });
    }
  }

  Future<void> _fixTimestamp() async {
    var sleepMs = 1000;
    var provider = _timestampProviderOrNull!;
    while (!_disposed) {
      try {
        var before = DateTime.timestamp();
        var serverTime = await provider.fetchNow();
        var after = DateTime.timestamp();

        var diff = after.difference(before).inMilliseconds;
        var now = before.add(Duration(milliseconds: diff ~/ 2));

        var offsetMs = serverTime.difference(now).inMilliseconds;
        if (isDebug) {
          // ignore: avoid_print
          print(
            '[time_sync] server: $serverTime, local: $now, offset: $offsetMs, diff: $diff',
          );
        }
        // less than 1 second, take it
        if (diff < 1000 || offsetMs > diff) {
          _needFix = false;
          offsetFromServerTimestampMs = offsetMs;
          _offsetSubject.add(offsetMs);
          break;
        }
      } catch (e, st) {
        if (isDebug) {
          // ignore: avoid_print
          print('[time_sync] error $e');
          // ignore: avoid_print
          print(st);
        }
      }
      await sleep(sleepMs);
      sleepMs = (sleepMs * 1.5).toInt().boundedMax(60000);
    }
  }

  /// Stops the synchronization.
  void dispose() {
    _disposed = true;
    _offsetSubject.close();
  }
}
