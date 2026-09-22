import 'package:festenao_common/data/object_editor.dart';
import 'package:flutter/material.dart';

import 'object_clipboard_flutter.dart';
import 'object_editor_dialogs.dart';
import 'object_editor_view.dart';
import 'object_value_editor.dart';

/// A screen editing the object of one [ObjectSource]: a json or yaml file, a
/// sembast or sdb record, a firestore document, a `cv` model.
///
/// It reads the source, shows it in an [ObjectEditorView] and writes it back
/// on save — with the edits it recorded, so a yaml file keeps its comments.
///
/// ```dart
/// await goToObjectEditorScreen(
///   context,
///   source: SdbObjectSource(database: db, store: store, key: 'main'),
/// );
/// ```
class ObjectEditorScreen extends StatefulWidget {
  /// Where the object is read from and written back to.
  final ObjectSource source;

  /// The widget each type is edited with.
  final ObjectValueEditorRegistry? valueEditors;

  /// The fields a `cv` model declares, offered when adding one.
  final CvObjectSchema? schema;

  /// The title of the screen, [ObjectSource.title] by default.
  final String? title;

  /// Where a copied value goes, the global one by default.
  final FlutterObjectClipboard? clipboard;

  /// Editor screen of [source].
  const ObjectEditorScreen({
    super.key,
    required this.source,
    this.valueEditors,
    this.schema,
    this.title,
    this.clipboard,
  });

  @override
  State<ObjectEditorScreen> createState() => _ObjectEditorScreenState();
}

class _ObjectEditorScreenState extends State<ObjectEditorScreen> {
  ObjectSource get source => widget.source;

  late ObjectSourceEditor _sourceEditor = ObjectSourceEditor(source);
  late Future<ObjectEditor> _loading = _sourceEditor.load();

  FlutterObjectClipboard get _clipboard =>
      widget.clipboard ?? globalFlutterObjectClipboard;

  /// Copies the whole object, without having to reach its root row.
  Future<void> _copyAll() async {
    var editor = _sourceEditor.editorOrNull;
    if (editor == null) {
      return;
    }
    var data = await _clipboard.copy(
      editor.value,
      typeRegistry: editor.typeRegistry,
      label: source.title,
    );
    _snack('Copied ${data.summary}');
  }

  /// Replaces the whole object with what was copied.
  Future<void> _pasteAll() async {
    var editor = _sourceEditor.editorOrNull;
    if (editor == null) {
      return;
    }
    var data = await _clipboard.read();
    if (data == null) {
      _snack('Nothing to paste');
      return;
    }
    editor.setRootValue(data.value(editor.typeRegistry));
    _snack('Pasted ${data.summary}');
  }

  @override
  void didUpdateWidget(ObjectEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another source was handed to the same screen: read it rather than keep
    // showing, and saving, the one before.
    if (!identical(oldWidget.source, source)) {
      _sourceEditor = ObjectSourceEditor(source);
      _loading = _sourceEditor.load();
    }
  }

  @override
  void dispose() {
    _sourceEditor.close();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await _sourceEditor.save();
      _snack('Saved ${source.title}');
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _reload() async {
    if (_sourceEditor.isDirty) {
      var confirmed = await objectEditorPromptConfirm(
        context,
        title: 'Reload',
        message: 'Drop the unsaved edits?',
        confirmText: 'Drop',
      );
      if (!confirmed) {
        return;
      }
    }
    setState(() {
      _loading = _sourceEditor.load();
    });
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title ?? source.title, overflow: TextOverflow.fade),
      actions: [
        if (source.isReadOnly)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Icon(Icons.lock_outline, size: 20)),
          ),
        IconButton(
          icon: const Icon(Icons.copy_all_outlined),
          tooltip: 'Copy the whole object',
          onPressed: _copyAll,
        ),
        if (!source.isReadOnly)
          IconButton(
            icon: const Icon(Icons.paste),
            tooltip: 'Paste the whole object',
            onPressed: _pasteAll,
          ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Reload',
          onPressed: _reload,
        ),
      ],
    ),
    body: FutureBuilder<ObjectEditor>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        var editor = snapshot.data;
        if (editor == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ObjectEditorView(
              editor: editor,
              valueEditors: widget.valueEditors,
              schema: widget.schema,
              readOnly: source.isReadOnly,
              clipboard: widget.clipboard,
            ),
            const SizedBox(height: 80),
          ],
        );
      },
    ),
    floatingActionButton: source.isReadOnly
        ? null
        : FutureBuilder<ObjectEditor>(
            future: _loading,
            builder: (context, snapshot) {
              var editor = snapshot.data;
              if (editor == null) {
                return const SizedBox.shrink();
              }
              return StreamBuilder<ObjectEditor>(
                stream: editor.onChanged,
                builder: (context, _) => FloatingActionButton(
                  tooltip: editor.isDirty ? 'Save' : 'Nothing to save',
                  onPressed: editor.isDirty ? _save : null,
                  backgroundColor: editor.isDirty
                      ? null
                      : Theme.of(context).disabledColor,
                  child: const Icon(Icons.save),
                ),
              );
            },
          ),
  );
}

/// Pushes an [ObjectEditorScreen] on [source].
Future<void> goToObjectEditorScreen(
  BuildContext context, {
  required ObjectSource source,
  ObjectValueEditorRegistry? valueEditors,
  CvObjectSchema? schema,
  String? title,
  FlutterObjectClipboard? clipboard,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => ObjectEditorScreen(
      source: source,
      valueEditors: valueEditors,
      schema: schema,
      title: title,
      clipboard: clipboard,
    ),
  ),
);
