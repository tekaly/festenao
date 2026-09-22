import 'package:festenao_common/data/object_editor.dart';
import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:flutter/material.dart';

import 'object_editor/object_clipboard_flutter.dart';
import 'object_editor/object_editor_dialogs.dart';
import 'object_editor/object_editor_screen.dart';
import 'object_editor/object_explorer_screen.dart';
import 'object_editor/object_value_editor.dart';

/// The icon a kind of entry is listed with.
IconData fileSystemEntryIcon(FileSystemEntryKind kind) => switch (kind) {
  FileSystemEntryKind.directory => Icons.folder_outlined,
  FileSystemEntryKind.json => Icons.data_object,
  FileSystemEntryKind.yaml => Icons.list_alt_outlined,
  FileSystemEntryKind.database => Icons.storage_outlined,
  FileSystemEntryKind.text => Icons.description_outlined,
  FileSystemEntryKind.binary => Icons.insert_drive_file_outlined,
};

/// A size in bytes, as a listing shows it.
String fileSystemFormatSize(int? size) {
  if (size == null) {
    return '';
  }
  if (size < 1024) {
    return '$size B';
  }
  if (size < 1024 * 1024) {
    return '${(size / 1024).toStringAsFixed(1)} kB';
  }
  return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// A screen browsing one directory of a [FileSystemExplorer].
///
/// Tapping an entry opens what it holds: a directory lists in turn, a json or
/// yaml document opens in the object editor, a sembast or sdb database file
/// opens in the object explorer, a text file opens in a text editor.
///
/// A read only explorer hides every write action, so
/// `explorer.readOnly` is all it takes to make this a viewer.
///
/// ```dart
/// await goToFileSystemExplorerScreen(
///   context,
///   explorer: FileSystemExplorer(fileSystem: fileSystemIo, rootPath: '.local'),
/// );
/// ```
class FileSystemExplorerScreen extends StatefulWidget {
  /// The file system being browsed.
  final FileSystemExplorer explorer;

  /// The directory this screen lists, the root of the explorer by default.
  final String path;

  /// The widget each type is edited with in the object editor.
  final ObjectValueEditorRegistry? valueEditors;

  /// Where a copied document goes, the global one by default.
  final FlutterObjectClipboard? clipboard;

  /// Explorer screen of [path].
  const FileSystemExplorerScreen({
    super.key,
    required this.explorer,
    this.path = '',
    this.valueEditors,
    this.clipboard,
  });

  @override
  State<FileSystemExplorerScreen> createState() =>
      _FileSystemExplorerScreenState();
}

class _FileSystemExplorerScreenState extends State<FileSystemExplorerScreen> {
  FileSystemExplorer get explorer => widget.explorer;

  String get path => widget.path;

  bool get isReadOnly => explorer.isReadOnly;

  late Future<List<FileSystemEntry>> _loading = explorer.list(path);

  FlutterObjectClipboard get _clipboard =>
      widget.clipboard ?? globalFlutterObjectClipboard;

  void _reload() => setState(() {
    _loading = explorer.list(path);
  });

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Runs an action, showing what the file system refused rather than
  /// throwing at the user.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _open(FileSystemEntry entry) async {
    switch (entry.kind) {
      case FileSystemEntryKind.directory:
        await goToFileSystemExplorerScreen(
          context,
          explorer: explorer,
          path: entry.path,
          valueEditors: widget.valueEditors,
          clipboard: widget.clipboard,
        );
      case FileSystemEntryKind.json:
      case FileSystemEntryKind.yaml:
        await goToObjectEditorScreen(
          context,
          source: explorer.objectSource(entry.path),
          valueEditors: widget.valueEditors,
          clipboard: widget.clipboard,
          title: entry.name,
        );
      case FileSystemEntryKind.database:
        await _openDatabase(entry);
      case FileSystemEntryKind.text:
        await goToFileSystemTextFileScreen(
          context,
          explorer: explorer,
          path: entry.path,
        );
      case FileSystemEntryKind.binary:
        _snack('${entry.name}: ${fileSystemFormatSize(entry.size)}');
    }
    _reload();
  }

  Future<void> _openDatabase(FileSystemEntry entry) async {
    FileSystemDatabase database;
    try {
      database = await explorer.openDatabase(entry.path);
    } catch (e) {
      _snack('${entry.name} is not a sembast nor an sdb database ($e)');
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
        clipboard: widget.clipboard,
      );
    } finally {
      // The database stays open while its screen is up, and no longer.
      await database.close();
    }
  }

  Future<void> _create(String extension, String content) async {
    var name = await objectEditorPromptText(
      context,
      title: 'New file',
      labelText: 'Name (${extension.isEmpty ? 'no extension' : extension})',
    );
    if (name == null || name.isEmpty) {
      return;
    }
    if (extension.isNotEmpty && !name.endsWith(extension)) {
      name = '$name$extension';
    }
    await _run(() async {
      var entry = await explorer.createFile(
        path.isEmpty ? name! : '$path/$name',
        content: content,
      );
      _reload();
      if (mounted) {
        await _open(entry);
      }
    });
  }

  Future<void> _createDirectory() async {
    var name = await objectEditorPromptText(
      context,
      title: 'New folder',
      labelText: 'Name',
    );
    if (name == null || name.isEmpty) {
      return;
    }
    await _run(
      () => explorer.createDirectory(path.isEmpty ? name : '$path/$name'),
    );
    _reload();
  }

  /// Copies the content of a json or yaml document.
  Future<void> _copy(FileSystemEntry entry) async {
    await _run(() async {
      var source = explorer.objectSource(entry.path);
      var data = await _clipboard.copy(
        await source.read(),
        typeRegistry: source.typeRegistry,
        label: entry.name,
      );
      _snack('Copied ${data.summary}');
    });
  }

  /// Writes what was copied into a json or yaml document.
  Future<void> _paste(FileSystemEntry entry) async {
    var data = await _clipboard.read();
    if (data == null) {
      _snack('Nothing to paste');
      return;
    }
    if (!mounted) {
      return;
    }
    var confirmed = await objectEditorPromptConfirm(
      context,
      title: 'Paste into ${entry.name}',
      message: 'Replace what it holds with ${data.summary}?',
      confirmText: 'Paste',
    );
    if (!confirmed) {
      return;
    }
    await _run(
      () => explorer
          .objectSource(entry.path)
          .paste(clipboard: _clipboard.clipboard),
    );
    _reload();
  }

  Future<void> _rename(FileSystemEntry entry) async {
    var name = await objectEditorPromptText(
      context,
      title: 'Rename ${entry.name}',
      initialValue: entry.name,
      labelText: 'Name',
    );
    if (name == null || name.isEmpty || name == entry.name) {
      return;
    }
    await _run(() => explorer.rename(entry.path, name));
    _reload();
  }

  Future<void> _delete(FileSystemEntry entry) async {
    var confirmed = await objectEditorPromptConfirm(
      context,
      title: 'Delete ${entry.name}',
      message: entry.isDirectory
          ? 'Delete the folder and everything in it?'
          : null,
      confirmText: 'Delete',
    );
    if (!confirmed) {
      return;
    }
    await _run(() => explorer.delete(entry.path));
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        path.isEmpty ? explorer.title : path,
        overflow: TextOverflow.fade,
      ),
      actions: [
        if (isReadOnly)
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
    body: FutureBuilder<List<FileSystemEntry>>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        var entries = snapshot.data;
        if (entries == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (entries.isEmpty) {
          return const Center(child: Text('Empty'));
        }
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            var entry = entries[index];
            return ListTile(
              leading: Icon(fileSystemEntryIcon(entry.kind)),
              title: Text(entry.name),
              subtitle: entry.isDirectory
                  ? null
                  : Text(fileSystemFormatSize(entry.size)),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                itemBuilder: (context) => [
                  if (entry.isObject)
                    const PopupMenuItem(value: 'copy', child: Text('Copy')),
                  if (!isReadOnly) ...[
                    if (entry.isObject)
                      const PopupMenuItem(
                        value: 'paste',
                        child: Text('Paste into'),
                      ),
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ],
                onSelected: (action) => switch (action) {
                  'copy' => _copy(entry),
                  'paste' => _paste(entry),
                  'rename' => _rename(entry),
                  'delete' => _delete(entry),
                  _ => null,
                },
              ),
              onTap: () => _open(entry),
            );
          },
        );
      },
    ),
    floatingActionButton: isReadOnly
        ? null
        : PopupMenuButton<String>(
            tooltip: 'New',
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'folder', child: Text('New folder')),
              PopupMenuItem(value: 'json', child: Text('New json file')),
              PopupMenuItem(value: 'yaml', child: Text('New yaml file')),
              PopupMenuItem(value: 'text', child: Text('New text file')),
            ],
            onSelected: (action) => switch (action) {
              'folder' => _createDirectory(),
              'json' => _create('.json', '{}\n'),
              'yaml' => _create('.yaml', ''),
              'text' => _create('.txt', ''),
              _ => null,
            },
            child: const FloatingActionButton(
              onPressed: null,
              child: Icon(Icons.add),
            ),
          ),
  );
}

/// A screen showing, and editing when the explorer allows it, a text file.
class FileSystemTextFileScreen extends StatefulWidget {
  /// The file system the file lives in.
  final FileSystemExplorer explorer;

  /// The path of the file, relative to the root of the explorer.
  final String path;

  /// Text screen of [path].
  const FileSystemTextFileScreen({
    super.key,
    required this.explorer,
    required this.path,
  });

  @override
  State<FileSystemTextFileScreen> createState() =>
      _FileSystemTextFileScreenState();
}

class _FileSystemTextFileScreenState extends State<FileSystemTextFileScreen> {
  FileSystemExplorer get explorer => widget.explorer;

  final _controller = TextEditingController();
  late Future<String> _loading = _load();
  var _isDirty = false;

  Future<String> _load() async {
    var content = await explorer.readAsString(widget.path);
    _controller.text = content;
    _isDirty = false;
    return content;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await explorer.writeAsString(widget.path, _controller.text);
      setState(() => _isDirty = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Saved ${widget.path}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.path, overflow: TextOverflow.fade),
      actions: [
        if (explorer.isReadOnly)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Icon(Icons.lock_outline, size: 20)),
          ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Reload',
          onPressed: () => setState(() {
            _loading = _load();
          }),
        ),
      ],
    ),
    body: FutureBuilder<String>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _controller,
            readOnly: explorer.isReadOnly,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onChanged: (_) {
              if (!_isDirty) {
                setState(() => _isDirty = true);
              }
            },
          ),
        );
      },
    ),
    floatingActionButton: explorer.isReadOnly
        ? null
        : FloatingActionButton(
            tooltip: _isDirty ? 'Save' : 'Nothing to save',
            onPressed: _isDirty ? _save : null,
            backgroundColor: _isDirty ? null : Theme.of(context).disabledColor,
            child: const Icon(Icons.save),
          ),
  );
}

/// Pushes a [FileSystemExplorerScreen] on [explorer], at [path].
Future<void> goToFileSystemExplorerScreen(
  BuildContext context, {
  required FileSystemExplorer explorer,
  String path = '',
  ObjectValueEditorRegistry? valueEditors,
  FlutterObjectClipboard? clipboard,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => FileSystemExplorerScreen(
      explorer: explorer,
      path: path,
      valueEditors: valueEditors,
      clipboard: clipboard,
    ),
  ),
);

/// Pushes a [FileSystemTextFileScreen] on the file [path] of [explorer].
Future<void> goToFileSystemTextFileScreen(
  BuildContext context, {
  required FileSystemExplorer explorer,
  required String path,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => FileSystemTextFileScreen(explorer: explorer, path: path),
  ),
);
