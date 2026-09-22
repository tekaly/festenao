import 'package:tekaly_synced_db_common/synced_db_common_firestore.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';

/// The two files a synced source export is written as.
///
/// The tekaly export format is a jsonl document plus the meta that says which
/// change it was taken at, which is what an import reads back.
class SyncedSourceExportFiles {
  /// The records, one json object per line.
  final String jsonl;

  /// The meta: the last change id, the timestamp, the source version.
  final String meta;

  /// How many lines the jsonl holds.
  final int lineCount;

  /// Files holding [jsonl] and [meta].
  SyncedSourceExportFiles({
    required this.jsonl,
    required this.meta,
    required this.lineCount,
  });

  @override
  String toString() => 'SyncedSourceExportFiles($lineCount lines)';
}

/// The files of [exportInfo], ready to be written.
SyncedSourceExportFiles syncedSourceExportFiles(
  SyncedDbExportInfo exportInfo,
) => SyncedSourceExportFiles(
  jsonl: exportInfo.getJsonlExport(),
  meta: exportInfo.getMetaExport(),
  lineCount: exportInfo.data.length,
);

/// The tekaly export of the synced source rooted at [rootPath] of [firestore].
///
/// This is the source side of a synced database: the change log a
/// `SyncedDbSynchronizer` reads, exported in the same format a local synced
/// database exports itself in. The two match, which is what
/// `SyncedDbExportInfoCompareExt.findContentDifference` checks.
///
/// ```dart
/// var exportInfo = await firestoreSyncedSourceExportInMemory(firestore);
/// var files = syncedSourceExportFiles(exportInfo);
/// await explorer.writeAsString('export.jsonl', files.jsonl);
/// await explorer.writeAsString('export.meta.json', files.meta);
/// ```
Future<SyncedDbExportInfo> firestoreSyncedSourceExportInMemory(
  Firestore firestore, {
  String? rootPath,
}) async {
  var source = SyncedSourceFirestore(firestore: firestore, rootPath: rootPath);
  try {
    return await source.exportInMemory();
  } finally {
    await source.close();
  }
}

/// Imports [exportInfo] into the synced source rooted at [rootPath] of
/// [firestore], pushing each record as a new change.
Future<void> firestoreSyncedSourceImportFromMemory(
  Firestore firestore, {
  required SyncedDbExportInfo exportInfo,
  String? rootPath,
}) async {
  var source = SyncedSourceFirestore(firestore: firestore, rootPath: rootPath);
  try {
    await source.importFromMemory(exportInfo: exportInfo);
  } finally {
    await source.close();
  }
}
