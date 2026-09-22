import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fs_shim/fs.dart';
import 'package:fs_shim/fs_memory.dart' show newFileSystemMemory;
import 'package:idb_shim/sdb.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:sembast/sembast.dart' as sembast;
import 'package:tekartik_app_flutter_fs/fs.dart' as app_fs;

import 'file_system_create_action.dart';
import 'file_system_demo.dart';
import 'files_system_explorer_flutter.dart';
import 'object_editor/object_value_editor.dart';

/// One directory the file system explorer can be rooted at: the documents of
/// the app, its support directory, the temporary one, the current one…
///
/// [resolve] answers null when the platform has no such directory — there are
/// no downloads on android, no current directory on the web — and the picker
/// leaves it out.
class FileSystemRoot {
  /// What the picker displays.
  final String name;

  /// A line under it, the path once it is resolved.
  final String? description;

  /// The directory, null when this platform has none.
  final Future<Directory?> Function() resolve;

  /// Root [name], resolved by [resolve].
  const FileSystemRoot({
    required this.name,
    required this.resolve,
    this.description,
  });

  @override
  String toString() => name;
}

/// The directory of a root, null when it has none here or asking threw.
///
/// `path_provider` throws rather than answers on a platform that has no such
/// directory, which is exactly a root the picker should leave out.
Future<Directory?> _tryDirectory(Future<Directory?> Function() resolve) async {
  try {
    return await resolve();
  } catch (_) {
    return null;
  }
}

Directory? _wrap(FileSystem fileSystem, String? path) =>
    path == null ? null : fileSystem.directory(path);

/// The roots a debug menu offers, in order.
///
/// [fileSystem] is the platform one by default — the disk on mobile and
/// desktop, indexeddb on the web — so the same menu works everywhere.
/// [packageName] names the directory on linux and windows, where there is no
/// `path_provider` documents directory.
List<FileSystemRoot> festenaoFileSystemRoots({
  FileSystem? fileSystem,
  String? packageName,
}) {
  var fs = fileSystem ?? app_fs.fs;
  return [
    FileSystemRoot(
      name: 'Documents',
      description: 'What the app stores for the user',
      resolve: () => _tryDirectory(
        () => fs.getApplicationDocumentsDirectory(packageName: packageName),
      ),
    ),
    FileSystemRoot(
      name: 'Support',
      description: 'What the app stores for itself',
      resolve: () => _tryDirectory(fs.getApplicationSupportDirectory),
    ),
    FileSystemRoot(
      name: 'Temporary',
      description: 'Cleared by the system',
      resolve: () => _tryDirectory(() async {
        if (kIsWeb) {
          return null;
        }
        return _wrap(fs, (await path_provider.getTemporaryDirectory()).path);
      }),
    ),
    FileSystemRoot(
      name: 'Downloads',
      description: 'Desktop only',
      resolve: () => _tryDirectory(() async {
        if (kIsWeb) {
          return null;
        }
        return _wrap(fs, (await path_provider.getDownloadsDirectory())?.path);
      }),
    ),
    FileSystemRoot(
      name: 'External storage',
      description: 'Android only',
      resolve: () => _tryDirectory(() async {
        if (kIsWeb) {
          return null;
        }
        return _wrap(
          fs,
          (await path_provider.getExternalStorageDirectory())?.path,
        );
      }),
    ),
    FileSystemRoot(
      name: 'Current directory',
      description: 'Where the app was started',
      resolve: () async => kIsWeb ? null : fs.currentDirectory,
    ),
    FileSystemRoot(
      name: 'Memory',
      description: 'A scratch file system, gone when the app stops',
      resolve: () async => newFileSystemMemory().directory('/'),
    ),
  ];
}

/// The explorer of [directory], sandboxed so it cannot leave it.
///
/// Sandboxing is what makes a picked directory safe to hand to the explorer:
/// its paths are rooted there and `..` leads nowhere.
///
/// [sembastDatabaseFactory] and [sdbFactory] are the app's own, when it has
/// them: the explorer then opens and edits the very databases the app opened,
/// rather than a second handle on the same files. The sandbox is handled —
/// a factory is given the path below it, see
/// [FileSystemExplorer.nativePath].
FileSystemExplorer festenaoDirectoryExplorer(
  Directory directory, {
  bool isReadOnly = false,
  sembast.DatabaseFactory? sembastDatabaseFactory,
  SdbFactory? sdbFactory,
}) {
  var sandboxed = directory.fs.sandbox(path: directory.path);
  return FileSystemExplorer(
    fileSystem: sandboxed,
    rootPath: sandboxed.currentDirectory.path,
    isReadOnly: isReadOnly,
    sembastDatabaseFactory: sembastDatabaseFactory,
    sdbFactory: sdbFactory,
  );
}

/// A screen picking the directory the file system explorer opens on.
///
/// The roots come from `path_provider` through `tekartik_app_flutter_fs`, so
/// the same screen works on mobile, desktop and the web. Picking one opens a
/// [FileSystemExplorerScreen] on it, sandboxed.
///
/// It is meant for a debug menu:
///
/// ```dart
/// muiItem('File system explorer', () {
///   goToFileSystemRootPickerScreen(muiBuildContext);
/// });
/// ```
class FileSystemRootPickerScreen extends StatefulWidget {
  /// The roots offered, [festenaoFileSystemRoots] by default.
  final List<FileSystemRoot>? roots;

  /// True to open the explorer as a viewer.
  final bool isReadOnly;

  /// The widget each type is edited with in the object editor.
  final ObjectValueEditorRegistry? valueEditors;

  /// Names the directory on linux and windows.
  final String? packageName;

  /// The sembast factory the explorer opens databases with, the `fs_shim`
  /// bridge by default; give the app's own to edit its databases.
  final sembast.DatabaseFactory? sembastDatabaseFactory;

  /// The sdb factory the explorer opens databases with, the `fs_shim` bridge
  /// by default; give the app's own to edit its databases.
  final SdbFactory? sdbFactory;

  /// What the `+` menu of the explorer offers to create.
  ///
  /// [defaultFileSystemCreateActions] plus [festenaoFileSystemDemoActions] by
  /// default, so a debug menu can make a populated example of each kind and
  /// look at it straight away. An app passes its own — a sembast database
  /// seeded its way, an sdb database with the schema it declares.
  final List<FileSystemCreateAction>? createActions;

  /// Picker of one of [roots].
  const FileSystemRootPickerScreen({
    super.key,
    this.roots,
    this.isReadOnly = false,
    this.valueEditors,
    this.packageName,
    this.createActions,
    this.sembastDatabaseFactory,
    this.sdbFactory,
  });

  @override
  State<FileSystemRootPickerScreen> createState() =>
      _FileSystemRootPickerScreenState();
}

class _FileSystemRootPickerScreenState
    extends State<FileSystemRootPickerScreen> {
  late final List<FileSystemRoot> _roots =
      widget.roots ?? festenaoFileSystemRoots(packageName: widget.packageName);

  late Future<List<(FileSystemRoot, Directory)>> _loading = _resolve();

  /// The roots this platform actually has, with their directory.
  Future<List<(FileSystemRoot, Directory)>> _resolve() async {
    var resolved = <(FileSystemRoot, Directory)>[];
    for (var root in _roots) {
      var directory = await root.resolve();
      if (directory != null) {
        resolved.add((root, directory));
      }
    }
    return resolved;
  }

  late final List<FileSystemCreateAction> _createActions =
      widget.createActions ??
      [...defaultFileSystemCreateActions(), ...festenaoFileSystemDemoActions()];

  var _isReadOnly = false;

  @override
  void initState() {
    _isReadOnly = widget.isReadOnly;
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('File system'),
      actions: [
        IconButton(
          icon: Icon(_isReadOnly ? Icons.lock_outline : Icons.lock_open),
          tooltip: _isReadOnly ? 'Read only' : 'Read write',
          onPressed: () => setState(() {
            _isReadOnly = !_isReadOnly;
          }),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Reload',
          onPressed: () => setState(() {
            _loading = _resolve();
          }),
        ),
      ],
    ),
    body: FutureBuilder<List<(FileSystemRoot, Directory)>>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        var roots = snapshot.data;
        if (roots == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          children: [
            ListTile(
              leading: Icon(_isReadOnly ? Icons.lock_outline : Icons.lock_open),
              title: Text(_isReadOnly ? 'Read only' : 'Read write'),
              subtitle: Text(
                _isReadOnly
                    ? 'Browse and copy, nothing is written'
                    : 'Files and records can be edited',
              ),
              onTap: () => setState(() {
                _isReadOnly = !_isReadOnly;
              }),
            ),
            const Divider(),
            for (var (root, directory) in roots)
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: Text(root.name),
                subtitle: Text(directory.path),
                onTap: () => goToFileSystemExplorerScreen(
                  context,
                  explorer: festenaoDirectoryExplorer(
                    directory,
                    isReadOnly: _isReadOnly,
                    sembastDatabaseFactory: widget.sembastDatabaseFactory,
                    sdbFactory: widget.sdbFactory,
                  ),
                  valueEditors: widget.valueEditors,
                  createActions: _createActions,
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// Pushes a [FileSystemRootPickerScreen].
Future<void> goToFileSystemRootPickerScreen(
  BuildContext context, {
  List<FileSystemRoot>? roots,
  bool isReadOnly = false,
  ObjectValueEditorRegistry? valueEditors,
  String? packageName,
  List<FileSystemCreateAction>? createActions,
  sembast.DatabaseFactory? sembastDatabaseFactory,
  SdbFactory? sdbFactory,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => FileSystemRootPickerScreen(
      roots: roots,
      isReadOnly: isReadOnly,
      valueEditors: valueEditors,
      packageName: packageName,
      createActions: createActions,
      sembastDatabaseFactory: sembastDatabaseFactory,
      sdbFactory: sdbFactory,
    ),
  ),
);
