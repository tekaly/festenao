import '../log_record.dart';
import '../reader/log_query_filter.dart';

/// Summary metadata for a log segment managed by Master DB.
class LogSegmentSummary {
  final String segmentId;
  final String name;
  final DateTime createdAt;
  final DateTime? sealedAt;
  final DateTime? oldestTimestamp;
  final DateTime? newestTimestamp;
  final int sizeBytes;
  final int recordCount;
  final String status; // 'active', 'sealed', 'fullySent', 'archived'

  LogSegmentSummary({
    required this.segmentId,
    required this.name,
    required this.createdAt,
    this.sealedAt,
    this.oldestTimestamp,
    this.newestTimestamp,
    required this.sizeBytes,
    required this.recordCount,
    required this.status,
  });

  Map<String, Object?> toMap() => {
        'segmentId': segmentId,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        if (sealedAt != null) 'sealedAt': sealedAt!.toIso8601String(),
        if (oldestTimestamp != null)
          'oldestTimestamp': oldestTimestamp!.toIso8601String(),
        if (newestTimestamp != null)
          'newestTimestamp': newestTimestamp!.toIso8601String(),
        'sizeBytes': sizeBytes,
        'recordCount': recordCount,
        'status': status,
      };

  factory LogSegmentSummary.fromMap(Map<String, Object?> map) {
    return LogSegmentSummary(
      segmentId: map['segmentId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      createdAt: DateTime.parse(map['createdAt']!.toString()).toUtc(),
      sealedAt: map['sealedAt'] != null
          ? DateTime.parse(map['sealedAt']!.toString()).toUtc()
          : null,
      oldestTimestamp: map['oldestTimestamp'] != null
          ? DateTime.parse(map['oldestTimestamp']!.toString()).toUtc()
          : null,
      newestTimestamp: map['newestTimestamp'] != null
          ? DateTime.parse(map['newestTimestamp']!.toString()).toUtc()
          : null,
      sizeBytes: (map['sizeBytes'] as int?) ?? 0,
      recordCount: (map['recordCount'] as int?) ?? 0,
      status: map['status']?.toString() ?? 'active',
    );
  }
}

/// Abstract storage interface for appending, querying, and managing log records.
abstract class LogStorage {
  /// Initialize storage resources.
  Future<void> init();

  /// Append a single log record.
  Future<void> appendRecord(LogRecord record);

  /// Append multiple log records in batch.
  Future<void> appendRecords(List<LogRecord> records);

  /// Fetch unsent records for remote push.
  Future<List<LogRecord>> getUnsentRecords({int? limit});

  /// Mark log records as sent by their unique IDs.
  Future<void> markAsSent(List<String> recordIds, {DateTime? sentAt});

  /// Query records matching a [LogQueryFilter].
  Future<List<LogRecord>> queryRecords(
    LogQueryFilter filter, {
    int? limit,
    int? offset,
    bool descending = true,
  });

  /// Stream records matching a [LogQueryFilter] in real-time.
  Stream<LogRecord> streamRecords(LogQueryFilter filter);

  /// Get segment metadata summaries managed by master database.
  Future<List<LogSegmentSummary>> getSegmentSummaries();

  /// Manually trigger segment rotation if size exceeds limit or on demand.
  Future<void> rotateSegment();

  /// Manually trigger log cleanup / purging based on duration and size limits.
  Future<void> purgeOldLogs({
    Duration? maxAge,
    int? maxTotalSizeBytes,
  });

  /// Flush pending writes to storage.
  Future<void> flush();

  /// Close storage handles.
  Future<void> close();
}
