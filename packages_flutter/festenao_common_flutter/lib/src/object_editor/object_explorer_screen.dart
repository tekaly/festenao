import 'package:festenao_common/data/object_editor.dart';
import 'package:flutter/material.dart';

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

  /// Explorer of [repository].
  const ObjectExplorerScreen({
    super.key,
    required this.repository,
    this.valueEditors,
    this.clipboard,
  });

  @override
  State<ObjectExplorerScreen> createState() => _ObjectExplorerScreenState();
}

class _ObjectExplorerScreenState extends State<ObjectExplorerScreen> {
  late Future<List<ObjectCollection>> _loading = widget.repository
      .listCollections();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.repository.title),
      actions: [
        if (widget.repository.isReadOnly)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Icon(Icons.lock_outline, size: 20)),
          ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Reload',
          onPressed: () => setState(() {
            _loading = widget.repository.listCollections();
          }),
        ),
      ],
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
          itemCount: collections.length,
          itemBuilder: (context, index) {
            var collection = collections[index];
            return ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(collection.name),
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
class ObjectCollectionScreen extends StatefulWidget {
  /// The collection being listed.
  final ObjectCollection collection;

  /// The widget each type is edited with.
  final ObjectValueEditorRegistry? valueEditors;

  /// Where a copied record goes, the global one by default.
  final FlutterObjectClipboard? clipboard;

  /// How many ids are listed at most.
  final int limit;

  /// Listing of [collection].
  const ObjectCollectionScreen({
    super.key,
    required this.collection,
    this.valueEditors,
    this.clipboard,
    this.limit = 200,
  });

  @override
  State<ObjectCollectionScreen> createState() => _ObjectCollectionScreenState();
}

class _ObjectCollectionScreenState extends State<ObjectCollectionScreen> {
  ObjectCollection get collection => widget.collection;

  late Future<List<String>> _loading = collection.listIds(limit: widget.limit);

  bool get _isReadOnly => collection.isReadOnly;

  FlutterObjectClipboard get _clipboard =>
      widget.clipboard ?? globalFlutterObjectClipboard;

  void _reload() => setState(() {
    _loading = collection.listIds(limit: widget.limit);
  });

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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(collection.name),
      actions: [
        if (_isReadOnly)
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
    body: FutureBuilder<List<String>>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        var ids = snapshot.data;
        if (ids == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (ids.isEmpty) {
          return const Center(child: Text('No object'));
        }
        return ListView.builder(
          itemCount: ids.length,
          itemBuilder: (context, index) {
            var id = ids[index];
            return ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(id),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'copy', child: Text('Copy')),
                  if (!_isReadOnly) ...[
                    const PopupMenuItem(
                      value: 'paste',
                      child: Text('Paste over'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ],
                onSelected: (action) => switch (action) {
                  'copy' => _copy(id),
                  'paste' => _paste(id: id),
                  'delete' => _delete(id),
                  _ => null,
                },
              ),
              onTap: () async {
                await goToObjectEditorScreen(
                  context,
                  source: collection.source(id),
                  valueEditors: widget.valueEditors,
                  clipboard: widget.clipboard,
                );
                _reload();
              },
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
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => ObjectExplorerScreen(
      repository: repository,
      valueEditors: valueEditors,
      clipboard: clipboard,
    ),
  ),
);

/// Pushes an [ObjectCollectionScreen] on [collection].
Future<void> goToObjectCollectionScreen(
  BuildContext context, {
  required ObjectCollection collection,
  ObjectValueEditorRegistry? valueEditors,
  FlutterObjectClipboard? clipboard,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => ObjectCollectionScreen(
      collection: collection,
      valueEditors: valueEditors,
      clipboard: clipboard,
    ),
  ),
);
