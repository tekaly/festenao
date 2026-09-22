import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:flutter/material.dart';

import 'explorer_ui/explorer_chip.dart';
import 'explorer_ui/explorer_scaffold.dart';
import 'object_editor/object_explorer_screen.dart';
import 'object_editor/object_value_editor.dart';

/// A database file and what it holds.
typedef FileSystemDatabaseEntry = (
  FileSystemEntry entry,
  FileSystemDatabaseKind kind,
);

/// The badges an opened [database] is shown with: its kind, the engine that
/// actually stores it, and its version — `sdb` and `sembast` alone don't say
/// whether a file sits on sqflite, the browser's indexeddb, or plain sembast.
List<Widget> fileSystemDatabaseInfoChips(FileSystemDatabase database) => [
  ExplorerChip(
    label: database.kind.name,
    tone: ExplorerChipTone.accent,
    tooltip: 'Database kind',
  ),
  ExplorerChip(
    label: database.engine,
    monospace: true,
    tooltip: 'Storage engine',
  ),
  ExplorerChip(label: 'v${database.version}', tooltip: 'Database version'),
];

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
        infoChips: fileSystemDatabaseInfoChips(database),
      );
    } finally {
      await database.close();
    }
    _reload();
  }

  String get _title =>
      widget.title ??
      switch (widget.kind) {
        FileSystemDatabaseKind.sembast => 'Sembast databases',
        FileSystemDatabaseKind.sdb => 'Sdb databases',
        null => 'Databases',
      };

  @override
  Widget build(BuildContext context) => ExplorerScaffold(
    title: _title,
    isReadOnly: explorer.isReadOnly,
    crumbs: [ExplorerCrumb(explorer.title), ExplorerCrumb(_title)],
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Reload',
        onPressed: _reload,
      ),
    ],
    statusBar: FutureBuilder<List<FileSystemDatabaseEntry>>(
      future: _loading,
      builder: (context, snapshot) => ExplorerStatusBar(
        message: explorer.title,
        trailing: [
          if (snapshot.data case var found?)
            ExplorerChip(label: '${found.length} found'),
        ],
      ),
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
          itemCount: found.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return ExplorerSectionHeader(
                label: 'Databases',
                trailing: ExplorerChip(label: '${found.length}'),
              );
            }
            var (entry, kind) = found[index - 1];
            return ListTile(
              leading: Icon(
                kind == FileSystemDatabaseKind.sdb
                    ? Icons.dns_outlined
                    : Icons.storage_outlined,
              ),
              title: Row(
                children: [
                  Flexible(child: Text(entry.name)),
                  const SizedBox(width: 8),
                  ExplorerChip(label: kind.name, tone: ExplorerChipTone.accent),
                ],
              ),
              subtitle: Text(entry.path),
              onTap: () => _open(found[index - 1]),
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
