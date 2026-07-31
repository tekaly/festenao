import 'dart:async';
import '../log_record.dart';
import '../reader/log_query_filter.dart';
import 'log_storage.dart';

/// Hybrid log storage implementation combining structured storage ([sdbStorage])
/// for active/unsent logs and file storage ([fsStorage]) for archived/sent logs.
class HybridLogStorage implements LogStorage {
  /// Active structured log storage.
  final LogStorage sdbStorage;

  /// Archived file log storage.
  final LogStorage fsStorage;

  final StreamController<LogRecord> _streamController =
      StreamController<LogRecord>.broadcast();

  bool _initialized = false;

  /// Creates a hybrid log storage instance.
  HybridLogStorage({required this.sdbStorage, required this.fsStorage});

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await sdbStorage.init();
    await fsStorage.init();
  }

  @override
  Future<void> appendRecord(LogRecord record) async {
    await init();
    await sdbStorage.appendRecord(record);
    _streamController.add(record);
  }

  @override
  Future<void> appendRecords(List<LogRecord> records) async {
    for (final r in records) {
      await appendRecord(r);
    }
  }

  @override
  Future<List<LogRecord>> getUnsentRecords({int? limit}) async {
    await init();
    return sdbStorage.getUnsentRecords(limit: limit);
  }

  @override
  Future<void> markAsSent(List<String> recordIds, {DateTime? sentAt}) async {
    await init();
    await sdbStorage.markAsSent(recordIds, sentAt: sentAt);

    final queryFilter = const LogQueryFilter(sentOnly: true);
    final sentFromSdb = await sdbStorage.queryRecords(queryFilter);
    if (sentFromSdb.isNotEmpty) {
      await fsStorage.appendRecords(sentFromSdb);
    }
  }

  @override
  Future<List<LogRecord>> queryRecords(
    LogQueryFilter filter, {
    int? limit,
    int? offset,
    bool descending = true,
  }) async {
    await init();
    final sdbRecords = await sdbStorage.queryRecords(filter);
    final fsRecords = await fsStorage.queryRecords(filter);

    final combinedMap = <String, LogRecord>{};
    for (final r in fsRecords) {
      combinedMap[r.id] = r;
    }
    for (final r in sdbRecords) {
      combinedMap[r.id] = r;
    }

    final combined = combinedMap.values.toList();
    if (descending) {
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } else {
      combined.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    final start = offset ?? 0;
    if (start >= combined.length) return [];

    if (limit != null) {
      final end = (start + limit).clamp(0, combined.length);
      return combined.sublist(start, end);
    }
    return combined.sublist(start);
  }

  @override
  Stream<LogRecord> streamRecords(LogQueryFilter filter) {
    return _streamController.stream.where(filter.matches);
  }

  @override
  Future<List<LogSegmentSummary>> getSegmentSummaries() async {
    await init();
    final sdbSummaries = await sdbStorage.getSegmentSummaries();
    final fsSummaries = await fsStorage.getSegmentSummaries();
    return [...sdbSummaries, ...fsSummaries];
  }

  @override
  Future<void> rotateSegment() async {
    await init();
    await sdbStorage.rotateSegment();
    await fsStorage.rotateSegment();
  }

  @override
  Future<void> purgeOldLogs({Duration? maxAge, int? maxTotalSizeBytes}) async {
    await init();
    await sdbStorage.purgeOldLogs(
      maxAge: maxAge,
      maxTotalSizeBytes: maxTotalSizeBytes,
    );
    await fsStorage.purgeOldLogs(
      maxAge: maxAge,
      maxTotalSizeBytes: maxTotalSizeBytes,
    );
  }

  @override
  Future<void> flush() async {
    await sdbStorage.flush();
    await fsStorage.flush();
  }

  @override
  Future<void> close() async {
    await _streamController.close();
    await sdbStorage.close();
    await fsStorage.close();
  }
}
