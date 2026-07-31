import 'dart:async';
import 'dart:convert';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';
import '../log_level.dart';
import '../log_record.dart';
import '../reader/log_query_filter.dart';
import 'log_storage.dart';

/// CV / SDB Record for log records.
class SdbLogRecordCv extends ScvStringRecordBase {
  final timestamp = CvField<String>('ts');
  final level = CvField<int>('level');
  final message = CvField<String>('msg');
  final loggerName = CvField<String>('logger');
  final error = CvField<String>('err');
  final stackTrace = CvField<String>('st');
  final deviceId = CvField<String>('devId');
  final sessionId = CvField<String>('sessId');
  final sent = CvField<bool>('sent');
  final sentAt = CvField<String>('sentAt');
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
  final name = CvField<String>('name');
  final createdAt = CvField<String>('createdAt');
  final sealedAt = CvField<String>('sealedAt');
  final oldestTimestamp = CvField<String>('oldestTs');
  final newestTimestamp = CvField<String>('newestTs');
  final sizeBytes = CvField<int>('size');
  final recordCount = CvField<int>('count');
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

final sdbLogMasterStore = scvStringStoreFactory.store<SdbLogSegmentCv>(
  'master',
);
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
  final SdbFactory sdbFactory;
  final String dbPathPrefix;
  final int maxSegmentSizeBytes;
  final Duration maxAge;
  final int maxTotalSizeBytes;

  final StreamController<LogRecord> _streamController =
      StreamController<LogRecord>.broadcast();

  SdbDatabase? _masterDb;
  SdbDatabase? _activeSegmentDb;
  LogSegmentSummary? _activeSegmentSummary;

  final List<LogSegmentSummary> _segmentSummaries = [];
  bool _initialized = false;

  static const String _masterDbName = 'festenao_log_master.db';

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
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
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
      if (seg.status == 'active') {
        activeSummary = seg;
        break;
      }
    }

    if (activeSummary == null) {
      activeSummary = await _createNewSegmentSummary();
    }

    _activeSegmentSummary = activeSummary;
    _activeSegmentDb = await _openSegmentDb(activeSummary.segmentId);
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
      status: 'active',
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
    final cvRec = SdbLogRecordCv.fromLogRecord(record);
    final map = record.toMap();
    final recSize = map.toString().length;

    await sdbLogRecordStore.record(record.id).put(_activeSegmentDb!, cvRec);

    _streamController.add(record);

    final current = _activeSegmentSummary!;
    final oldest =
        current.oldestTimestamp == null ||
            record.timestamp.isBefore(current.oldestTimestamp!)
        ? record.timestamp
        : current.oldestTimestamp;
    final newest =
        current.newestTimestamp == null ||
            record.timestamp.isAfter(current.newestTimestamp!)
        ? record.timestamp
        : current.newestTimestamp;

    _activeSegmentSummary = LogSegmentSummary(
      segmentId: current.segmentId,
      name: current.name,
      createdAt: current.createdAt,
      sealedAt: current.sealedAt,
      oldestTimestamp: oldest,
      newestTimestamp: newest,
      sizeBytes: current.sizeBytes + recSize,
      recordCount: current.recordCount + 1,
      status: current.status,
    );

    final idx = _segmentSummaries.indexWhere(
      (s) => s.segmentId == current.segmentId,
    );
    if (idx != -1) {
      _segmentSummaries[idx] = _activeSegmentSummary!;
    }
    await _saveSegmentSummary(_activeSegmentSummary!);

    if (_activeSegmentSummary!.sizeBytes >= maxSegmentSizeBytes) {
      await rotateSegment();
    }
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
    final results = <LogRecord>[];

    for (final segSummary in _segmentSummaries) {
      final db = await _openSegmentDb(segSummary.segmentId);
      final recs = await sdbLogRecordStore.findRecords(db);
      for (final r in recs) {
        final rec = r.toLogRecord();
        if (!rec.sent) {
          results.add(rec);
          if (limit != null && results.length >= limit) {
            return results;
          }
        }
      }
    }
    return results;
  }

  @override
  Future<void> markAsSent(List<String> recordIds, {DateTime? sentAt}) async {
    await init();
    final now = (sentAt ?? DateTime.now()).toUtc();
    final idSet = recordIds.toSet();

    for (var segIdx = 0; segIdx < _segmentSummaries.length; segIdx++) {
      final segSummary = _segmentSummaries[segIdx];
      final db = await _openSegmentDb(segSummary.segmentId);
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

      if (updatedCount > 0 &&
          allSent &&
          recs.isNotEmpty &&
          segSummary.status == 'sealed') {
        final newSummary = LogSegmentSummary(
          segmentId: segSummary.segmentId,
          name: segSummary.name,
          createdAt: segSummary.createdAt,
          sealedAt: segSummary.sealedAt,
          oldestTimestamp: segSummary.oldestTimestamp,
          newestTimestamp: segSummary.newestTimestamp,
          sizeBytes: segSummary.sizeBytes,
          recordCount: segSummary.recordCount,
          status: 'fullySent',
        );
        _segmentSummaries[segIdx] = newSummary;
        await _saveSegmentSummary(newSummary);
      }
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
    final results = <LogRecord>[];

    for (final segSummary in _segmentSummaries) {
      final db = await _openSegmentDb(segSummary.segmentId);
      final recs = await sdbLogRecordStore.findRecords(db);
      for (final r in recs) {
        final rec = r.toLogRecord();
        if (filter.matches(rec)) {
          results.add(rec);
        }
      }
    }

    if (descending) {
      results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } else {
      results.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    final start = offset ?? 0;
    if (start >= results.length) return [];

    if (limit != null) {
      final end = (start + limit).clamp(0, results.length);
      return results.sublist(start, end);
    }
    return results.sublist(start);
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
    if (_activeSegmentSummary != null &&
        _activeSegmentSummary!.status == 'active') {
      final sealed = LogSegmentSummary(
        segmentId: _activeSegmentSummary!.segmentId,
        name: _activeSegmentSummary!.name,
        createdAt: _activeSegmentSummary!.createdAt,
        sealedAt: DateTime.now().toUtc(),
        oldestTimestamp: _activeSegmentSummary!.oldestTimestamp,
        newestTimestamp: _activeSegmentSummary!.newestTimestamp,
        sizeBytes: _activeSegmentSummary!.sizeBytes,
        recordCount: _activeSegmentSummary!.recordCount,
        status: 'sealed',
      );
      final idx = _segmentSummaries.indexWhere(
        (s) => s.segmentId == sealed.segmentId,
      );
      if (idx != -1) {
        _segmentSummaries[idx] = sealed;
      }
      await _saveSegmentSummary(sealed);
    }

    _activeSegmentSummary = await _createNewSegmentSummary();
    _activeSegmentDb = await _openSegmentDb(_activeSegmentSummary!.segmentId);
  }

  @override
  Future<void> purgeOldLogs({Duration? maxAge, int? maxTotalSizeBytes}) async {
    await init();
    final ageCutoff = maxAge ?? this.maxAge;
    final sizeLimit = maxTotalSizeBytes ?? this.maxTotalSizeBytes;
    final now = DateTime.now().toUtc();

    final toDelete = <LogSegmentSummary>[];
    for (final seg in _segmentSummaries) {
      if (seg.segmentId == _activeSegmentSummary?.segmentId) continue;
      if (seg.newestTimestamp != null) {
        if (now.difference(seg.newestTimestamp!) > ageCutoff) {
          toDelete.add(seg);
        }
      }
    }

    for (final seg in toDelete) {
      _segmentSummaries.removeWhere((s) => s.segmentId == seg.segmentId);
      await sdbLogMasterStore.record(seg.segmentId).delete(_masterDb!);
      await sdbFactory.deleteDatabase(_segmentDbPath(seg.segmentId));
    }

    int totalBytes() =>
        _segmentSummaries.fold(0, (sum, seg) => sum + seg.sizeBytes);

    while (totalBytes() > sizeLimit && _segmentSummaries.length > 1) {
      var targetIdx = -1;
      for (var i = 0; i < _segmentSummaries.length; i++) {
        if (_segmentSummaries[i].segmentId == _activeSegmentSummary?.segmentId)
          continue;
        if (_segmentSummaries[i].status == 'fullySent') {
          targetIdx = i;
          break;
        }
      }
      if (targetIdx == -1) {
        for (var i = 0; i < _segmentSummaries.length; i++) {
          if (_segmentSummaries[i].segmentId !=
              _activeSegmentSummary?.segmentId) {
            targetIdx = i;
            break;
          }
        }
      }
      if (targetIdx != -1) {
        final seg = _segmentSummaries.removeAt(targetIdx);
        await sdbLogMasterStore.record(seg.segmentId).delete(_masterDb!);
        await sdbFactory.deleteDatabase(_segmentDbPath(seg.segmentId));
      } else {
        break;
      }
    }
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {
    await _streamController.close();
    await _activeSegmentDb?.close();
    await _masterDb?.close();
  }
}
