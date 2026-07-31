import 'package:dev_test/test.dart';
import 'package:festenao_common/log/log.dart';

void main() {
  group('LogRecord', () {
    test('serialization & deserialization', () {
      final now = DateTime.now().toUtc();
      final record = LogRecord(
        id: 'test-id-123',
        timestamp: now,
        level: LogLevel.warning,
        loggerName: 'kiosk.auth',
        message: 'User authentication attempt failed',
        error: 'InvalidCredentialsException',
        stackTrace: 'StackTrace #0',
        extra: {'attempts': 3, 'ip': '192.168.1.50'},
        deviceId: 'borne-42',
        sessionId: 'sess-abc',
        sent: true,
        sentAt: now,
      );

      final map = record.toMap();
      expect(map['id'], 'test-id-123');
      expect(map['level'], 800);
      expect(map['levelName'], 'WARNING');
      expect(map['message'], 'User authentication attempt failed');
      expect(map['deviceId'], 'borne-42');
      expect(map['sent'], true);

      final restored = LogRecord.fromMap(map);
      expect(restored.id, 'test-id-123');
      expect(restored.level, LogLevel.warning);
      expect(restored.loggerName, 'kiosk.auth');
      expect(restored.message, 'User authentication attempt failed');
      expect(restored.error, 'InvalidCredentialsException');
      expect(restored.extra, {'attempts': 3, 'ip': '192.168.1.50'});
      expect(restored.deviceId, 'borne-42');
      expect(restored.sessionId, 'sess-abc');
      expect(restored.sent, true);
    });

    test('truncates large payloads exceeding 256KB', () {
      final hugeMessage = 'A' * (300 * 1024); // 300 KB string
      final record = LogRecord(
        level: LogLevel.error,
        message: hugeMessage,
      );

      final map = record.toMap();
      final msg = map['message'] as String;
      expect(msg.endsWith('...[truncated]'), isTrue);
      expect(msg.length, lessThanOrEqualTo(256 * 1024));
    });
  });
}
