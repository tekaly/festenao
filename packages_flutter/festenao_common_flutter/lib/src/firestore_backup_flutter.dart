import 'package:festenao_common/data/firestore_backup.dart';
import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';

import 'object_editor/object_editor_dialogs.dart';

/// What a backup is written as.
enum FirestoreBackupFormat {
  /// One json file holding every document under its path.
  json,

  /// An sdb database, a store per collection.
  sdb,

  /// The tekaly synced source export: a jsonl document and its meta, what a
  /// synced database reads back.
  syncedSource,
}

/// What [FirestoreBackupFormat] is called, and what it writes.
extension FirestoreBackupFormatExt on FirestoreBackupFormat {
  /// What a menu displays.
  String get label => switch (this) {
    FirestoreBackupFormat.json => 'Json file',
    FirestoreBackupFormat.sdb => 'Sdb database',
    FirestoreBackupFormat.syncedSource => 'Synced source export',
  };

  /// A line under it.
  String get description => switch (this) {
    FirestoreBackupFormat.json =>
      'Every document under its path, types and all',
    FirestoreBackupFormat.sdb => 'A store per collection',
    FirestoreBackupFormat.syncedSource =>
      'The tekaly format, what a synced database reads back',
  };

  /// The extension the file takes.
  String get extension => switch (this) {
    FirestoreBackupFormat.json => '.json',
    FirestoreBackupFormat.sdb => '.db',
    FirestoreBackupFormat.syncedSource => '.jsonl',
  };
}

/// What a backup wrote.
class FirestoreBackupResult {
  /// What it was written as.
  final FirestoreBackupFormat format;

  /// The paths it wrote, relative to the explorer.
  final List<String> paths;

  /// How many documents, or lines for a synced source export.
  final int count;

  /// Result of a backup.
  FirestoreBackupResult({
    required this.format,
    required this.paths,
    required this.count,
  });

  /// What a snack says.
  String get summary =>
      '$count ${format == FirestoreBackupFormat.syncedSource ? 'lines' : 'documents'} '
      'to ${paths.join(', ')}';

  @override
  String toString() => 'FirestoreBackupResult($summary)';
}

/// Backs the firestore tree [rootPath] up into [explorer], as [format].
///
/// [rootPath] is a collection path, a document path, or null for the whole
/// instance. [name] is the file it writes, without its extension.
///
/// A synced source export ignores [rootPath] beyond using it as the root of
/// the source, since that export is the change log rather than a tree.
Future<FirestoreBackupResult> writeFirestoreBackup({
  required Firestore firestore,
  required FileSystemExplorer explorer,
  required String name,
  required FirestoreBackupFormat format,
  String? rootPath,
  String directoryPath = '',
  int? limit,
}) async {
  String pathOf(String suffix) =>
      directoryPath.isEmpty ? '$name$suffix' : '$directoryPath/$name$suffix';

  switch (format) {
    case FirestoreBackupFormat.syncedSource:
      var exportInfo = await firestoreSyncedSourceExportInMemory(
        firestore,
        rootPath: rootPath,
      );
      var files = syncedSourceExportFiles(exportInfo);
      var jsonlPath = pathOf('.jsonl');
      var metaPath = pathOf('.meta.json');
      await explorer.writeAsString(jsonlPath, files.jsonl);
      await explorer.writeAsString(metaPath, files.meta);
      return FirestoreBackupResult(
        format: format,
        paths: [jsonlPath, metaPath],
        count: files.lineCount,
      );

    case FirestoreBackupFormat.json:
      var backup = FirestoreBackup(firestore: firestore);
      var data = await _read(backup, rootPath, limit);
      var path = pathOf('.json');
      await explorer.writeAsString(path, backup.toJsonText(data));
      return FirestoreBackupResult(
        format: format,
        paths: [path],
        count: data.documentCount,
      );

    case FirestoreBackupFormat.sdb:
      var backup = FirestoreBackup(firestore: firestore);
      var data = await _read(backup, rootPath, limit);
      var path = pathOf('.db');
      var database = await explorer.createSdbDatabase(
        path,
        schema: firestoreBackupSdbSchema(data),
        onCreate: (database) => writeFirestoreBackupToSdb(
          data,
          database,
          typeRegistry: backup.typeRegistry,
        ),
      );
      await database.close();
      return FirestoreBackupResult(
        format: format,
        paths: [path],
        count: data.documentCount,
      );
  }
}

/// The tree [rootPath] names: a collection, a document, or everything.
Future<FirestoreBackupData> _read(
  FirestoreBackup backup,
  String? rootPath,
  int? limit,
) {
  if (rootPath == null || rootPath.isEmpty) {
    return backup.readAll(limit: limit);
  }
  // An even number of parts is a document, an odd one a collection.
  return rootPath.split('/').length.isEven
      ? backup.readDocument(rootPath)
      : backup.readCollection(rootPath, limit: limit);
}

/// Asks what to back up and where, then writes it.
///
/// Answers what it wrote, or null when the dialogs were dismissed.
Future<FirestoreBackupResult?> promptFirestoreBackup(
  BuildContext context, {
  required Firestore firestore,
  required FileSystemExplorer explorer,
  String? rootPath,
  String directoryPath = '',
}) async {
  var format = await showDialog<FirestoreBackupFormat>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text('Back up ${rootPath ?? 'everything'}'),
      children: [
        for (var format in FirestoreBackupFormat.values)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(format),
            child: ListTile(
              title: Text(format.label),
              subtitle: Text(format.description),
            ),
          ),
      ],
    ),
  );
  if (format == null || !context.mounted) {
    return null;
  }
  var suggested = (rootPath ?? 'firestore').replaceAll('/', '_');
  var name = await objectEditorPromptText(
    context,
    title: format.label,
    initialValue: suggested,
    labelText: 'Name (${format.extension})',
  );
  if (name == null || name.isEmpty) {
    return null;
  }
  return writeFirestoreBackup(
    firestore: firestore,
    explorer: explorer,
    name: name,
    format: format,
    rootPath: rootPath,
    directoryPath: directoryPath,
  );
}
