import 'dart:convert';
import 'package:dev_test/test.dart';
import 'package:festenao_common/log/log.dart';
import 'package:festenao_common/log/log_server.dart';

void main() {
  group('FestenaoLogServerHandler', () {
    test('receives and persists JSON batch', () async {
      final storage = MemoryLogStorage();
      await storage.init();
      final handler = FestenaoLogServerHandler(storage: storage);

      final rec1 = LogRecord(
        level: LogLevel.info,
        message: 'Server test log 1',
      );
      final rec2 = LogRecord(
        level: LogLevel.error,
        message: 'Server test log 2',
      );

      final payload = jsonEncode([rec1.toMap(), rec2.toMap()]);

      final result = await handler.handleJsonPayload(payload);
      expect(result['success'], isTrue);
      expect(result['count'], 2);

      final stored = await storage.queryRecords(const LogQueryFilter());
      expect(stored.length, 2);

      await storage.close();
    });
  });
}
