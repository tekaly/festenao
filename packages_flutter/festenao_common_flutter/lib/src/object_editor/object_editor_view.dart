import 'package:festenao_common/data/object_editor.dart';
import 'package:flutter/material.dart';

import 'object_clipboard_flutter.dart';
import 'object_editor_dialogs.dart';
import 'object_value_editor.dart';

/// The tree of an object being edited, a row per field.
///
/// Like the firestore console record editor: each row shows the key, the value
/// in an editor fitting its type, and a menu to change the type, rename or
/// remove it; a map or a list expands to its children and offers to add one.
///
/// It edits the [ObjectEditor] in place and rebuilds on
/// [ObjectEditor.onChanged], so the same editor may be driven from elsewhere —
/// a reload, another widget — and this view follows.
///
/// Give [schema] to have the fields a `cv` model declares offered when adding
/// one; the view stays generic either way, a map is a map.
///
/// Every row copies and pastes: the whole tree at the root, a field, a nested
/// map, one item of a list — through [clipboard], which mirrors the clipboard
/// of the system, so a value crosses trees, backends and apps.
class ObjectEditorView extends StatefulWidget {
  /// The tree being edited.
  final ObjectEditor editor;

  /// The widget each type is edited with.
  final ObjectValueEditorRegistry? valueEditors;

  /// The fields offered when adding one to the root map, none by default.
  final CvObjectSchema? schema;

  /// True to show the tree without editing it.
  ///
  /// Copying still works: a viewer is for reading, and reading includes
  /// taking a copy.
  final bool readOnly;

  /// Where a copied value goes, the global one by default.
  final FlutterObjectClipboard? clipboard;

  /// Editor of [editor].
  const ObjectEditorView({
    super.key,
    required this.editor,
    this.valueEditors,
    this.schema,
    this.readOnly = false,
    this.clipboard,
  });

  @override
  State<ObjectEditorView> createState() => _ObjectEditorViewState();
}

class _ObjectEditorViewState extends State<ObjectEditorView> {
  final _collapsed = <String>{};

  ObjectEditor get editor => widget.editor;

  ObjectValueEditorRegistry get valueEditors =>
      widget.valueEditors ?? defaultObjectValueEditorRegistry;

  FlutterObjectClipboard get clipboard =>
      widget.clipboard ?? globalFlutterObjectClipboard;

  bool _isExpanded(ObjectNode node) => !_collapsed.contains('${node.path}');

  void _toggle(ObjectNode node) => setState(() {
    var key = '${node.path}';
    if (!_collapsed.remove(key)) {
      _collapsed.add(key);
    }
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<ObjectEditor>(
    stream: editor.onChanged,
    builder: (context, _) {
      var root = editor.rootNode;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The root has a row of its own, so the whole tree is copied,
          // pasted over and retyped like any other value.
          _buildRow(root, 0),
          if (root.isContainer) ..._buildChildren(root, 1),
        ],
      );
    },
  );

  List<Widget> _buildChildren(ObjectNode node, int level) => [
    for (var child in node.children) ..._buildNode(child, level),
    if (!widget.readOnly) _buildAddRow(node, level),
  ];

  List<Widget> _buildNode(ObjectNode node, int level) => [
    _buildRow(node, level),
    if (node.isContainer && _isExpanded(node))
      ..._buildChildren(node, level + 1),
  ];

  Widget _buildRow(ObjectNode node, int level) {
    var theme = Theme.of(context);
    var isContainer = node.isContainer;
    return Padding(
      // Keyed by path and type so the state of a value editor — the text
      // being typed — follows its field when the tree around it changes.
      key: ValueKey('${node.path}|${node.type.id}'),
      padding: EdgeInsets.only(left: level * 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            child: isContainer
                ? IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      _isExpanded(node)
                          ? Icons.arrow_drop_down
                          : Icons.arrow_right,
                    ),
                    onPressed: () => _toggle(node),
                  )
                : null,
          ),
          SizedBox(
            width: 140,
            child: Text(
              node.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: isContainer
                  ? Text(node.display, style: theme.textTheme.bodySmall)
                  : _buildValue(node),
            ),
          ),
          _buildMenu(node),
        ],
      ),
    );
  }

  Widget _buildValue(ObjectNode node) {
    var type = node.type;
    if (type == objectTypeUnknown || widget.readOnly) {
      return Text(node.display, style: Theme.of(context).textTheme.bodySmall);
    }
    return valueEditors.build(
      context,
      type,
      node.value,
      (value) => editor.setValueAt(node.path, value),
    );
  }

  Widget _buildMenu(ObjectNode node) {
    var isRoot = node.path.isRoot;
    var isField = node.key is String;
    var readOnly = widget.readOnly;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'copy', child: Text('Copy')),
        if (!readOnly) ...[
          const PopupMenuItem(value: 'paste', child: Text('Paste here')),
          if (node.type == objectTypeMap)
            const PopupMenuItem(
              value: 'pasteField',
              child: Text('Paste as a field'),
            ),
          if (node.type == objectTypeList)
            const PopupMenuItem(
              value: 'pasteItem',
              child: Text('Paste as an item'),
            ),
          const PopupMenuItem(value: 'type', child: Text('Change type')),
          if (isField && !isRoot)
            const PopupMenuItem(value: 'rename', child: Text('Rename')),
          if (!isRoot)
            const PopupMenuItem(value: 'remove', child: Text('Remove')),
        ],
      ],
      onSelected: (action) async {
        switch (action) {
          case 'copy':
            await _copy(node);
          case 'paste':
            await _paste(
              (data) =>
                  editor.setValueAt(node.path, data.value(editor.typeRegistry)),
            );
          case 'pasteField':
            var name = await objectEditorPromptText(
              context,
              title: 'Paste as a field of ${node.name}',
              labelText: 'Field name',
            );
            if (name == null || name.isEmpty) {
              return;
            }
            await _paste(
              (data) => editor.addField(
                node.path,
                name,
                value: data.value(editor.typeRegistry),
              ),
            );
          case 'pasteItem':
            await _paste(
              (data) => editor.addItem(
                node.path,
                value: data.value(editor.typeRegistry),
              ),
            );
          case 'type':
            var type = await objectEditorPromptType(
              context,
              editor.typeRegistry,
              title: 'Type of ${node.name}',
              current: node.type,
            );
            if (type != null) {
              editor.setTypeAt(node.path, type.id);
            }
          case 'rename':
            var name = await objectEditorPromptText(
              context,
              title: 'Rename ${node.name}',
              initialValue: '${node.key}',
            );
            if (name != null && name.isNotEmpty) {
              _run(() => editor.renameField(node.path, name));
            }
          case 'remove':
            _run(() => editor.removeAt(node.path));
        }
      },
    );
  }

  Widget _buildAddRow(ObjectNode node, int level) {
    var isMap = node.type == objectTypeMap;
    return Padding(
      padding: EdgeInsets.only(left: level * 16.0 + 32),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(isMap ? 'Add field' : 'Add item'),
          onPressed: () => isMap ? _addField(node) : _addItem(node),
        ),
      ),
    );
  }

  Future<void> _addField(ObjectNode node) async {
    var field = await objectEditorPromptNewField(
      context,
      editor.typeRegistry,
      // The known field names, only offered on the root map: a nested map is
      // not the model the schema describes.
      names: node.path.isRoot
          ? widget.schema?.missingFieldNames(node.value)
          : null,
      schema: node.path.isRoot ? widget.schema : null,
    );
    if (field == null) {
      return;
    }
    _run(() => editor.addField(node.path, field.name, typeId: field.typeId));
  }

  Future<void> _addItem(ObjectNode node) async {
    var type = await objectEditorPromptType(
      context,
      editor.typeRegistry,
      title: 'Type of the new item',
    );
    if (type != null) {
      _run(() => editor.addItem(node.path, typeId: type.id));
    }
  }

  Future<void> _copy(ObjectNode node) async {
    var data = await clipboard.copy(
      node.value,
      typeRegistry: editor.typeRegistry,
      label: '${node.path}',
    );
    _snack('Copied ${data.summary}');
  }

  /// Pastes what the clipboard holds, [apply] putting it where it belongs.
  Future<void> _paste(void Function(ObjectClipboardData data) apply) async {
    var data = await clipboard.read();
    if (data == null) {
      _snack('Nothing to paste');
      return;
    }
    _run(() => apply(data));
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Runs an edit, showing what it refused rather than throwing at the user.
  void _run(void Function() action) {
    try {
      action();
    } catch (e) {
      _snack('$e');
    }
  }
}
