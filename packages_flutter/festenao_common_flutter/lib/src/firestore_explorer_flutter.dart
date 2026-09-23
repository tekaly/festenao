import 'package:festenao_common/data/object_editor.dart';
import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';

import 'explorer_ui/explorer_chip.dart';
import 'explorer_ui/explorer_scaffold.dart';
import 'firestore_backup_flutter.dart';
import 'object_editor/object_clipboard_flutter.dart';
import 'object_editor/object_editor_dialogs.dart';
import 'object_editor/object_editor_screen.dart';
import 'object_editor/object_explorer_screen.dart';
import 'object_editor/object_value_editor.dart';

/// A screen browsing the collections of a firestore instance, or the ones
/// under a document.
///
/// It is the object explorer on a [FirestoreObjectRepository], so a document
/// is edited with the firestore types: a `timestamp` gets a date picker, a
/// `blob` edits as base64, a `geoPoint` as `latitude,longitude` and a
/// `documentReference` as its path — see [firestoreObjectTypeRegistry].
///
/// Listing the collections needs `FirestoreService.supportsListCollections`.
/// A backend that cannot list them — the rest api, a client sdk — shows the
/// paths given as [collectionPaths] instead, and the screen offers to add one
/// by hand, so a known collection is reachable either way.
///
/// A document of a collection opens in the object editor, or its
/// sub-collections open in another explorer, under that document — how the
/// whole tree is walked. A document with no data but with sub-collections is
/// hidden from a collection until asked for, and opens them straight away.
///
/// ```dart
/// await goToFirestoreExplorerScreen(context, firestore: firestore);
/// ```
///
/// A read only explorer is a viewer: the documents still copy, nothing writes.
class FirestoreExplorerScreen extends StatefulWidget {
  /// The instance being browsed.
  final Firestore firestore;

  /// The document the collections sit under, the root ones when null.
  final String? documentPath;

  /// The collection paths to show instead of listing them.
  final List<String>? collectionPaths;

  /// True to browse without writing.
  final bool isReadOnly;

  /// The widget each type is edited with.
  final ObjectValueEditorRegistry? valueEditors;

  /// Where a copied document goes, the global one by default.
  final FlutterObjectClipboard? clipboard;

  /// The title of the screen.
  final String? title;

  /// Where a backup is written, no backup being offered without one.
  ///
  /// It is the file system explorer of wherever backups belong — a directory
  /// the app picked, the documents directory, anywhere `fs_shim` reaches. See
  /// [promptFirestoreBackup].
  final FileSystemExplorer? backupExplorer;

  /// The directory of [backupExplorer] a backup is written in.
  final String backupDirectoryPath;

  /// Explorer of [firestore].
  const FirestoreExplorerScreen({
    super.key,
    required this.firestore,
    this.documentPath,
    this.collectionPaths,
    this.isReadOnly = false,
    this.valueEditors,
    this.clipboard,
    this.title,
    this.backupExplorer,
    this.backupDirectoryPath = '',
  });

  @override
  State<FirestoreExplorerScreen> createState() =>
      _FirestoreExplorerScreenState();
}

class _FirestoreExplorerScreenState extends State<FirestoreExplorerScreen> {
  Firestore get firestore => widget.firestore;

  /// The paths added by hand, for a backend that cannot list its collections.
  final _addedPaths = <String>[];

  late Future<List<ObjectCollection>> _loading = _repository()
      .listCollections();

  /// True when the collections have to be named rather than listed.
  bool get _mustName =>
      widget.collectionPaths != null ||
      !firestore.service.supportsListCollections;

  FirestoreObjectRepository _repository() => FirestoreObjectRepository(
    firestore,
    documentPath: widget.documentPath,
    collectionPaths: _mustName
        ? [...?widget.collectionPaths, ..._addedPaths]
        : null,
    title: widget.title ?? widget.documentPath ?? 'firestore',
    isReadOnly: widget.isReadOnly,
  );

  void _reload() => setState(() {
    _loading = _repository().listCollections();
  });

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// The full path of a collection named by hand, under the document when
  /// there is one.
  String _fullPath(String path) {
    var documentPath = widget.documentPath;
    return documentPath == null ? path : '$documentPath/$path';
  }

  Future<void> _addCollection() async {
    var path = await objectEditorPromptText(
      context,
      title: 'Collection',
      labelText: widget.documentPath == null
          ? 'Path (users, users/123/posts)'
          : 'Name, under ${widget.documentPath}',
    );
    if (path == null || path.isEmpty) {
      return;
    }
    setState(() {
      _addedPaths.add(_fullPath(path));
    });
    _reload();
  }

  /// Opens another explorer on the collections under the document of
  /// [collection] of id [id].
  Future<void> _openSubCollections(
    BuildContext context,
    ObjectCollection collection,
    String id,
  ) => goToFirestoreExplorerScreen(
    context,
    firestore: firestore,
    documentPath: '${collection.name}/$id',
    isReadOnly: widget.isReadOnly,
    valueEditors: widget.valueEditors,
    clipboard: widget.clipboard,
    backupExplorer: widget.backupExplorer,
    backupDirectoryPath: widget.backupDirectoryPath,
  );

  /// Opens the document the collections sit under.
  Future<void> _openParentDocument(String documentPath) =>
      goToFirestoreDocumentScreen(
        context,
        firestore: firestore,
        path: documentPath,
        isReadOnly: widget.isReadOnly,
        valueEditors: widget.valueEditors,
        clipboard: widget.clipboard,
      );

  /// Opens one document straight away, which is how a known path is reached
  /// without walking a collection that cannot be listed.
  Future<void> _openDocument() async {
    var path = await objectEditorPromptText(
      context,
      title: 'Document',
      labelText: 'Path (users/123)',
    );
    if (path == null || path.isEmpty || !mounted) {
      return;
    }
    var fullPath = _fullPath(path);
    if (fullPath.split('/').length.isOdd) {
      _snack('$fullPath is a collection, not a document');
      return;
    }
    await goToObjectEditorScreen(
      context,
      source: FirestoreObjectSource(
        firestore: firestore,
        path: fullPath,
        isReadOnly: widget.isReadOnly,
      ),
      valueEditors: widget.valueEditors,
      clipboard: widget.clipboard,
      title: fullPath,
    );
  }

  /// Backs up a tree — the one the screen is on, or one collection of it.
  Future<void> _backup({String? rootPath}) async {
    var explorer = widget.backupExplorer;
    if (explorer == null) {
      return;
    }
    try {
      var result = await promptFirestoreBackup(
        context,
        firestore: firestore,
        explorer: explorer,
        rootPath: rootPath ?? widget.documentPath,
        directoryPath: widget.backupDirectoryPath,
      );
      if (result != null) {
        _snack('Backed up ${result.summary}');
      }
    } catch (e) {
      _snack('$e');
    }
  }

  @override
  Widget build(BuildContext context) => ExplorerScaffold(
    title: widget.title ?? widget.documentPath ?? 'Firestore',
    isReadOnly: widget.isReadOnly,
    crumbs: ExplorerBreadcrumb.ofPath(
      widget.documentPath ?? '',
      root: widget.title ?? 'firestore',
    ),
    stateChip: ExplorerChip(
      label: _mustName ? 'named' : 'listed',
      icon: Icons.cloud_outlined,
      tone: ExplorerChipTone.accent,
    ),
    actions: [
      if (widget.documentPath case var documentPath?)
        IconButton(
          icon: const Icon(Icons.description_outlined),
          tooltip: 'Open $documentPath',
          onPressed: () => _openParentDocument(documentPath),
        ),
      if (widget.backupExplorer != null)
        IconButton(
          icon: const Icon(Icons.backup_outlined),
          tooltip: 'Back up',
          onPressed: _backup,
        ),
      IconButton(
        icon: const Icon(Icons.find_in_page_outlined),
        tooltip: 'Open a document',
        onPressed: _openDocument,
      ),
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Reload',
        onPressed: _reload,
      ),
    ],
    statusBar: FutureBuilder<List<ObjectCollection>>(
      future: _loading,
      builder: (context, snapshot) => ExplorerStatusBar(
        message: widget.documentPath ?? 'firestore',
        trailing: [
          if (snapshot.data case var collections?)
            ExplorerChip(label: '${collections.length} collections'),
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
          return Center(
            child: Text(
              _mustName ? 'No collection named yet, add one' : 'No collection',
            ),
          );
        }
        return ListView.builder(
          itemCount: collections.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return ExplorerSectionHeader(
                label: 'Collections',
                trailing: ExplorerChip(label: '${collections.length}'),
              );
            }
            var collection = collections[index - 1];
            return ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(collection.name),
              trailing: widget.backupExplorer == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.backup_outlined, size: 20),
                      tooltip: 'Back up ${collection.name}',
                      onPressed: () => _backup(rootPath: collection.name),
                    ),
              onTap: () => goToObjectCollectionScreen(
                context,
                collection: collection,
                valueEditors: widget.valueEditors,
                clipboard: widget.clipboard,
                onOpenSubCollections: (context, id) =>
                    _openSubCollections(context, collection, id),
              ),
            );
          },
        );
      },
    ),
    floatingActionButton: FloatingActionButton(
      tooltip: 'Add a collection',
      onPressed: _addCollection,
      child: const Icon(Icons.create_new_folder_outlined),
    ),
  );
}

/// Pushes a [FirestoreExplorerScreen] on [firestore].
Future<void> goToFirestoreExplorerScreen(
  BuildContext context, {
  required Firestore firestore,
  String? documentPath,
  List<String>? collectionPaths,
  bool isReadOnly = false,
  ObjectValueEditorRegistry? valueEditors,
  FlutterObjectClipboard? clipboard,
  String? title,
  FileSystemExplorer? backupExplorer,
  String backupDirectoryPath = '',
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => FirestoreExplorerScreen(
      firestore: firestore,
      documentPath: documentPath,
      collectionPaths: collectionPaths,
      isReadOnly: isReadOnly,
      valueEditors: valueEditors,
      clipboard: clipboard,
      title: title,
      backupExplorer: backupExplorer,
      backupDirectoryPath: backupDirectoryPath,
    ),
  ),
);

/// Pushes the object editor on one firestore document.
Future<void> goToFirestoreDocumentScreen(
  BuildContext context, {
  required Firestore firestore,
  required String path,
  bool isReadOnly = false,
  ObjectValueEditorRegistry? valueEditors,
  FlutterObjectClipboard? clipboard,
}) => goToObjectEditorScreen(
  context,
  source: FirestoreObjectSource(
    firestore: firestore,
    path: path,
    isReadOnly: isReadOnly,
  ),
  valueEditors: valueEditors,
  clipboard: clipboard,
  title: path,
);
