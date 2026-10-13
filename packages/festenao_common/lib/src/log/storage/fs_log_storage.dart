import 'dart:async';
import 'dart:convert';
import 'package:fs_shim/fs.dart';
import 'package:tekartik_common_utils/common_utils_import.dart' show Lock;
import '../log_record.dart';
import '../reader/log_query_filter.dart';
import 'log_storage.dart';
import 'log_storage_prv.dart';

/// File-system based implementation of [LogStorage] using `fs_shim`.
/// Supports line-delimited JSON log files (JSONL), rotation at 10MB, and master index tracking.
class FsLogStorage implements LogStorage {
  /// File system abstraction used for reading and writing files.
  final FileSystem fileSystem;

  /// Directory path where log files are stored.
  final String directoryPath;

  /// Maximum size of a segment file before rotating.
  final int maxSegmentSizeBytes;

  /// Maximum age of log entries before purge.
  final Duration maxAge;

  /// Maximum combined size of all log files before purge.
  final int maxTotalSizeBytes;

  final StreamController<LogRecord> _streamController =
      StreamController<LogRecord>.broadcast();

  final List<LogSegmentSummary> _segmentSummaries = [];
  LogSegmentSummary? _activeSegmentSummary;
  Future<void>? _initFuture;

  /// Appends, rewrites and reads one at a time (the logger does not wait for
  /// its appends).
  final _lock = Lock();

  /// Creates an [FsLogStorage] instance.
  FsLogStorage({
    required this.fileSystem,
    this.directoryPath = 'festenao_log_files',
    this.maxSegmentSizeBytes = 10 * 1024 * 1024,
    this.maxAge = const Duration(days: 14),
    this.maxTotalSizeBytes = 100 * 1024 * 1024,
  });

  Directory get _dir => fileSystem.directory(directoryPath);
  File get _masterIndexFile =>
      fileSystem.file('${_dir.path}/master_index.json');

  File _segmentFile(String segmentId) =>
      fileSystem.file('${_dir.path}/log_seg_$segmentId.jsonl');

  @override
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    if (!await _dir.exists()) {
      await _dir.create(recursive: true);
    }

    if (await _masterIndexFile.exists()) {
      final content = await _masterIndexFile.readAsString();
      if (content.isNotEmpty) {
        final rawList = jsonDecode(content) as List;
        for (final item in rawList) {
          if (item is Map<String, Object?>) {
            _segmentSummaries.add(LogSegmentSummary.fromMap(item));
          }
        }
      }
    }

    _segmentSummaries.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final seg in _segmentSummaries) {
      if (seg.status == logSegmentStatusActive) {
        _activeSegmentSummary = seg;
        break;
      }
    }

    _activeSegmentSummary ??= await _createNewSegmentSummary();
  }

  Future<LogSegmentSummary> _createNewSegmentSummary() async {
    final seq = _segmentSummaries.length + 1;
    final segId = 'seg_${DateTime.now().millisecondsSinceEpoch}_$seq';
    final file = _segmentFile(segId);

    final summary = LogSegmentSummary(
      segmentId: segId,
      name: file.path,
      createdAt: DateTime.now().toUtc(),
      sizeBytes: 0,
      recordCount: 0,
      status: logSegmentStatusActive,
    );

    _segmentSummaries.add(summary);
    await _saveMasterIndex();
    return summary;
  }

  Future<void> _saveMasterIndex() async {
    final list = _segmentSummaries.map((s) => s.toMap()).toList();
    await _masterIndexFile.writeAsString(jsonEncode(list));
  }

  @override
  Future<void> appendRecord(LogRecord record) async {
    await init();
    await _lock.synchronized(() async {
      final active = _activeSegmentSummary!;
      final file = _segmentFile(active.segmentId);

      final line = '${jsonEncode(record.toMap())}\n';
      final lineBytes = utf8.encode(line).length;

      await file.writeAsString(line, mode: FileMode.append);

      _streamController.add(record);

      _activeSegmentSummary = logSegmentSummaryAddRecord(
        active,
        record,
        lineBytes,
      );
      logSegmentSummariesReplace(_segmentSummaries, _activeSegmentSummary!);
      await _saveMasterIndex();

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

  Future<List<LogRecord>> _readSegmentRecords(String segmentId) async {
    final file = _segmentFile(segmentId);
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    final lines = content.split('\n');
    final results = <LogRecord>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final map = jsonDecode(line) as Map<String, Object?>;
        results.add(LogRecord.fromMap(map));
      } catch (_) {}
    }
    return results;
  }

  @override
  Future<List<LogRecord>> getUnsentRecords({int? limit}) async {
    await init();
    return await _lock.synchronized(() async {
      final results = <LogRecord>[];
      for (final segSummary in _segmentSummaries) {
        final records = await _readSegmentRecords(segSummary.segmentId);
        for (final rec in records) {
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
        final records = await _readSegmentRecords(segSummary.segmentId);
        var modified = false;
        var allSent = true;

        for (var i = 0; i < records.length; i++) {
          final rec = records[i];
          if (idSet.contains(rec.id)) {
            records[i] = rec.copyWith(sent: true, sentAt: now);
            modified = true;
          } else if (!records[i].sent) {
            allSent = false;
          }
        }

        if (modified) {
          final file = _segmentFile(segSummary.segmentId);
          final lines = records.map((r) => jsonEncode(r.toMap())).join('\n');
          await file.writeAsString(lines.isEmpty ? '' : '$lines\n');

          if (allSent &&
              records.isNotEmpty &&
              segSummary.status == logSegmentStatusSealed) {
            _segmentSummaries[segIdx] = logSegmentSummaryWithStatus(
              segSummary,
              logSegmentStatusFullySent,
            );
            await _saveMasterIndex();
          }
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
        final records = await _readSegmentRecords(segSummary.segmentId);
        results.addAll(records.where(filter.matches));
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
      logSegmentSummariesReplace(
        _segmentSummaries,
        logSegmentSummaryWithStatus(
          active,
          logSegmentStatusSealed,
          sealedAt: DateTime.now().toUtc(),
        ),
      );
      await _saveMasterIndex();
    }

    _activeSegmentSummary = await _createNewSegmentSummary();
  }

  Future<void> _deleteSegmentFile(String segmentId) async {
    final file = _segmentFile(segmentId);
    if (await file.exists()) {
      await file.delete();
    }
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
        await _deleteSegmentFile(seg.segmentId);
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
        final seg = _segmentSummaries.removeAt(targetIdx);
        await _deleteSegmentFile(seg.segmentId);
      }
      await _saveMasterIndex();
    });
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {
    // Wait for the pending writes.
    await _lock.synchronized(() {});
    await _streamController.close();
  }
}
