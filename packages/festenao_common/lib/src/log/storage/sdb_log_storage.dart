import 'dart:async';
import 'dart:convert';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';
import 'package:tekartik_common_utils/common_utils_import.dart' show Lock;
import '../log_level.dart';
import '../log_record.dart';
import '../reader/log_query_filter.dart';
import 'log_storage.dart';
import 'log_storage_prv.dart';

/// CV / SDB Record for log records.
class SdbLogRecordCv extends ScvStringRecordBase {
  /// Timestamp field.
  final timestamp = CvField<String>('ts');

  /// Log level field.
  final level = CvField<int>('level');

  /// Message field.
  final message = CvField<String>('msg');

  /// Logger name field.
  final loggerName = CvField<String>('logger');

  /// Error field.
  final error = CvField<String>('err');

  /// Stack trace field.
  final stackTrace = CvField<String>('st');

  /// Device ID field.
  final deviceId = CvField<String>('devId');

  /// Session ID field.
  final sessionId = CvField<String>('sessId');

  /// Sent flag field.
  final sent = CvField<bool>('sent');

  /// Sent timestamp field.
  final sentAt = CvField<String>('sentAt');

  /// Extra metadata JSON field.
  final extraJson = CvField<String>('extra');

  @override
  CvFields get fields => [
    timestamp,
    level,
    message,
    loggerName,
    error,
    stackTrace,
    deviceId,
    sessionId,
    sent,
    sentAt,
    extraJson,
  ];

  /// Converts this CV record to a [LogRecord].
  LogRecord toLogRecord() {
    Map<String, Object?>? extra;
    if (extraJson.v != null && extraJson.v!.isNotEmpty) {
      try {
        extra = Map<String, Object?>.from(jsonDecode(extraJson.v!) as Map);
      } catch (_) {}
    }
    return LogRecord(
      id: id,
      timestamp: DateTime.parse(timestamp.v!).toUtc(),
      level: LogLevel.parse(level.v!),
      loggerName: loggerName.v,
      message: message.v ?? '',
      error: error.v,
      stackTrace: stackTrace.v,
      extra: extra,
      deviceId: deviceId.v,
      sessionId: sessionId.v,
      sent: sent.v ?? false,
      sentAt: sentAt.v != null ? DateTime.parse(sentAt.v!).toUtc() : null,
    );
  }

  /// Creates an [SdbLogRecordCv] from a [LogRecord].
  static SdbLogRecordCv fromLogRecord(LogRecord record) {
    return sdbLogRecordStore.record(record.id).cv()
      ..timestamp.v = record.timestamp.toIso8601String()
      ..level.v = record.level.value
      ..message.v = record.message
      ..loggerName.v = record.loggerName
      ..error.v = record.error
      ..stackTrace.v = record.stackTrace
      ..deviceId.v = record.deviceId
      ..sessionId.v = record.sessionId
      ..sent.v = record.sent
      ..sentAt.v = record.sentAt?.toIso8601String()
      ..extraJson.v = record.extra != null ? jsonEncode(record.extra) : null;
  }
}

/// CV / SDB Record for log segment summaries in Master DB.
class SdbLogSegmentCv extends ScvStringRecordBase {
  /// Name field.
  final name = CvField<String>('name');

  /// Created at field.
  final createdAt = CvField<String>('createdAt');

  /// Sealed at field.
  final sealedAt = CvField<String>('sealedAt');

  /// Oldest timestamp field.
  final oldestTimestamp = CvField<String>('oldestTs');

  /// Newest timestamp field.
  final newestTimestamp = CvField<String>('newestTs');

  /// Size in bytes field.
  final sizeBytes = CvField<int>('size');

  /// Record count field.
  final recordCount = CvField<int>('count');

  /// Status field.
  final status = CvField<String>('status');

  @override
  CvFields get fields => [
    name,
    createdAt,
    sealedAt,
    oldestTimestamp,
    newestTimestamp,
    sizeBytes,
    recordCount,
    status,
  ];

  /// Converts to a [LogSegmentSummary].
  LogSegmentSummary toSummary() {
    return LogSegmentSummary(
      segmentId: id,
      name: name.v ?? '',
      createdAt: DateTime.parse(createdAt.v!).toUtc(),
      sealedAt: sealedAt.v != null ? DateTime.parse(sealedAt.v!).toUtc() : null,
      oldestTimestamp: oldestTimestamp.v != null
          ? DateTime.parse(oldestTimestamp.v!).toUtc()
          : null,
      newestTimestamp: newestTimestamp.v != null
          ? DateTime.parse(newestTimestamp.v!).toUtc()
          : null,
      sizeBytes: sizeBytes.v ?? 0,
      recordCount: recordCount.v ?? 0,
      status: status.v ?? 'active',
    );
  }

  /// Creates an [SdbLogSegmentCv] from a [LogSegmentSummary].
  static SdbLogSegmentCv fromSummary(LogSegmentSummary summary) {
    return sdbLogMasterStore.record(summary.segmentId).cv()
      ..name.v = summary.name
      ..createdAt.v = summary.createdAt.toIso8601String()
      ..sealedAt.v = summary.sealedAt?.toIso8601String()
      ..oldestTimestamp.v = summary.oldestTimestamp?.toIso8601String()
      ..newestTimestamp.v = summary.newestTimestamp?.toIso8601String()
      ..sizeBytes.v = summary.sizeBytes
      ..recordCount.v = summary.recordCount
      ..status.v = summary.status;
  }
}

/// Store for log segment summaries.
final sdbLogMasterStore = scvStringStoreFactory.store<SdbLogSegmentCv>(
  'master',
);

/// Store for log records.
final sdbLogRecordStore = scvStringStoreFactory.store<SdbLogRecordCv>('logs');

bool _logCvBuildersInitialized = false;
void _initSdbLogBuilders() {
  if (_logCvBuildersInitialized) return;
  _logCvBuildersInitialized = true;
  cvAddConstructors([SdbLogRecordCv.new, SdbLogSegmentCv.new]);
}

/// SDB-backed implementation of [LogStorage] supporting multi-segment databases,
/// master DB indexing, 10MB segment limits, 256KB record bounds, and purging.
class SdbLogStorage implements LogStorage {
  /// SDB factory for opening databases.
  final SdbFactory sdbFactory;

  /// Database path prefix.
  final String dbPathPrefix;

  /// Maximum segment size in bytes.
  final int maxSegmentSizeBytes;

  /// Maximum age of log records before purge.
  final Duration maxAge;

  /// Maximum total size in bytes across all segments.
  final int maxTotalSizeBytes;

  final StreamController<LogRecord> _streamController =
      StreamController<LogRecord>.broadcast();

  SdbDatabase? _masterDb;
  SdbDatabase? _activeSegmentDb;
  LogSegmentSummary? _activeSegmentSummary;

  final List<LogSegmentSummary> _segmentSummaries = [];
  Future<void>? _initFuture;

  /// Writes one at a time (the logger does not wait for its appends).
  final _lock = Lock();

  static const String _masterDbName = 'festenao_log_master.db';

  /// Creates an [SdbLogStorage] instance.
  SdbLogStorage({
    required this.sdbFactory,
    this.dbPathPrefix = 'festenao_logs',
    this.maxSegmentSizeBytes = 10 * 1024 * 1024,
    this.maxAge = const Duration(days: 14),
    this.maxTotalSizeBytes = 100 * 1024 * 1024,
  });

  String _masterDbPath() =>
      dbPathPrefix.isEmpty ? _masterDbName : '$dbPathPrefix/$_masterDbName';

  String _segmentDbPath(String segmentId) => dbPathPrefix.isEmpty
      ? 'log_seg_$segmentId.db'
      : '$dbPathPrefix/log_seg_$segmentId.db';

  @override
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    _initSdbLogBuilders();

    final masterPath = _masterDbPath();
    _masterDb = await sdbFactory.openDatabase(
      masterPath,
      options: SdbOpenDatabaseOptions(
        version: 1,
        schema: SdbDatabaseSchema(stores: [sdbLogMasterStore.schema()]),
      ),
    );

    final masterRecords = await sdbLogMasterStore.findRecords(_masterDb!);
    for (final rec in masterRecords) {
      _segmentSummaries.add(rec.toSummary());
    }

    _segmentSummaries.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    LogSegmentSummary? activeSummary;
    for (final seg in _segmentSummaries) {
      if (seg.status == logSegmentStatusActive) {
        activeSummary = seg;
        break;
      }
    }

    activeSummary ??= await _createNewSegmentSummary();

    _activeSegmentSummary = activeSummary;
    _activeSegmentDb = await _openSegmentDb(activeSummary.segmentId);
  }

  /// Runs [action] on the database of [segmentId], the active one or a
  /// database opened then closed (an open database would block its deletion
  /// on the web).
  Future<T> _withSegmentDb<T>(
    String segmentId,
    Future<T> Function(SdbDatabase db) action,
  ) async {
    if (segmentId == _activeSegmentSummary?.segmentId &&
        _activeSegmentDb != null) {
      return await action(_activeSegmentDb!);
    }
    final db = await _openSegmentDb(segmentId);
    try {
      return await action(db);
    } finally {
      await db.close();
    }
  }

  Future<SdbDatabase> _openSegmentDb(String segmentId) async {
    final path = _segmentDbPath(segmentId);
    return await sdbFactory.openDatabase(
      path,
      options: SdbOpenDatabaseOptions(
        version: 1,
        schema: SdbDatabaseSchema(stores: [sdbLogRecordStore.schema()]),
      ),
    );
  }

  Future<LogSegmentSummary> _createNewSegmentSummary() async {
    final seq = _segmentSummaries.length + 1;
    final segId = 'seg_${DateTime.now().millisecondsSinceEpoch}_$seq';

    final summary = LogSegmentSummary(
      segmentId: segId,
      name: _segmentDbPath(segId),
      createdAt: DateTime.now().toUtc(),
      sizeBytes: 0,
      recordCount: 0,
      status: logSegmentStatusActive,
    );

    _segmentSummaries.add(summary);
    await _saveSegmentSummary(summary);
    return summary;
  }

  Future<void> _saveSegmentSummary(LogSegmentSummary summary) async {
    final cvRec = SdbLogSegmentCv.fromSummary(summary);
    await sdbLogMasterStore.record(summary.segmentId).put(_masterDb!, cvRec);
  }

  @override
  Future<void> appendRecord(LogRecord record) async {
    await init();
    await _lock.synchronized(() async {
      final cvRec = SdbLogRecordCv.fromLogRecord(record);
      final recSize = record.toMap().toString().length;

      await sdbLogRecordStore.record(record.id).put(_activeSegmentDb!, cvRec);

      _streamController.add(record);

      _activeSegmentSummary = logSegmentSummaryAddRecord(
        _activeSegmentSummary!,
        record,
        recSize,
      );
      logSegmentSummariesReplace(_segmentSummaries, _activeSegmentSummary!);
      await _saveSegmentSummary(_activeSegmentSummary!);

      if (_activeSegmentSummary!.sizeBytes >= maxSegmentSizeBytes) {
        await _rotateSegment();
      }
    });
  }

  @override
  Future<void> appendRecords(List<LogRecord> records) async {
    for (final r in records) {
      await appendRecord(r);
    }
  }

  /// All the records of [segmentId].
  Future<List<LogRecord>> _segmentRecords(String segmentId) =>
      _withSegmentDb(segmentId, (db) async {
        final recs = await sdbLogRecordStore.findRecords(db);
        return recs.map((r) => r.toLogRecord()).toList();
      });

  @override
  Future<List<LogRecord>> getUnsentRecords({int? limit}) async {
    await init();
    return await _lock.synchronized(() async {
      final results = <LogRecord>[];
      for (final segSummary in _segmentSummaries) {
        for (final rec in await _segmentRecords(segSummary.segmentId)) {
          if (!rec.sent) {
            results.add(rec);
            if (limit != null && results.length >= limit) {
              return results;
            }
          }
        }
      }
      return results;
    });
  }

  @override
  Future<void> markAsSent(List<String> recordIds, {DateTime? sentAt}) async {
    await init();
    await _lock.synchronized(() async {
      final now = (sentAt ?? DateTime.now()).toUtc();
      final idSet = recordIds.toSet();

      for (var segIdx = 0; segIdx < _segmentSummaries.length; segIdx++) {
        final segSummary = _segmentSummaries[segIdx];
        final (updatedCount, allSent, count) = await _withSegmentDb(
          segSummary.segmentId,
          (db) async {
            final recs = await sdbLogRecordStore.findRecords(db);
            var updatedCount = 0;
            var allSent = true;
            for (final r in recs) {
              final rec = r.toLogRecord();
              if (idSet.contains(rec.id)) {
                final updated = rec.copyWith(sent: true, sentAt: now);
                final updatedCv = SdbLogRecordCv.fromLogRecord(updated);
                await sdbLogRecordStore.record(rec.id).put(db, updatedCv);
                updatedCount++;
              } else if (!rec.sent) {
                allSent = false;
              }
            }
            return (updatedCount, allSent, recs.length);
          },
        );

        if (updatedCount > 0 &&
            allSent &&
            count > 0 &&
            segSummary.status == logSegmentStatusSealed) {
          final newSummary = logSegmentSummaryWithStatus(
            segSummary,
            logSegmentStatusFullySent,
          );
          _segmentSummaries[segIdx] = newSummary;
          await _saveSegmentSummary(newSummary);
        }
      }
    });
  }

  @override
  Future<List<LogRecord>> queryRecords(
    LogQueryFilter filter, {
    int? limit,
    int? offset,
    bool descending = true,
  }) async {
    await init();
    final results = await _lock.synchronized(() async {
      final results = <LogRecord>[];
      for (final segSummary in _segmentSummaries) {
        results.addAll(
          (await _segmentRecords(segSummary.segmentId)).where(filter.matches),
        );
      }
      return results;
    });
    return logRecordsSortAndPage(
      results,
      limit: limit,
      offset: offset,
      descending: descending,
    );
  }

  @override
  Stream<LogRecord> streamRecords(LogQueryFilter filter) {
    return _streamController.stream.where(filter.matches);
  }

  @override
  Future<List<LogSegmentSummary>> getSegmentSummaries() async {
    await init();
    return List.from(_segmentSummaries);
  }

  @override
  Future<void> rotateSegment() async {
    await init();
    await _lock.synchronized(_rotateSegment);
  }

  Future<void> _rotateSegment() async {
    final active = _activeSegmentSummary;
    if (active != null && active.status == logSegmentStatusActive) {
      final sealed = logSegmentSummaryWithStatus(
        active,
        logSegmentStatusSealed,
        sealedAt: DateTime.now().toUtc(),
      );
      logSegmentSummariesReplace(_segmentSummaries, sealed);
      await _saveSegmentSummary(sealed);
    }

    final previousDb = _activeSegmentDb;
    _activeSegmentSummary = await _createNewSegmentSummary();
    _activeSegmentDb = await _openSegmentDb(_activeSegmentSummary!.segmentId);
    // The sealed segment is opened on demand.
    await previousDb?.close();
  }

  Future<void> _deleteSegment(LogSegmentSummary seg) async {
    await sdbLogMasterStore.record(seg.segmentId).delete(_masterDb!);
    await sdbFactory.deleteDatabase(_segmentDbPath(seg.segmentId));
  }

  @override
  Future<void> purgeOldLogs({Duration? maxAge, int? maxTotalSizeBytes}) async {
    await init();
    await _lock.synchronized(() async {
      final sizeLimit = maxTotalSizeBytes ?? this.maxTotalSizeBytes;
      final activeSegmentId = _activeSegmentSummary?.segmentId;

      final toDelete = logSegmentsOlderThan(
        _segmentSummaries,
        activeSegmentId: activeSegmentId,
        maxAge: maxAge ?? this.maxAge,
      );
      for (final seg in toDelete) {
        _segmentSummaries.removeWhere((s) => s.segmentId == seg.segmentId);
        await _deleteSegment(seg);
      }

      int totalBytes() =>
          _segmentSummaries.fold(0, (sum, seg) => sum + seg.sizeBytes);

      while (totalBytes() > sizeLimit && _segmentSummaries.length > 1) {
        final targetIdx = logSegmentPurgeIndex(
          _segmentSummaries,
          activeSegmentId: activeSegmentId,
        );
        if (targetIdx == -1) {
          break;
        }
        await _deleteSegment(_segmentSummaries.removeAt(targetIdx));
      }
    });
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {
    // Wait for the pending writes.
    await _lock.synchronized(() {});
    await _streamController.close();
    await _activeSegmentDb?.close();
    await _masterDb?.close();
  }
}
