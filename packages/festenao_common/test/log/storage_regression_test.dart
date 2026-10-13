import 'dart:async';

import 'package:festenao_common/log/log.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';
import 'package:test/test.dart';

void main() {
  LogStorage newSdbStorage() =>
      SdbLogStorage(sdbFactory: newSdbFactoryMemory(), dbPathPrefix: 'logs');
  LogStorage newFsStorage() =>
      FsLogStorage(fileSystem: newFileSystemMemory(), directoryPath: '/logs');

  for (var (kind, newStorage) in [
    ('sdb', newSdbStorage),
    ('fs', newFsStorage),
  ]) {
    group(kind, () {
      test('appends not awaited, before init', () async {
        var storage = newStorage();
        var errors = <Object>[];
        await runZonedGuarded(() async {
          // The logger does not wait for its appends.
          for (var i = 0; i < 10; i++) {
            unawaited(
              storage.appendRecord(
                LogRecord(level: LogLevel.info, message: 'm$i'),
              ),
            );
          }
          await storage.flush();
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }, (e, _) => errors.add(e));
        expect(errors, isEmpty);
        expect(
          await storage.queryRecords(const LogQueryFilter()),
          hasLength(10),
        );
        var summaries = await storage.getSegmentSummaries();
        expect(summaries.map((s) => s.recordCount), [10]);
        await storage.close();
      });
    });
  }

  test('sdb purge after a query of a sealed segment', () async {
    var storage = SdbLogStorage(
      sdbFactory: newSdbFactoryMemory(),
      dbPathPrefix: 'purge',
    );
    await storage.appendRecord(
      LogRecord(
        level: LogLevel.info,
        message: 'old',
        timestamp: DateTime.now().subtract(const Duration(days: 30)),
      ),
    );
    await storage.rotateSegment();
    expect(await storage.queryRecords(const LogQueryFilter()), hasLength(1));
    await storage.purgeOldLogs().timeout(const Duration(seconds: 5));
    expect(await storage.queryRecords(const LogQueryFilter()), isEmpty);
    expect(await storage.getSegmentSummaries(), hasLength(1));
    await storage.close();
  });

  test('hybrid markAsSent archives each record once', () async {
    var sdb = SdbLogStorage(
      sdbFactory: newSdbFactoryMemory(),
      dbPathPrefix: 'h',
    );
    var fs = FsLogStorage(
      fileSystem: newFileSystemMemory(),
      directoryPath: '/h',
    );
    var hybrid = HybridLogStorage(sdbStorage: sdb, fsStorage: fs);
    var ids = <String>[];
    for (var i = 0; i < 3; i++) {
      var record = LogRecord(level: LogLevel.info, message: 'm$i');
      ids.add(record.id);
      await hybrid.appendRecord(record);
      await hybrid.markAsSent([record.id]);
    }
    // Sent again, not archived again.
    await hybrid.markAsSent(ids);
    var archived = await fs.queryRecords(const LogQueryFilter());
    expect(archived.map((r) => r.id).toSet(), ids.toSet());
    expect(archived, hasLength(3));
    expect(archived.every((r) => r.sent), isTrue);
    await hybrid.close();
  });
}
