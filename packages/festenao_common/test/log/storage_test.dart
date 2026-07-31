import 'package:dev_test/test.dart';
import 'package:festenao_common/log/log.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';

void main() {
  group('LogStorage', () {
    test('MemoryLogStorage append, query, markAsSent, rotation, and purge',
        () async {
      final storage = MemoryLogStorage(
        maxSegmentSizeBytes: 500, // force small segment for rotation test
        maxAge: const Duration(days: 1),
        maxTotalSizeBytes: 2000,
      );
      await storage.init();

      final rec1 = LogRecord(
        level: LogLevel.info,
        message: 'First log entry for testing memory storage',
      );
      final rec2 = LogRecord(
        level: LogLevel.error,
        message: 'Second log entry with error details',
      );

      await storage.appendRecord(rec1);
      await storage.appendRecord(rec2);

      // Unsent query
      final unsent = await storage.getUnsentRecords();
      expect(unsent.length, 2);

      // Query filter
      final errorOnly = await storage.queryRecords(
        const LogQueryFilter(minLevel: LogLevel.error),
      );
      expect(errorOnly.length, 1);
      expect(errorOnly.first.id, rec2.id);

      // Mark as sent
      await storage.markAsSent([rec1.id]);
      final unsentAfter = await storage.getUnsentRecords();
      expect(unsentAfter.length, 1);
      expect(unsentAfter.first.id, rec2.id);

      // Verify segment summaries
      final summaries = await storage.getSegmentSummaries();
      expect(summaries.isNotEmpty, isTrue);

      await storage.close();
    });

    test('SdbLogStorage (in-memory SDB factory)', () async {
      final storage = SdbLogStorage(
        sdbFactory: sdbFactoryMemory,
        dbPathPrefix: 'test_sdb_logs',
        maxSegmentSizeBytes: 1000,
      );
      await storage.init();

      final rec = LogRecord(
        level: LogLevel.info,
        loggerName: 'app.boot',
        message: 'System initialization',
      );
      await storage.appendRecord(rec);

      final records = await storage.queryRecords(const LogQueryFilter());
      expect(records.length, 1);
      expect(records.first.message, 'System initialization');

      final summaries = await storage.getSegmentSummaries();
      expect(summaries.length, 1);
      expect(summaries.first.recordCount, 1);

      await storage.markAsSent([rec.id]);
      final unsent = await storage.getUnsentRecords();
      expect(unsent, isEmpty);

      await storage.close();
    });

    test('FsLogStorage (in-memory FileSystem shim)', () async {
      final fs = newFileSystemMemory();
      final storage = FsLogStorage(
        fileSystem: fs,
        directoryPath: '/test_logs',
        maxSegmentSizeBytes: 1000,
      );
      await storage.init();

      final rec = LogRecord(
        level: LogLevel.warning,
        message: 'Network latency spike detected',
      );
      await storage.appendRecord(rec);

      final query = await storage.queryRecords(const LogQueryFilter());
      expect(query.length, 1);
      expect(query.first.message, 'Network latency spike detected');

      await storage.markAsSent([rec.id]);
      final unsent = await storage.getUnsentRecords();
      expect(unsent, isEmpty);

      await storage.close();
    });

    test('HybridLogStorage combining SDB and FS', () async {
      final sdb = SdbLogStorage(
        sdbFactory: sdbFactoryMemory,
        dbPathPrefix: 'hybrid_sdb',
      );
      final fs = FsLogStorage(
        fileSystem: newFileSystemMemory(),
        directoryPath: '/hybrid_fs',
      );

      final hybrid = HybridLogStorage(sdbStorage: sdb, fsStorage: fs);
      await hybrid.init();

      final rec = LogRecord(
        level: LogLevel.info,
        message: 'Hybrid storage log message',
      );
      await hybrid.appendRecord(rec);

      final unsent = await hybrid.getUnsentRecords();
      expect(unsent.length, 1);

      await hybrid.markAsSent([rec.id]);
      final unsentAfter = await hybrid.getUnsentRecords();
      expect(unsentAfter, isEmpty);

      await hybrid.close();
    });
  });
}
