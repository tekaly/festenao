import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:flutter/material.dart';

import 'object_editor/object_explorer_screen.dart';
import 'object_editor/object_value_editor.dart';

/// A database file and what it holds.
typedef FileSystemDatabaseEntry = (
  FileSystemEntry entry,
  FileSystemDatabaseKind kind,
);

/// The databases under [path] of [explorer], walking the directories below it.
///
/// Every file whose extension says database is opened to tell a sembast one
/// from an sdb one, and a file that turns out to be neither is left out — so
/// the list is what can really be opened, not what is merely named `.db`.
///
/// [kind] keeps only the databases of that kind.
Future<List<FileSystemDatabaseEntry>> listFileSystemDatabases(
  FileSystemExplorer explorer, {
  String path = '',
  FileSystemDatabaseKind? kind,
  int maxDepth = 5,
}) async {
  var found = <FileSystemDatabaseEntry>[];
  Future<void> walk(String path, int depth) async {
    if (depth < 0) {
      return;
    }
    for (var entry in await explorer.list(path)) {
      if (entry.isDirectory) {
        await walk(entry.path, depth - 1);
      } else if (entry.isDatabase) {
        var entryKind = await explorer.databaseKind(entry.path);
        if (entryKind != null && (kind == null || entryKind == kind)) {
          found.add((entry, entryKind));
        }
      }
    }
  }

  await walk(path, maxDepth);
  return found;
}

/// A screen listing the databases of a file system and opening one.
///
/// It is the answer to "which databases are there?", which a path prompt is
/// not: it walks the tree, opens each candidate to tell what it holds, and
/// lists what can really be browsed.
///
/// ```dart
/// await goToFileSystemDatabaseListScreen(
///   context,
///   explorer: explorer,
///   kind: FileSystemDatabaseKind.sdb,
/// );
/// ```
class FileSystemDatabaseListScreen extends StatefulWidget {
  /// The file system being walked.
  final FileSystemExplorer explorer;

  /// The directory it starts at.
  final String path;

  /// Keeps only the databases of that kind, both when null.
  final FileSystemDatabaseKind? kind;

  /// The widget each type is edited with.
  final ObjectValueEditorRegistry? valueEditors;

  /// The title of the screen.
  final String? title;

  /// Database listing of [explorer].
  const FileSystemDatabaseListScreen({
    super.key,
    required this.explorer,
    this.path = '',
    this.kind,
    this.valueEditors,
    this.title,
  });

  @override
  State<FileSystemDatabaseListScreen> createState() =>
      _FileSystemDatabaseListScreenState();
}

class _FileSystemDatabaseListScreenState
    extends State<FileSystemDatabaseListScreen> {
  FileSystemExplorer get explorer => widget.explorer;

  late Future<List<FileSystemDatabaseEntry>> _loading = _load();

  Future<List<FileSystemDatabaseEntry>> _load() =>
      listFileSystemDatabases(explorer, path: widget.path, kind: widget.kind);

  void _reload() => setState(() {
    _loading = _load();
  });

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _open(FileSystemDatabaseEntry found) async {
    var (entry, kind) = found;
    FileSystemDatabase database;
    try {
      database = await explorer.openDatabase(entry.path, kind: kind);
    } catch (e) {
      _snack('$e');
      return;
    }
    try {
      if (!mounted) {
        return;
      }
      await goToObjectExplorerScreen(
        context,
        repository: database.repository,
        valueEditors: widget.valueEditors,
      );
    } finally {
      await database.close();
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.title ??
            switch (widget.kind) {
              FileSystemDatabaseKind.sembast => 'Sembast databases',
              FileSystemDatabaseKind.sdb => 'Sdb databases',
              null => 'Databases',
            },
      ),
      actions: [
        if (explorer.isReadOnly)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Icon(Icons.lock_outline, size: 20)),
          ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Reload',
          onPressed: _reload,
        ),
      ],
    ),
    body: FutureBuilder<List<FileSystemDatabaseEntry>>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        var found = snapshot.data;
        if (found == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (found.isEmpty) {
          return const Center(child: Text('No database here'));
        }
        return ListView.builder(
          itemCount: found.length,
          itemBuilder: (context, index) {
            var (entry, kind) = found[index];
            return ListTile(
              leading: Icon(
                kind == FileSystemDatabaseKind.sdb
                    ? Icons.dns_outlined
                    : Icons.storage_outlined,
              ),
              title: Text(entry.name),
              subtitle: Text('${entry.path} · ${kind.name}'),
              onTap: () => _open(found[index]),
            );
          },
        );
      },
    ),
  );
}

/// Pushes a [FileSystemDatabaseListScreen].
Future<void> goToFileSystemDatabaseListScreen(
  BuildContext context, {
  required FileSystemExplorer explorer,
  String path = '',
  FileSystemDatabaseKind? kind,
  ObjectValueEditorRegistry? valueEditors,
  String? title,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => FileSystemDatabaseListScreen(
      explorer: explorer,
      path: path,
      kind: kind,
      valueEditors: valueEditors,
      title: title,
    ),
  ),
);
