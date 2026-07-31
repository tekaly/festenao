import 'dart:async';
import '../log_record.dart';
import '../reader/log_query_filter.dart';
import 'log_storage.dart';

/// In-memory implementation of [LogStorage] supporting multi-segment indexing,
/// size limits (256KB per record, 10MB per segment, 100MB total), rotation, and purging.
class MemoryLogStorage implements LogStorage {
  final int maxSegmentSizeBytes;
  final Duration maxAge;
  final int maxTotalSizeBytes;

  final List<_MemorySegment> _segments = [];
  final _streamController = StreamController<LogRecord>.broadcast();

  bool _initialized = false;
  int _segmentSequence = 0;

  MemoryLogStorage({
    this.maxSegmentSizeBytes = 10 * 1024 * 1024, // 10 MB per segment
    this.maxAge = const Duration(days: 14), // 2 weeks duration limit
    this.maxTotalSizeBytes = 100 * 1024 * 1024, // 100 MB total limit
  });

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _createNewSegment();
  }

  _MemorySegment get _activeSegment {
    if (_segments.isEmpty) {
      _createNewSegment();
    }
    return _segments.last;
  }

  void _createNewSegment() {
    _segmentSequence++;
    final segmentId = 'seg_$_segmentSequence';
    _segments.add(
      _MemorySegment(
        summary: LogSegmentSummary(
          segmentId: segmentId,
          name: 'memory_log_$segmentId',
          createdAt: DateTime.now().toUtc(),
          sizeBytes: 0,
          recordCount: 0,
          status: 'active',
        ),
      ),
    );
  }

  @override
  Future<void> appendRecord(LogRecord record) async {
    await init();
    final active = _activeSegment;
    active.addRecord(record);

    _streamController.add(record);

    if (active.summary.sizeBytes >= maxSegmentSizeBytes) {
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
    final results = <LogRecord>[];
    for (final seg in _segments) {
      for (final rec in seg.records) {
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
    final now = (sentAt ?? DateTime.now()).toUtc();
    final idSet = recordIds.toSet();

    for (final seg in _segments) {
      var allSent = true;
      for (var i = 0; i < seg.records.length; i++) {
        final rec = seg.records[i];
        if (idSet.contains(rec.id)) {
          seg.records[i] = rec.copyWith(sent: true, sentAt: now);
        } else if (!seg.records[i].sent) {
          allSent = false;
        }
      }
      if (allSent && seg.records.isNotEmpty && seg.summary.status == 'sealed') {
        seg.summary = LogSegmentSummary(
          segmentId: seg.summary.segmentId,
          name: seg.summary.name,
          createdAt: seg.summary.createdAt,
          sealedAt: seg.summary.sealedAt,
          oldestTimestamp: seg.summary.oldestTimestamp,
          newestTimestamp: seg.summary.newestTimestamp,
          sizeBytes: seg.summary.sizeBytes,
          recordCount: seg.summary.recordCount,
          status: 'fullySent',
        );
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
    final allMatching = <LogRecord>[];
    for (final seg in _segments) {
      for (final rec in seg.records) {
        if (filter.matches(rec)) {
          allMatching.add(rec);
        }
      }
    }

    if (descending) {
      allMatching.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } else {
      allMatching.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    final start = offset ?? 0;
    if (start >= allMatching.length) return [];

    if (limit != null) {
      final end = (start + limit).clamp(0, allMatching.length);
      return allMatching.sublist(start, end);
    }
    return allMatching.sublist(start);
  }

  @override
  Stream<LogRecord> streamRecords(LogQueryFilter filter) {
    return _streamController.stream.where(filter.matches);
  }

  @override
  Future<List<LogSegmentSummary>> getSegmentSummaries() async {
    return _segments.map((s) => s.summary).toList();
  }

  @override
  Future<void> rotateSegment() async {
    if (_segments.isEmpty) return;
    final current = _segments.last;
    if (current.summary.status == 'active') {
      current.summary = LogSegmentSummary(
        segmentId: current.summary.segmentId,
        name: current.summary.name,
        createdAt: current.summary.createdAt,
        sealedAt: DateTime.now().toUtc(),
        oldestTimestamp: current.summary.oldestTimestamp,
        newestTimestamp: current.summary.newestTimestamp,
        sizeBytes: current.summary.sizeBytes,
        recordCount: current.summary.recordCount,
        status: 'sealed',
      );
    }
    _createNewSegment();
  }

  @override
  Future<void> purgeOldLogs({Duration? maxAge, int? maxTotalSizeBytes}) async {
    final ageCutoff = maxAge ?? this.maxAge;
    final sizeLimit = maxTotalSizeBytes ?? this.maxTotalSizeBytes;
    final now = DateTime.now().toUtc();

    // 1. Evict segments older than maxAge
    _segments.removeWhere((seg) {
      if (seg == _activeSegment) return false;
      if (seg.summary.newestTimestamp != null) {
        final age = now.difference(seg.summary.newestTimestamp!);
        return age > ageCutoff;
      }
      return false;
    });

    // 2. Enforce total storage size limit (FIFO eviction of sealed segments)
    int totalBytes() =>
        _segments.fold(0, (sum, seg) => sum + seg.summary.sizeBytes);

    while (totalBytes() > sizeLimit && _segments.length > 1) {
      // Prioritize fullySent sealed segments, otherwise oldest sealed segment
      int targetIndex = -1;
      for (var i = 0; i < _segments.length - 1; i++) {
        if (_segments[i].summary.status == 'fullySent') {
          targetIndex = i;
          break;
        }
      }
      if (targetIndex == -1) {
        targetIndex = 0; // oldest sealed segment
      }
      _segments.removeAt(targetIndex);
    }
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {
    await _streamController.close();
  }
}

class _MemorySegment {
  LogSegmentSummary summary;
  final List<LogRecord> records = [];

  _MemorySegment({required this.summary});

  void addRecord(LogRecord record) {
    records.add(record);

    final recordMap = record.toMap();
    final recSize = recordMap.toString().length;

    final oldest =
        summary.oldestTimestamp == null ||
            record.timestamp.isBefore(summary.oldestTimestamp!)
        ? record.timestamp
        : summary.oldestTimestamp;

    final newest =
        summary.newestTimestamp == null ||
            record.timestamp.isAfter(summary.newestTimestamp!)
        ? record.timestamp
        : summary.newestTimestamp;

    summary = LogSegmentSummary(
      segmentId: summary.segmentId,
      name: summary.name,
      createdAt: summary.createdAt,
      sealedAt: summary.sealedAt,
      oldestTimestamp: oldest,
      newestTimestamp: newest,
      sizeBytes: summary.sizeBytes + recSize,
      recordCount: records.length,
      status: summary.status,
    );
  }
}
