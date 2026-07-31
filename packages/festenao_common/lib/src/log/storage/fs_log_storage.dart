import 'dart:async';
import 'dart:convert';
import 'package:fs_shim/fs.dart';
import '../log_record.dart';
import '../reader/log_query_filter.dart';
import 'log_storage.dart';

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
  bool _initialized = false;

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
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

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
      if (seg.status == 'active') {
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
      status: 'active',
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
    final active = _activeSegmentSummary!;
    final file = _segmentFile(active.segmentId);

    final line = '${jsonEncode(record.toMap())}\n';
    final lineBytes = utf8.encode(line).length;

    await file.writeAsString(line, mode: FileMode.append);

    _streamController.add(record);

    final oldest =
        active.oldestTimestamp == null ||
            record.timestamp.isBefore(active.oldestTimestamp!)
        ? record.timestamp
        : active.oldestTimestamp;
    final newest =
        active.newestTimestamp == null ||
            record.timestamp.isAfter(active.newestTimestamp!)
        ? record.timestamp
        : active.newestTimestamp;

    _activeSegmentSummary = LogSegmentSummary(
      segmentId: active.segmentId,
      name: active.name,
      createdAt: active.createdAt,
      sealedAt: active.sealedAt,
      oldestTimestamp: oldest,
      newestTimestamp: newest,
      sizeBytes: active.sizeBytes + lineBytes,
      recordCount: active.recordCount + 1,
      status: active.status,
    );

    final idx = _segmentSummaries.indexWhere(
      (s) => s.segmentId == active.segmentId,
    );
    if (idx != -1) {
      _segmentSummaries[idx] = _activeSegmentSummary!;
    }
    await _saveMasterIndex();

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
  }

  @override
  Future<void> markAsSent(List<String> recordIds, {DateTime? sentAt}) async {
    await init();
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

        if (allSent && records.isNotEmpty && segSummary.status == 'sealed') {
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
          await _saveMasterIndex();
        }
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
      final records = await _readSegmentRecords(segSummary.segmentId);
      for (final rec in records) {
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
      await _saveMasterIndex();
    }

    _activeSegmentSummary = await _createNewSegmentSummary();
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
      final file = _segmentFile(seg.segmentId);
      if (await file.exists()) {
        await file.delete();
      }
    }

    int totalBytes() =>
        _segmentSummaries.fold(0, (sum, seg) => sum + seg.sizeBytes);

    while (totalBytes() > sizeLimit && _segmentSummaries.length > 1) {
      var targetIdx = -1;
      for (var i = 0; i < _segmentSummaries.length; i++) {
        if (_segmentSummaries[i].segmentId ==
            _activeSegmentSummary?.segmentId) {
          continue;
        }
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
        final file = _segmentFile(seg.segmentId);
        if (await file.exists()) {
          await file.delete();
        }
      } else {
        break;
      }
    }
    await _saveMasterIndex();
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {
    await _streamController.close();
  }
}
