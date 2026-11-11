import 'dart:async';

import '../log_record.dart';
import 'log_storage.dart';

/// The operations still running (the appends the logger does not wait for),
/// waited for by a close.
class LogPendingOperations {
  final _pending = <Future<void>>{};

  /// Tracks [future] until it completes; returns a future completing like it
  /// (its error included).
  Future<T> track<T>(Future<T> future) {
    var done = Completer<void>();
    _pending.add(done.future);
    return future.whenComplete(() {
      _pending.remove(done.future);
      done.complete();
    });
  }

  /// Waits for the tracked operations, the ones started meanwhile included.
  Future<void> wait() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }
}

/// True when a [summary] whose records are all sent ([allSent], [recordCount]
/// records) becomes [logSegmentStatusFullySent]: a sealed segment, whether
/// its last records were sent now or before it was sealed.
bool logSegmentBecomesFullySent(
  LogSegmentSummary summary, {
  required bool allSent,
  required int recordCount,
}) => allSent && recordCount > 0 && summary.status == logSegmentStatusSealed;

/// Status of the segment receiving the new records.
const logSegmentStatusActive = 'active';

/// Status of a segment no longer receiving records.
const logSegmentStatusSealed = 'sealed';

/// Status of a sealed segment whose records are all sent.
const logSegmentStatusFullySent = 'fullySent';

/// [summary] with [record] of [sizeBytes] added.
LogSegmentSummary logSegmentSummaryAddRecord(
  LogSegmentSummary summary,
  LogRecord record,
  int sizeBytes,
) {
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
  return LogSegmentSummary(
    segmentId: summary.segmentId,
    name: summary.name,
    createdAt: summary.createdAt,
    sealedAt: summary.sealedAt,
    oldestTimestamp: oldest,
    newestTimestamp: newest,
    sizeBytes: summary.sizeBytes + sizeBytes,
    recordCount: summary.recordCount + 1,
    status: summary.status,
  );
}

/// [summary] with a new [status] (and [sealedAt] if set).
LogSegmentSummary logSegmentSummaryWithStatus(
  LogSegmentSummary summary,
  String status, {
  DateTime? sealedAt,
}) {
  return LogSegmentSummary(
    segmentId: summary.segmentId,
    name: summary.name,
    createdAt: summary.createdAt,
    sealedAt: sealedAt ?? summary.sealedAt,
    oldestTimestamp: summary.oldestTimestamp,
    newestTimestamp: summary.newestTimestamp,
    sizeBytes: summary.sizeBytes,
    recordCount: summary.recordCount,
    status: status,
  );
}

/// Replaces the summary of the same segment in [summaries].
void logSegmentSummariesReplace(
  List<LogSegmentSummary> summaries,
  LogSegmentSummary summary,
) {
  final idx = summaries.indexWhere((s) => s.segmentId == summary.segmentId);
  if (idx != -1) {
    summaries[idx] = summary;
  }
}

/// The segments (but the active one) whose newest record is older than
/// [maxAge].
List<LogSegmentSummary> logSegmentsOlderThan(
  List<LogSegmentSummary> summaries, {
  required String? activeSegmentId,
  required Duration maxAge,
}) {
  final now = DateTime.now().toUtc();
  return summaries
      .where(
        (seg) =>
            seg.segmentId != activeSegmentId &&
            seg.newestTimestamp != null &&
            now.difference(seg.newestTimestamp!) > maxAge,
      )
      .toList();
}

/// Index of the segment to purge first when over the size limit (a fully
/// sent one first, never the active one), -1 if none.
int logSegmentPurgeIndex(
  List<LogSegmentSummary> summaries, {
  required String? activeSegmentId,
}) {
  final fullySentIdx = summaries.indexWhere(
    (seg) =>
        seg.segmentId != activeSegmentId &&
        seg.status == logSegmentStatusFullySent,
  );
  if (fullySentIdx != -1) {
    return fullySentIdx;
  }
  return summaries.indexWhere((seg) => seg.segmentId != activeSegmentId);
}

/// [records] sorted by timestamp then paged.
List<LogRecord> logRecordsSortAndPage(
  List<LogRecord> records, {
  int? limit,
  int? offset,
  bool descending = true,
}) {
  if (descending) {
    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  } else {
    records.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  final start = offset ?? 0;
  if (start >= records.length) return [];

  if (limit != null) {
    final end = (start + limit).clamp(0, records.length);
    return records.sublist(start, end);
  }
  return records.sublist(start);
}
