import 'package:dev_test/test.dart';
import 'package:festenao_common/log/log.dart';

void main() {
  group('FestenaoLogger', () {
    test('logs records above minLevel and flushes via transport', () async {
      final storage = MemoryLogStorage();
      final transport = MockLogTransport();

      final logger = FestenaoLogger(
        storage: storage,
        transport: transport,
        deviceId: 'borne-01',
        minLevel: LogLevel.info,
        flushInterval: Duration.zero, // manual flush in test
      );

      logger.debug('Debug msg ignored'); // below minLevel (info)
      logger.info('App started');
      logger.warning('Low battery warning');
      logger.error('Database connection timeout', error: 'TimeoutException');

      // Wait brief moment for async appendRecord calls
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final allInStorage = await storage.queryRecords(
        const LogQueryFilter(),
        descending: false,
      );
      expect(allInStorage.length, 3);
      expect(allInStorage[0].message, 'App started');
      expect(allInStorage[1].message, 'Low battery warning');
      expect(allInStorage[2].message, 'Database connection timeout');
      expect(allInStorage[2].deviceId, 'borne-01');

      // Flush unsent records to transport
      await logger.flush();

      expect(transport.sentBatches.length, 1);
      expect(transport.sentBatches.first.length, 3);

      final unsentAfterFlush = await storage.getUnsentRecords();
      expect(unsentAfterFlush, isEmpty);

      await logger.close();
    });
  });
}
