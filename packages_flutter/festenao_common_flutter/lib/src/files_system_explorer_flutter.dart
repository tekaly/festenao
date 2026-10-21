import 'package:festenao_common/data/object_editor.dart';
import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'explorer_ui/explorer_chip.dart';
import 'explorer_ui/explorer_find.dart';
import 'explorer_ui/explorer_scaffold.dart';
import 'explorer_ui/explorer_text_style.dart';
import 'file_system_create_action.dart';
import 'file_system_database_list.dart' show fileSystemDatabaseInfoChips;
import 'file_system_file_opener.dart';
import 'file_system_hex_editor.dart';
import 'file_system_transfer.dart';
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

/// What a file can be forced open as, regardless of what its extension
/// guesses — the answer to "open as…".
enum FileSystemOpenAsKind {
  /// A plain text file.
  text('Text', Icons.description_outlined),

  /// The raw bytes, in the hex editor.
  binary('Binary (hex)', Icons.insert_drive_file_outlined),

  /// A json document.
  json('Json', Icons.data_object),

  /// A yaml document.
  yaml('Yaml', Icons.list_alt_outlined),

  /// A plain sembast database.
  sembast('Sembast database', Icons.storage_outlined),

  /// An sdb (`idb_shim`) database.
  sdb('Sdb database (idb_shim)', Icons.dns_outlined);

  /// What the picker shows.
  final String label;

  /// The icon beside [label].
  final IconData icon;

  const FileSystemOpenAsKind(this.label, this.icon);
}

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

  /// What the `+` menu offers to create, beside the folder.
  ///
  /// [defaultFileSystemCreateActions] by default — a json, yaml, text and
  /// binary file. An app adds its own: a sembast database seeded its way, an
  /// sdb database with the schema it declares, a template document. See
  /// [FileSystemCreateAction], and `festenaoFileSystemDemoActions` for one
  /// populated demo of each kind.
  final List<FileSystemCreateAction>? createActions;

  /// True to show a "Select" action that picks this directory instead of
  /// opening what is tapped in it.
  ///
  /// The screen a caller pushes (over a read only explorer, `explorer.
  /// readOnly`) to ask "where?" — a destination to copy to, a folder to
  /// download — see [pickFileSystemDirectory].
  final bool isPicker;

  /// What [isPicker] shows in the app bar instead of the path, saying what
  /// the pick is for.
  final String? pickerTitle;

  /// The viewers the app plugs in for the formats the explorer does not know
  /// (`pbFileSystemOpener` of `pb_explorer_flutter.dart` for `.pb` files):
  /// a tap opens their files with them, "open as…" offers them for any file.
  final List<FileSystemFileOpener>? fileOpeners;

  /// The actions the app adds to the app bar, on the directory listed (and
  /// on the ones opened from it): a view of its own of the directory, for
  /// instance.
  final List<FileSystemDirectoryAction>? directoryActions;

  /// Explorer screen of [path].
  const FileSystemExplorerScreen({
    super.key,
    required this.explorer,
    this.path = '',
    this.valueEditors,
    this.clipboard,
    this.createActions,
    this.isPicker = false,
    this.pickerTitle,
    this.fileOpeners,
    this.directoryActions,
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

  late final List<FileSystemCreateAction> _createActions =
      widget.createActions ?? defaultFileSystemCreateActions();

  List<FileSystemFileOpener> get _fileOpeners => widget.fileOpeners ?? const [];

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
    if (entry.kind == FileSystemEntryKind.directory && widget.isPicker) {
      // Drilling further while picking: a pick made below is this screen's
      // own pick too, so it is popped straight back up.
      var picked = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => FileSystemExplorerScreen(
            explorer: explorer,
            path: entry.path,
            isPicker: true,
            pickerTitle: widget.pickerTitle,
          ),
        ),
      );
      if (picked != null && mounted) {
        Navigator.of(context).pop(picked);
      }
      return;
    }
    // A plugged in viewer comes before what the extension guesses.
    var opener = fileSystemFileOpenerOf(_fileOpeners, entry);
    if (opener != null) {
      await opener.open(context, explorer, entry.path);
      _reload();
      return;
    }
    switch (entry.kind) {
      case FileSystemEntryKind.directory:
        await goToFileSystemExplorerScreen(
          context,
          explorer: explorer,
          path: entry.path,
          valueEditors: widget.valueEditors,
          clipboard: widget.clipboard,
          createActions: widget.createActions,
          fileOpeners: widget.fileOpeners,
          directoryActions: widget.directoryActions,
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
        await goToFileSystemHexFileScreen(
          context,
          explorer: explorer,
          path: entry.path,
        );
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
        infoChips: fileSystemDatabaseInfoChips(database),
      );
    } finally {
      // The database stays open while its screen is up, and no longer.
      await database.close();
    }
  }

  /// Forces [entry] open as [kind], regardless of what its extension guesses.
  Future<void> _openAs(FileSystemEntry entry, FileSystemOpenAsKind kind) async {
    switch (kind) {
      case FileSystemOpenAsKind.text:
        await goToFileSystemTextFileScreen(
          context,
          explorer: explorer,
          path: entry.path,
        );
      case FileSystemOpenAsKind.binary:
        await goToFileSystemHexFileScreen(
          context,
          explorer: explorer,
          path: entry.path,
        );
      case FileSystemOpenAsKind.json:
        await goToObjectEditorScreen(
          context,
          source: explorer.objectSource(entry.path, format: objectJsonFormat),
          valueEditors: widget.valueEditors,
          clipboard: widget.clipboard,
          title: entry.name,
        );
      case FileSystemOpenAsKind.yaml:
        await goToObjectEditorScreen(
          context,
          source: explorer.objectSource(entry.path, format: objectYamlFormat),
          valueEditors: widget.valueEditors,
          clipboard: widget.clipboard,
          title: entry.name,
        );
      case FileSystemOpenAsKind.sembast:
        await _openAsDatabase(entry, FileSystemDatabaseKind.sembast);
      case FileSystemOpenAsKind.sdb:
        await _openAsDatabase(entry, FileSystemDatabaseKind.sdb);
    }
    _reload();
  }

  Future<void> _openAsDatabase(
    FileSystemEntry entry,
    FileSystemDatabaseKind kind,
  ) async {
    FileSystemDatabase database;
    try {
      database = await explorer.openDatabase(entry.path, kind: kind);
    } catch (e) {
      _snack('Not a ${kind.name} database ($e)');
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
        infoChips: fileSystemDatabaseInfoChips(database),
      );
    } finally {
      await database.close();
    }
  }

  /// The "open as…" picker: every [FileSystemOpenAsKind] and every plugged
  /// in [FileSystemFileOpener], whatever [entry]'s own extension guesses —
  /// the way out when the guess is wrong, or the file holds more than one
  /// thing worth looking at.
  Future<void> _pickOpenAs(FileSystemEntry entry) async {
    Widget option(Object value, IconData icon, String label) =>
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(value),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Text(label),
            ],
          ),
        );
    var choice = await showDialog<Object>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Open ${entry.name} as'),
        children: [
          for (var openAs in FileSystemOpenAsKind.values)
            option(openAs, openAs.icon, openAs.label),
          for (var opener in _fileOpeners)
            option(opener, opener.icon, opener.label),
        ],
      ),
    );
    if (choice == null || !mounted) {
      return;
    }
    switch (choice) {
      case FileSystemOpenAsKind kind:
        await _openAs(entry, kind);
      case FileSystemFileOpener opener:
        await opener.open(context, explorer, entry.path);
        _reload();
    }
  }

  /// What the file system reports about [entry]: kind, size, when it was
  /// last modified, and which [FileSystemOpenAsKind] it can be forced open
  /// as.
  Future<void> _showInfo(FileSystemEntry entry) async {
    var theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Path', entry.path.isEmpty ? '/' : entry.path),
              _infoRow('Kind', entry.kind.name),
              if (!entry.isDirectory)
                _infoRow('Size', fileSystemFormatSize(entry.size)),
              _infoRow(
                'Modified',
                entry.modified?.toLocal().toString() ?? 'unknown',
              ),
              const SizedBox(height: 8),
              Text(
                "Created and accessed times aren't reported across "
                'platforms by this file system layer.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (!entry.isDirectory) ...[
                const SizedBox(height: 12),
                Text('Open mode available', style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var openAs in FileSystemOpenAsKind.values)
                      ExplorerChip(label: openAs.label, icon: openAs.icon),
                    for (var opener in _fileOpeners)
                      ExplorerChip(label: opener.label, icon: opener.icon),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (!entry.isDirectory)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _pickOpenAs(entry);
              },
              child: const Text('Open as…'),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );

  /// Runs a create action and opens what it made.
  Future<void> _create(FileSystemCreateAction action) async {
    String? created;
    await _run(() async {
      created = await action.create(context, explorer, path);
    });
    _reload();
    if (created == null || !mounted) {
      return;
    }
    var entry = await explorer.entry(created!);
    if (entry != null && mounted) {
      await _open(entry);
    }
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

  /// Downloads [entry] to the device.
  Future<void> _download(FileSystemEntry entry) async {
    await _run(() => downloadFileSystemFile(explorer, entry));
  }

  /// Zips [directoryPath] (named [name] in the zip file name) and downloads
  /// it to the device.
  Future<void> _downloadZip(String directoryPath, String name) async {
    await _run(
      () => downloadFileSystemDirectoryAsZip(
        explorer,
        directoryPath,
        zipName: '$name.zip',
      ),
    );
  }

  /// Lets the user pick files from the device and writes them here.
  Future<void> _upload() async {
    List<String> written;
    try {
      written = await uploadFilesToFileSystem(explorer, path);
    } catch (e) {
      _snack('$e');
      return;
    }
    if (written.isNotEmpty) {
      _snack(
        written.length == 1
            ? 'Uploaded ${written.single}'
            : 'Uploaded ${written.length} files',
      );
    }
    _reload();
  }

  /// Lets the user pick a destination in this same explorer and copies
  /// [entry] there.
  Future<void> _copyTo(FileSystemEntry entry) async {
    var destination = await pickFileSystemDirectory(
      context,
      explorer: explorer,
      title: 'Copy ${entry.name} to',
    );
    if (destination == null || !mounted) {
      return;
    }
    await _run(() async {
      var newPath = await copyFileSystemEntryTo(explorer, entry, destination);
      _snack('Copied to $newPath');
    });
    _reload();
  }

  /// How deep in the tree this screen sits.
  int get _depth => path.isEmpty ? 0 : path.split('/').length;

  /// Goes back up to [target] segments deep.
  ///
  /// Each directory was pushed on the one above it, so going up is popping
  /// that many screens.
  void _goUp(int target) {
    var navigator = Navigator.of(context);
    for (var pops = _depth - target; pops > 0 && navigator.canPop(); pops--) {
      navigator.pop();
    }
  }

  /// The steps of the path, each one going back up to it.
  List<ExplorerCrumb> get _crumbs =>
      ExplorerBreadcrumb.ofPath(path, root: explorer.title, onTap: _goUp);

  @override
  Widget build(BuildContext context) => ExplorerScaffold(
    title: widget.pickerTitle ?? (path.isEmpty ? explorer.title : path),
    isReadOnly: isReadOnly,
    crumbs: _crumbs,
    actions: [
      if (widget.isPicker)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).pop(path),
            icon: const Icon(Icons.check),
            label: const Text('Select'),
          ),
        )
      else ...[
        for (var action
            in widget.directoryActions ?? <FileSystemDirectoryAction>[])
          IconButton(
            icon: Icon(action.icon),
            tooltip: action.label,
            onPressed: () => action.onPressed(context, explorer, path),
          ),
        IconButton(
          icon: const Icon(Icons.archive_outlined),
          tooltip: 'Download this folder as a zip',
          onPressed: () => _downloadZip(
            path,
            path.isEmpty ? explorer.title : path.split('/').last,
          ),
        ),
        if (!isReadOnly)
          IconButton(
            icon: const Icon(Icons.upload_outlined),
            tooltip: 'Upload from the device',
            onPressed: _upload,
          ),
      ],
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Reload',
        onPressed: _reload,
      ),
    ],
    statusBar: FutureBuilder<List<FileSystemEntry>>(
      future: _loading,
      builder: (context, snapshot) {
        var entries = snapshot.data;
        return ExplorerStatusBar(
          message: explorer.fileSystem.name,
          trailing: [
            if (entries != null) ...[
              ExplorerChip(
                label:
                    '${entries.where((entry) => entry.isDirectory).length} dirs',
              ),
              ExplorerChip(
                label:
                    '${entries.where((entry) => !entry.isDirectory).length} files',
              ),
            ],
          ],
        );
      },
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
          itemCount: entries.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return ExplorerSectionHeader(
                label: path.isEmpty ? 'Files' : path,
                trailing: ExplorerChip(label: '${entries.length}'),
              );
            }
            var entry = entries[index - 1];
            var opener = fileSystemFileOpenerOf(_fileOpeners, entry);
            return ListTile(
              leading: Icon(opener?.icon ?? fileSystemEntryIcon(entry.kind)),
              title: Row(
                children: [
                  Flexible(child: Text(entry.name)),
                  const SizedBox(width: 8),
                  ExplorerChip(
                    label: opener?.kindLabel ?? entry.kind.name,
                    tone: entry.isDatabase
                        ? ExplorerChipTone.accent
                        : ExplorerChipTone.neutral,
                  ),
                ],
              ),
              subtitle: entry.isDirectory
                  ? null
                  : Text(fileSystemFormatSize(entry.size)),
              trailing: widget.isPicker
                  ? null
                  : PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'info', child: Text('Info')),
                        if (!entry.isDirectory) ...[
                          const PopupMenuItem(
                            value: 'open_as',
                            child: Text('Open as…'),
                          ),
                          const PopupMenuItem(
                            value: 'download',
                            child: Text('Download'),
                          ),
                          const PopupMenuItem(
                            value: 'copy_to',
                            child: Text('Copy to…'),
                          ),
                        ] else
                          const PopupMenuItem(
                            value: 'download_zip',
                            child: Text('Download as zip'),
                          ),
                        if (entry.isObject)
                          const PopupMenuItem(
                            value: 'copy',
                            child: Text('Copy'),
                          ),
                        if (!isReadOnly) ...[
                          if (entry.isObject)
                            const PopupMenuItem(
                              value: 'paste',
                              child: Text('Paste into'),
                            ),
                          const PopupMenuItem(
                            value: 'rename',
                            child: Text('Rename'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ],
                      onSelected: (action) => switch (action) {
                        'info' => _showInfo(entry),
                        'open_as' => _pickOpenAs(entry),
                        'download' => _download(entry),
                        'download_zip' => _downloadZip(entry.path, entry.name),
                        'copy_to' => _copyTo(entry),
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
        : PopupMenuButton<int>(
            tooltip: 'New',
            itemBuilder: (context) => [
              const PopupMenuItem(value: -1, child: Text('New folder')),
              for (var (index, action) in _createActions.indexed)
                PopupMenuItem(value: index, child: Text(action.label)),
            ],
            onSelected: (index) =>
                index < 0 ? _createDirectory() : _create(_createActions[index]),
            child: const FloatingActionButton(
              onPressed: null,
              child: Icon(Icons.add),
            ),
          ),
  );
}

/// A screen showing, and editing when the explorer allows it, a text file,
/// in the monospace font.
///
/// Ctrl+F finds (any: case and accents ignored, or exact), the matches
/// highlighted, F3 or enter going from one to the next; ctrl+S saves. A file
/// that is not utf8 says so and offers the hex editor instead.
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

/// A text controller painting the find matches.
class _FindTextEditingController extends TextEditingController {
  List<TextRange> _matches = const [];
  var _current = -1;
  ({TextStyle match, TextStyle current})? _styles;

  void setMatches(
    List<TextRange> matches,
    int current,
    ({TextStyle match, TextStyle current}) styles,
  ) {
    _matches = matches;
    _current = current;
    _styles = styles;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    var styles = _styles;
    if (_matches.isEmpty ||
        styles == null ||
        (withComposing && value.isComposingRangeValid)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    var children = <TextSpan>[];
    var position = 0;
    for (var (index, match) in _matches.indexed) {
      // Matches of a text since changed: ignored until found again.
      if (match.start < position || match.end > text.length) {
        continue;
      }
      if (match.start > position) {
        children.add(TextSpan(text: text.substring(position, match.start)));
      }
      children.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: index == _current ? styles.current : styles.match,
        ),
      );
      position = match.end;
    }
    if (position < text.length) {
      children.add(TextSpan(text: text.substring(position)));
    }
    return TextSpan(style: style, children: children);
  }
}

class _FileSystemTextFileScreenState extends State<FileSystemTextFileScreen> {
  FileSystemExplorer get explorer => widget.explorer;

  bool get isReadOnly => explorer.isReadOnly;

  final _controller = _FindTextEditingController();
  final _editorFocusNode = FocusNode(debugLabel: 'text');
  final _fieldKey = GlobalKey();
  late final _find = ExplorerFindController(search: _search)
    ..addListener(_onFind);
  ExplorerTextFinder? _finder;
  TextRange? _lastMatch;
  var _revealCount = 0;
  late Future<String> _loading = _load();
  var _isDirty = false;

  Future<String> _load() async {
    var content = await explorer.readAsString(widget.path);
    _controller.text = content;
    _isDirty = false;
    _finder = null;
    _find.refresh();
    return content;
  }

  @override
  void dispose() {
    _find.dispose();
    _controller.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  List<TextRange> _search(String query, ExplorerFindMode mode) {
    var finder = _finder;
    if (finder == null || finder.text != _controller.text) {
      finder = _finder = ExplorerTextFinder(_controller.text);
    }
    return finder.find(query, mode);
  }

  void _onFind() {
    if (!mounted) {
      return;
    }
    _controller.setMatches(
      _find.matches,
      _find.current,
      explorerFindStyles(context),
    );
    var match = _find.currentMatch;
    if (match != null) {
      _lastMatch = match;
      if (_find.revealCount != _revealCount) {
        _revealCount = _find.revealCount;
        WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(match));
      }
    } else if (_find.isOpen) {
      _lastMatch = null;
    } else {
      // Closed: back in the text, on the last match.
      var last = _lastMatch;
      _lastMatch = null;
      if (last != null && last.end <= _controller.text.length) {
        _controller.selection = TextSelection(
          baseOffset: last.start,
          extentOffset: last.end,
        );
        _editorFocusNode.requestFocus();
      }
    }
  }

  /// Scrolls [match] into the view of the text field.
  void _reveal(TextRange match) {
    EditableTextState? editable;
    void visit(Element element) {
      if (editable != null) {
        return;
      }
      if (element is StatefulElement && element.state is EditableTextState) {
        editable = element.state as EditableTextState;
        return;
      }
      element.visitChildren(visit);
    }

    _fieldKey.currentContext?.visitChildElements(visit);
    if (editable != null && match.end <= _controller.text.length) {
      editable!.bringIntoView(TextPosition(offset: match.end));
      editable!.bringIntoView(TextPosition(offset: match.start));
    }
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _save() async {
    if (isReadOnly || !_isDirty) {
      return;
    }
    try {
      await explorer.writeAsString(widget.path, _controller.text);
      setState(() => _isDirty = false);
      _snack('Saved ${widget.path}');
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _openHex() async {
    await goToFileSystemHexFileScreen(
      context,
      explorer: explorer,
      path: widget.path,
    );
    if (!_isDirty && mounted) {
      setState(() {
        _loading = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
      const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
      ...explorerFindShortcuts(_find),
    },
    // Somewhere for the shortcuts to start from, before the text is focused
    // (read only, it never is).
    child: Focus(
      autofocus: true,
      child: ExplorerScaffold(
        title: widget.path,
        isReadOnly: isReadOnly,
        stateChip: isReadOnly
            ? null
            : _isDirty
            ? const ExplorerChip(
                label: 'unsaved',
                icon: Icons.edit_outlined,
                tone: ExplorerChipTone.accent,
              )
            : const ExplorerChip(label: 'saved', icon: Icons.check),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Find (Ctrl+F)',
            onPressed: _find.toggle,
          ),
          IconButton(
            icon: const Icon(Icons.data_array),
            tooltip: 'Open in the hex editor',
            onPressed: _openHex,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: () => setState(() {
              _loading = _load();
            }),
          ),
        ],
        statusBar: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            var text = _controller.text;
            var lines = text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;
            return ExplorerStatusBar(
              message: '$lines lines · ${text.length} chars',
              trailing: const [ExplorerChip(label: 'utf8')],
            );
          },
        ),
        body: FutureBuilder<String>(
          future: _loading,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${snapshot.error}', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: _openHex,
                        icon: const Icon(Icons.data_array),
                        label: const Text('Open in the hex editor'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                ExplorerFindBar(controller: _find),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: KeyedSubtree(
                      key: _fieldKey,
                      child: TextField(
                        controller: _controller,
                        focusNode: _editorFocusNode,
                        readOnly: isReadOnly,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: explorerMonospaceTextStyle,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          _find.refresh();
                          if (!_isDirty) {
                            setState(() => _isDirty = true);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: isReadOnly
            ? null
            : FloatingActionButton(
                tooltip: _isDirty ? 'Save (Ctrl+S)' : 'Nothing to save',
                onPressed: _isDirty ? _save : null,
                backgroundColor: _isDirty
                    ? null
                    : Theme.of(context).disabledColor,
                child: const Icon(Icons.save),
              ),
      ),
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
  List<FileSystemCreateAction>? createActions,
  List<FileSystemFileOpener>? fileOpeners,
  List<FileSystemDirectoryAction>? directoryActions,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => FileSystemExplorerScreen(
      explorer: explorer,
      path: path,
      valueEditors: valueEditors,
      clipboard: clipboard,
      createActions: createActions,
      fileOpeners: fileOpeners,
      directoryActions: directoryActions,
    ),
  ),
);

/// Lets the user browse [explorer] read only and pick a directory, null when
/// they cancel — the "where?" of a copy or a download, [title] saying what
/// for.
Future<String?> pickFileSystemDirectory(
  BuildContext context, {
  required FileSystemExplorer explorer,
  String path = '',
  String? title,
}) => Navigator.of(context).push<String>(
  MaterialPageRoute(
    builder: (_) => FileSystemExplorerScreen(
      explorer: explorer.readOnly,
      path: path,
      isPicker: true,
      pickerTitle: title,
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
