import 'package:festenao_common/data/object_editor.dart';
import 'package:flutter/material.dart';

import '../explorer_ui/explorer_chip.dart';
import '../explorer_ui/explorer_scaffold.dart';
import 'object_clipboard_flutter.dart';
import 'object_editor_dialogs.dart';
import 'object_editor_screen.dart';
import 'object_value_editor.dart';

/// A screen listing the collections of an [ObjectRepository]: the stores of a
/// sembast or sdb database, the collections of a firestore instance.
///
/// Tapping one opens an [ObjectCollectionScreen], and a record from there
/// opens an [ObjectEditorScreen] — the same editor whatever the backend is.
///
/// ```dart
/// await goToObjectExplorerScreen(
///   context,
///   repository: SdbObjectRepository(db),
/// );
/// ```
class ObjectExplorerScreen extends StatefulWidget {
  /// The database being explored.
  final ObjectRepository repository;

  /// The widget each type is edited with.
  final ObjectValueEditorRegistry? valueEditors;

  /// Where a copied record goes, the global one by default.
  final FlutterObjectClipboard? clipboard;

  /// What backs [repository], shown beside the store count: the database
  /// kind, engine and version for one opened from a [FileSystemExplorer],
  /// nothing for a backend that has no such thing to say (firestore).
  final List<Widget> infoChips;

  /// Explorer of [repository].
  const ObjectExplorerScreen({
    super.key,
    required this.repository,
    this.valueEditors,
    this.clipboard,
    this.infoChips = const [],
  });

  @override
  State<ObjectExplorerScreen> createState() => _ObjectExplorerScreenState();
}

class _ObjectExplorerScreenState extends State<ObjectExplorerScreen> {
  late Future<List<ObjectCollection>> _loading = widget.repository
      .listCollections();

  @override
  Widget build(BuildContext context) => ExplorerScaffold(
    title: widget.repository.title,
    isReadOnly: widget.repository.isReadOnly,
    crumbs: [ExplorerCrumb(widget.repository.title)],
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Reload',
        onPressed: () => setState(() {
          _loading = widget.repository.listCollections();
        }),
      ),
    ],
    statusBar: FutureBuilder<List<ObjectCollection>>(
      future: _loading,
      builder: (context, snapshot) => ExplorerStatusBar(
        message: widget.repository.title,
        trailing: [
          ...widget.infoChips,
          if (snapshot.data case var collections?)
            ExplorerChip(label: '${collections.length} stores'),
        ],
      ),
    ),
    body: FutureBuilder<List<ObjectCollection>>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        var collections = snapshot.data;
        if (collections == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (collections.isEmpty) {
          return const Center(child: Text('No collection'));
        }
        return ListView.builder(
          itemCount: collections.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return ExplorerSectionHeader(
                label: 'Stores',
                trailing: ExplorerChip(label: '${collections.length}'),
              );
            }
            var collection = collections[index - 1];
            return ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(collection.name),
              trailing: collection.isReadOnly
                  ? const ExplorerChip(
                      label: 'read only',
                      icon: Icons.lock_outline,
                    )
                  : null,
              onTap: () => goToObjectCollectionScreen(
                context,
                collection: collection,
                valueEditors: widget.valueEditors,
                clipboard: widget.clipboard,
              ),
            );
          },
        );
      },
    ),
  );
}

/// A screen listing the ids of an [ObjectCollection]: the records of a store,
/// the documents of a firestore collection, the files of a directory.
///
/// A collection that may hold hidden records — a firestore document with no
/// data of its own but with sub-collections, see
/// [ObjectCollection.supportsHiddenIds] — offers to show them too.
///
/// Records with collections under them — firestore documents — each get a
/// sub-collections action beside the one opening the record, see
/// [onOpenSubCollections].
class ObjectCollectionScreen extends StatefulWidget {
  /// The collection being listed.
  final ObjectCollection collection;

  /// The widget each type is edited with.
  final ObjectValueEditorRegistry? valueEditors;

  /// Where a copied record goes, the global one by default.
  final FlutterObjectClipboard? clipboard;

  /// How many ids are listed at most.
  final int limit;

  /// Opens the collections under the record [id], null when records have
  /// none (a sembast or sdb store).
  ///
  /// A hidden record, which has nothing but them, opens them when tapped.
  final Future<void> Function(BuildContext context, String id)?
  onOpenSubCollections;

  /// Listing of [collection].
  const ObjectCollectionScreen({
    super.key,
    required this.collection,
    this.valueEditors,
    this.clipboard,
    this.limit = 200,
    this.onOpenSubCollections,
  });

  @override
  State<ObjectCollectionScreen> createState() => _ObjectCollectionScreenState();
}

class _ObjectCollectionScreenState extends State<ObjectCollectionScreen> {
  ObjectCollection get collection => widget.collection;

  /// True to list the hidden records too.
  var _showHidden = false;

  late Future<ObjectCollectionIds> _loading = _list();

  bool get _isReadOnly => collection.isReadOnly;

  FlutterObjectClipboard get _clipboard =>
      widget.clipboard ?? globalFlutterObjectClipboard;

  Future<ObjectCollectionIds> _list() async => _showHidden
      ? await collection.listIdsWithHidden(limit: widget.limit)
      : ObjectCollectionIds(await collection.listIds(limit: widget.limit));

  void _reload() => setState(() {
    _loading = _list();
  });

  void _toggleHidden() {
    _showHidden = !_showHidden;
    _reload();
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Copies the whole record, without opening it.
  Future<void> _copy(String id) async {
    try {
      var source = collection.source(id);
      var data = await _clipboard.copy(
        await source.read(),
        typeRegistry: source.typeRegistry,
        label: source.title,
      );
      _snack('Copied ${data.summary}');
    } catch (e) {
      _snack('$e');
    }
  }

  /// Writes what was copied over the record [id], or into a new one.
  Future<void> _paste({String? id}) async {
    var data = await _clipboard.read();
    if (data == null) {
      _snack('Nothing to paste');
      return;
    }
    if (!mounted) {
      return;
    }
    if (id == null) {
      var newId = await objectEditorPromptText(
        context,
        title: 'Paste as a new object',
        labelText: 'Id (empty for a generated one)',
      );
      if (newId == null) {
        return;
      }
      id = newId.isEmpty ? null : newId;
    } else {
      var confirmed = await objectEditorPromptConfirm(
        context,
        title: 'Paste over $id',
        message: 'Replace what it holds with ${data.summary}?',
        confirmText: 'Paste',
      );
      if (!confirmed) {
        return;
      }
    }
    try {
      var pastedId = await collection.paste(
        clipboard: _clipboard.clipboard,
        id: id,
      );
      _snack('Pasted into $pastedId');
    } catch (e) {
      _snack('$e');
    }
    _reload();
  }

  Future<void> _open(String id) async {
    await goToObjectEditorScreen(
      context,
      source: collection.source(id),
      valueEditors: widget.valueEditors,
      clipboard: widget.clipboard,
    );
    _reload();
  }

  /// A record can come and go with what is written under it: a hidden one
  /// appears with its first sub-collection document, and goes with the last.
  Future<void> _openSubCollections(String id) async {
    await widget.onOpenSubCollections!(context, id);
    _reload();
  }

  Future<void> _delete(String id) async {
    var confirmed = await objectEditorPromptConfirm(
      context,
      title: 'Delete $id',
      confirmText: 'Delete',
    );
    if (!confirmed) {
      return;
    }
    try {
      await collection.source(id).delete();
    } catch (e) {
      _snack('$e');
    }
    _reload();
  }

  Future<void> _add() async {
    var id = await objectEditorPromptText(
      context,
      title: 'New object',
      labelText: 'Id (empty for a generated one)',
    );
    if (id == null || !mounted) {
      return;
    }
    try {
      var source = id.isEmpty
          ? collection.source(await collection.add(<String, Object?>{}))
          : collection.source(id);
      if (!mounted) {
        return;
      }
      await goToObjectEditorScreen(
        context,
        source: source,
        valueEditors: widget.valueEditors,
      );
    } catch (e) {
      _snack('$e');
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) => ExplorerScaffold(
    title: collection.name,
    isReadOnly: _isReadOnly,
    crumbs: [ExplorerCrumb(collection.name)],
    actions: [
      if (collection.supportsHiddenIds)
        IconButton(
          icon: Icon(
            _showHidden
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          tooltip: _showHidden ? 'Hide hidden records' : 'Show hidden records',
          onPressed: _toggleHidden,
        ),
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Reload',
        onPressed: _reload,
      ),
    ],
    statusBar: FutureBuilder<ObjectCollectionIds>(
      future: _loading,
      builder: (context, snapshot) => ExplorerStatusBar(
        message: collection.name,
        trailing: [
          if (snapshot.data case var listed?) ...[
            ExplorerChip(label: '${listed.ids.length} records'),
            if (_showHidden)
              ExplorerChip(label: '${listed.hiddenIds.length} hidden'),
          ],
        ],
      ),
    ),
    body: FutureBuilder<ObjectCollectionIds>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        var listed = snapshot.data;
        if (listed == null) {
          return const Center(child: CircularProgressIndicator());
        }
        var ids = listed.ids;
        if (ids.isEmpty) {
          return const Center(child: Text('No object'));
        }
        return ListView.builder(
          itemCount: ids.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return ExplorerSectionHeader(
                label: 'Records',
                trailing: ExplorerChip(label: '${ids.length}'),
              );
            }
            var id = ids[index - 1];
            // A hidden record holds nothing to copy nor delete, but it can
            // be written, opening it empty.
            var isHidden = listed.isHidden(id);
            var hasSubCollections = widget.onOpenSubCollections != null;
            var hasMenu = !isHidden || !_isReadOnly;
            return ListTile(
              leading: Icon(
                isHidden
                    ? Icons.visibility_off_outlined
                    : Icons.description_outlined,
              ),
              title: isHidden
                  ? Row(
                      children: [
                        Flexible(child: Text(id)),
                        const SizedBox(width: 8),
                        const ExplorerChip(label: 'hidden'),
                      ],
                    )
                  : Text(id),
              trailing: !hasSubCollections && !hasMenu
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasSubCollections)
                          IconButton(
                            icon: const Icon(
                              Icons.folder_open_outlined,
                              size: 20,
                            ),
                            tooltip: 'Sub-collections',
                            onPressed: () => _openSubCollections(id),
                          ),
                        if (hasMenu)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            itemBuilder: (context) => [
                              if (isHidden)
                                const PopupMenuItem(
                                  value: 'open',
                                  child: Text('Open'),
                                )
                              else
                                const PopupMenuItem(
                                  value: 'copy',
                                  child: Text('Copy'),
                                ),
                              if (!_isReadOnly) ...[
                                const PopupMenuItem(
                                  value: 'paste',
                                  child: Text('Paste over'),
                                ),
                                if (!isHidden)
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                              ],
                            ],
                            onSelected: (action) => switch (action) {
                              'open' => _open(id),
                              'copy' => _copy(id),
                              'paste' => _paste(id: id),
                              'delete' => _delete(id),
                              _ => null,
                            },
                          ),
                      ],
                    ),
              onTap: () => isHidden && hasSubCollections
                  ? _openSubCollections(id)
                  : _open(id),
            );
          },
        );
      },
    ),
    floatingActionButton: _isReadOnly
        ? null
        : PopupMenuButton<String>(
            tooltip: 'New',
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'add', child: Text('New object')),
              PopupMenuItem(value: 'paste', child: Text('Paste as a new one')),
            ],
            onSelected: (action) => switch (action) {
              'add' => _add(),
              'paste' => _paste(),
              _ => null,
            },
            child: const FloatingActionButton(
              onPressed: null,
              child: Icon(Icons.add),
            ),
          ),
  );
}

/// Pushes an [ObjectExplorerScreen] on [repository].
Future<void> goToObjectExplorerScreen(
  BuildContext context, {
  required ObjectRepository repository,
  ObjectValueEditorRegistry? valueEditors,
  FlutterObjectClipboard? clipboard,
  List<Widget> infoChips = const [],
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => ObjectExplorerScreen(
      repository: repository,
      valueEditors: valueEditors,
      clipboard: clipboard,
      infoChips: infoChips,
    ),
  ),
);

/// Pushes an [ObjectCollectionScreen] on [collection].
Future<void> goToObjectCollectionScreen(
  BuildContext context, {
  required ObjectCollection collection,
  ObjectValueEditorRegistry? valueEditors,
  FlutterObjectClipboard? clipboard,
  Future<void> Function(BuildContext context, String id)? onOpenSubCollections,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => ObjectCollectionScreen(
      collection: collection,
      valueEditors: valueEditors,
      clipboard: clipboard,
      onOpenSubCollections: onOpenSubCollections,
    ),
  ),
);
