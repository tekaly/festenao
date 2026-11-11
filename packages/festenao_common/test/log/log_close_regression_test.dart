import 'dart:async';
import 'dart:convert';

import 'package:festenao_common/log/log.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';
import 'package:test/test.dart';

const _timeout = Timeout(Duration(seconds: 30));

/// Uncaught errors of [body] (and of what it left running).
Future<List<Object>> _uncaughtErrors(Future<void> Function() body) async {
  var errors = <Object>[];
  // An error of the body stays in the guarded zone: completed either way.
  var done = Completer<void>();
  unawaited(
    runZonedGuarded(() async {
      try {
        await body();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      } finally {
        done.complete();
      }
    }, (e, _) => errors.add(e)),
  );
  await done.future;
  return errors;
}

/// A transport whose sends wait for [release].
class _SlowTransport extends MockLogTransport {
  final release = Completer<void>();
  final started = Completer<void>();

  @override
  Future<bool> sendBatch(List<LogRecord> records) async {
    if (!started.isCompleted) {
      started.complete();
    }
    await release.future;
    return super.sendBatch(records);
  }
}

int _encodedSize(LogRecord record) =>
    utf8.encode(jsonEncode(record.toMap())).length;

void main() {
  var storages = <(String, LogStorage Function())>[
    ('memory', MemoryLogStorage.new),
    (
      'sdb',
      () => SdbLogStorage(sdbFactory: newSdbFactoryMemory(), dbPathPrefix: 'l'),
    ),
    (
      'fs',
      () =>
          FsLogStorage(fileSystem: newFileSystemMemory(), directoryPath: '/l'),
    ),
    (
      'hybrid',
      () => HybridLogStorage(
        sdbStorage: SdbLogStorage(
          sdbFactory: newSdbFactoryMemory(),
          dbPathPrefix: 'h',
        ),
        fsStorage: FsLogStorage(
          fileSystem: newFileSystemMemory(),
          directoryPath: '/h',
        ),
      ),
    ),
  ];

  group('logger close', () {
    test('close sends the unsent records', () async {
      var transport = MockLogTransport();
      var storage = MemoryLogStorage();
      var logger = FestenaoLogger(
        storage: storage,
        transport: transport,
        flushInterval: Duration.zero,
      );
      logger.info('last words');
      await logger.close();
      expect(transport.sentBatches, hasLength(1));
      expect(transport.sentBatches.first.single.message, 'last words');
    }, timeout: _timeout);

    test('close waits for a running flush', () async {
      var transport = _SlowTransport();
      var storage = SdbLogStorage(
        sdbFactory: newSdbFactoryMemory(),
        dbPathPrefix: 'slow',
      );
      var logger = FestenaoLogger(
        storage: storage,
        transport: transport,
        flushInterval: Duration.zero,
      );
      var errors = await _uncaughtErrors(() async {
        await storage.appendRecord(
          LogRecord(level: LogLevel.info, message: 'm1'),
        );
        var flush = logger.flush();
        await transport.started.future;
        var close = logger.close();
        // The send is still running while close goes on.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        transport.release.complete();
        // Closing the database under the flush made it hang ("database is
        // closed").
        await flush.timeout(const Duration(seconds: 5));
        await close.timeout(const Duration(seconds: 5));
      });
      expect(errors, isEmpty);
      expect(transport.sentBatches.expand((batch) => batch), hasLength(1));
      // Marked as sent before the storage was closed.
      var reopened = SdbLogStorage(
        sdbFactory: storage.sdbFactory,
        dbPathPrefix: 'slow',
      );
      expect(await reopened.getUnsentRecords(), isEmpty);
      await reopened.close();
    }, timeout: _timeout);

    for (var (kind, newStorage) in storages) {
      test('$kind log then close at once', () async {
        var storage = newStorage();
        var errors = await _uncaughtErrors(() async {
          var logger = FestenaoLogger(storage: storage);
          logger.info('a');
          await logger.close();
        });
        expect(errors, isEmpty);
      }, timeout: _timeout);

      test('$kind initialized, log then close at once', () async {
        var errors = await _uncaughtErrors(() async {
          var storage = newStorage();
          await storage.init();
          var logger = FestenaoLogger(storage: storage);
          logger.info('a');
          await logger.close();
        });
        expect(errors, isEmpty);
      }, timeout: _timeout);
    }

    test('sdb pending appends are written before close', () async {
      var factory = newSdbFactoryMemory();
      var storage = SdbLogStorage(sdbFactory: factory, dbPathPrefix: 'p');
      var errors = await _uncaughtErrors(() async {
        for (var i = 0; i < 5; i++) {
          unawaited(
            storage.appendRecord(
              LogRecord(level: LogLevel.info, message: 'm$i'),
            ),
          );
        }
        await storage.close();
      });
      expect(errors, isEmpty);
      var reopened = SdbLogStorage(sdbFactory: factory, dbPathPrefix: 'p');
      expect(await reopened.queryRecords(const LogQueryFilter()), hasLength(5));
      await reopened.close();
    }, timeout: _timeout);
  });

  group('fully sent segment', () {
    for (var (kind, newStorage) in storages) {
      test('$kind segment sent before being sealed', () async {
        var storage = newStorage();
        var r1 = LogRecord(level: LogLevel.info, message: 'm1');
        await storage.appendRecord(r1);
        await storage.markAsSent([r1.id]);
        await storage.rotateSegment();
        var r2 = LogRecord(level: LogLevel.info, message: 'm2');
        await storage.appendRecord(r2);
        await storage.markAsSent([r2.id]);
        var summaries = await storage.getSegmentSummaries();
        expect(summaries.first.status, 'fullySent');
        await storage.close();
      }, timeout: _timeout);
    }
  });

  group('record size', () {
    test('a big error is cut', () {
      var record = LogRecord(
        level: LogLevel.error,
        message: 'x',
        error: 'e' * 300000,
      );
      expect(_encodedSize(record), lessThanOrEqualTo(maxLogRecordSizeBytes));
      expect(record.toMap()['message'], 'x');
    }, timeout: _timeout);

    test('a big error with a small stack trace is cut', () {
      var record = LogRecord(
        level: LogLevel.error,
        message: 'x',
        error: 'e' * 300000,
        stackTrace: '#0 main',
      );
      expect(_encodedSize(record), lessThanOrEqualTo(maxLogRecordSizeBytes));
    }, timeout: _timeout);

    test('a big multi byte message is cut', () {
      var record = LogRecord(level: LogLevel.info, message: 'é' * 200000);
      expect(_encodedSize(record), lessThanOrEqualTo(maxLogRecordSizeBytes));
      expect(record.toMap()['message'] as String, endsWith('[truncated]'));
    }, timeout: _timeout);

    test('error, stack trace and message all big', () {
      var record = LogRecord(
        level: LogLevel.error,
        message: 'm' * 200000,
        error: 'e' * 200000,
        stackTrace: 's' * 200000,
      );
      expect(_encodedSize(record), lessThanOrEqualTo(maxLogRecordSizeBytes));
    }, timeout: _timeout);

    test('a small record is unchanged', () {
      var record = LogRecord(
        level: LogLevel.error,
        message: 'hello',
        error: 'boom',
        stackTrace: '#0 main',
      );
      var map = record.toMap();
      expect(map['message'], 'hello');
      expect(map['error'], 'boom');
      expect(map['stackTrace'], '#0 main');
    }, timeout: _timeout);
  });
}
