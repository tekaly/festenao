import 'dart:async';
import '../log_record.dart';
import '../storage/log_storage.dart';
import 'log_query_filter.dart';

/// Log reader utility for UI applications and diagnostic inspection.
class FestenaoLogReader {
  /// Storage backend read by this reader.
  final LogStorage storage;

  /// Creates a log reader with the specified [storage].
  FestenaoLogReader({required this.storage});

  /// Queries logs matching the specified [LogQueryFilter].
  Future<List<LogRecord>> queryLogs(
    LogQueryFilter filter, {
    int? limit,
    int? offset,
    bool descending = true,
  }) {
    return storage.queryRecords(
      filter,
      limit: limit,
      offset: offset,
      descending: descending,
    );
  }

  /// Real-time stream of incoming records matching [LogQueryFilter].
  Stream<LogRecord> streamLogs(LogQueryFilter filter) {
    return storage.streamRecords(filter);
  }

  /// Retrieves metadata summaries for all log database/file segments managed by Master DB.
  Future<List<LogSegmentSummary>> getSegmentSummaries() {
    return storage.getSegmentSummaries();
  }
}
