import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:flutter/material.dart';
import 'package:idb_shim/sdb.dart';
import 'package:sembast/sembast.dart' as sembast;

import 'object_editor/object_editor_dialogs.dart';

/// Something the `+` menu of the file system explorer offers to create.
///
/// It is the hook an app extends that menu through: a sembast database seeded
/// the way the app wants it, an sdb database with the schema the app declares
/// (see [fileSystemCreateSdbDatabaseAction]), a template document, anything.
///
/// [create] is given the explorer and the directory the menu was opened in,
/// and answers the path of what it made so the explorer opens it, or null when
/// it made nothing — the name was not given, the user backed out.
class FileSystemCreateAction {
  /// What the menu displays.
  final String label;

  /// Creates something in [path] of [explorer].
  final Future<String?> Function(
    BuildContext context,
    FileSystemExplorer explorer,
    String path,
  )
  create;

  /// Action [label], performed by [create].
  const FileSystemCreateAction({required this.label, required this.create});

  @override
  String toString() => label;
}

/// Asks for a file name in [directoryPath], answering its path in the
/// explorer, or null when none was given.
///
/// [extension] is appended when the name does not carry it already.
Future<String?> fileSystemPromptNewPath(
  BuildContext context, {
  required String directoryPath,
  required String title,
  required String extension,
}) async {
  var name = await objectEditorPromptText(
    context,
    title: title,
    labelText: 'Name ($extension)',
  );
  if (name == null || name.isEmpty) {
    return null;
  }
  if (!name.endsWith(extension)) {
    name = '$name$extension';
  }
  return directoryPath.isEmpty ? name : '$directoryPath/$name';
}

/// Creates an empty sembast database, [onCreate] filling it when it is given.
///
/// ```dart
/// fileSystemCreateSembastDatabaseAction(
///   onCreate: (db) => myStore.record('main').put(db, {'hello': 'world'}),
/// )
/// ```
FileSystemCreateAction fileSystemCreateSembastDatabaseAction({
  String label = 'New sembast database',
  String extension = '.db',
  Future<void> Function(sembast.Database database)? onCreate,
}) => FileSystemCreateAction(
  label: label,
  create: (context, explorer, path) async {
    var newPath = await fileSystemPromptNewPath(
      context,
      directoryPath: path,
      title: label,
      extension: extension,
    );
    if (newPath == null) {
      return null;
    }
    // Created and closed again: the explorer opens it when it is tapped, and
    // a database left open would be a second handle on the same file.
    var database = await explorer.createSembastDatabase(
      newPath,
      onCreate: onCreate,
    );
    await database.close();
    return newPath;
  },
);

/// Creates an sdb database holding the stores [schema] declares, [onCreate]
/// filling it when it is given.
///
/// The schema is where the `cv` sdb helpers come in: declare the records as
/// `ScvStringRecordBase` models, the stores with `scvStringStoreFactory`, and
/// hand their `schema()` over.
///
/// ```dart
/// fileSystemCreateSdbDatabaseAction(
///   label: 'New notes database',
///   schema: SdbDatabaseSchema(stores: [noteStore.schema()]),
/// )
/// ```
FileSystemCreateAction fileSystemCreateSdbDatabaseAction({
  required SdbDatabaseSchema schema,
  String label = 'New sdb database',
  String extension = '.db',
  int version = 1,
  Future<void> Function(SdbDatabase database)? onCreate,
}) => FileSystemCreateAction(
  label: label,
  create: (context, explorer, path) async {
    var newPath = await fileSystemPromptNewPath(
      context,
      directoryPath: path,
      title: label,
      extension: extension,
    );
    if (newPath == null) {
      return null;
    }
    var database = await explorer.createSdbDatabase(
      newPath,
      schema: schema,
      version: version,
      onCreate: onCreate,
    );
    await database.close();
    return newPath;
  },
);

/// Creates a file holding [content].
FileSystemCreateAction fileSystemCreateFileAction({
  required String label,
  required String extension,
  String content = '',
}) => FileSystemCreateAction(
  label: label,
  create: (context, explorer, path) async {
    var newPath = await fileSystemPromptNewPath(
      context,
      directoryPath: path,
      title: label,
      extension: extension,
    );
    if (newPath == null) {
      return null;
    }
    await explorer.createFile(newPath, content: content);
    return newPath;
  },
);

/// Creates a binary file holding [bytes], edited in the hex editor.
FileSystemCreateAction fileSystemCreateBinaryFileAction({
  String label = 'New binary file',
  String extension = '.bin',
  List<int> bytes = const [],
}) => FileSystemCreateAction(
  label: label,
  create: (context, explorer, path) async {
    var newPath = await fileSystemPromptNewPath(
      context,
      directoryPath: path,
      title: label,
      extension: extension,
    );
    if (newPath == null) {
      return null;
    }
    await explorer.writeAsBytes(newPath, bytes);
    return newPath;
  },
);

/// What the `+` menu offers when nothing else is given: a folder and the four
/// kinds of file the explorer edits.
///
/// The folder is not one of these — the explorer makes it itself, having
/// nothing to create in it.
List<FileSystemCreateAction> defaultFileSystemCreateActions() => [
  fileSystemCreateFileAction(
    label: 'New json file',
    extension: '.json',
    content: '{}\n',
  ),
  fileSystemCreateFileAction(label: 'New yaml file', extension: '.yaml'),
  fileSystemCreateFileAction(label: 'New text file', extension: '.txt'),
  fileSystemCreateBinaryFileAction(),
];
