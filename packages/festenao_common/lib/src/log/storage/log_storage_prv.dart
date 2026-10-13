import '../log_record.dart';
import 'log_storage.dart';

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
