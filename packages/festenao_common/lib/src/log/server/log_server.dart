import 'dart:convert';
import '../log_record.dart';
import '../storage/log_storage.dart';

/// Lightweight HTTP receiver handler for receiving log batches from remote client loggers.
class FestenaoLogServerHandler {
  final LogStorage storage;

  FestenaoLogServerHandler({required this.storage});

  /// Processes a raw JSON payload string containing a list of log record maps.
  Future<Map<String, Object?>> handleJsonPayload(String payloadJson) async {
    try {
      final decoded = jsonDecode(payloadJson);
      List rawList;
      if (decoded is List) {
        rawList = decoded;
      } else if (decoded is Map && decoded['records'] is List) {
        rawList = decoded['records'] as List;
      } else {
        return {'success': false, 'error': 'Invalid JSON format, expected array of records'};
      }

      final records = <LogRecord>[];
      for (final item in rawList) {
        if (item is Map<String, Object?>) {
          records.add(LogRecord.fromMap(item));
        }
      }

      if (records.isNotEmpty) {
        await storage.appendRecords(records);
      }

      return {
        'success': true,
        'count': records.length,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
