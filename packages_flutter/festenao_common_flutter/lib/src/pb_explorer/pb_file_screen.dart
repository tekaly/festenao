import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_app_pb/pb.dart';

import '../explorer_ui/explorer_chip.dart';
import '../explorer_ui/explorer_find.dart';
import '../explorer_ui/explorer_scaffold.dart';
import '../explorer_ui/explorer_text_style.dart';
import '../explorer_ui/explorer_text_view.dart';
import '../file_system_file_opener.dart';
import '../file_system_hex_editor.dart';
import '../object_editor/object_editor_dialogs.dart';
import 'pb_tree.dart';

/// The extensions [pbFileSystemOpener] opens on a tap.
const pbFileExtensions = <String>{'.pb', '.binpb', '.protobuf'};

Future<void> _openPbFile(
  BuildContext context,
  FileSystemExplorer explorer,
  String path,
) => goToPbFileScreen(context, explorer: explorer, path: path);

/// Plugs the protobuf viewer into the file system explorer: `.pb` files
/// open in a [PbFileScreen], and "open as…" offers it for any file.
///
/// ```dart
/// await goToFileSystemExplorerScreen(
///   context,
///   explorer: explorer,
///   fileOpeners: [pbFileSystemOpener],
/// );
/// ```
const pbFileSystemOpener = FileSystemFileOpener(
  label: 'Protobuf',
  icon: Icons.account_tree_outlined,
  kindLabel: 'protobuf',
  extensions: pbFileExtensions,
  open: _openPbFile,
);

const _monospace = explorerMonospaceTextStyle;

/// A screen browsing a protobuf file as a tree of fields, without any
/// schema, and editing it when the explorer allows it.
///
/// Each field shows its number, how it is laid out on the wire and its value;
/// an embedded message or a group expands into its own fields. The wire does
/// not say whether a length delimited value is text, a message, bytes or
/// packed numbers: it is guessed, and "view as" changes the guess. The text
/// view prints the whole file like `protoc --decode_raw`, and ctrl+F finds in
/// it (any: case and accents ignored, or exact).
///
/// Editing changes a value (in any of the formats its wire type allows),
/// renumbers, adds or deletes a field; the messages above it are encoded
/// again, the untouched fields keep their exact bytes.
class PbFileScreen extends StatefulWidget {
  /// The file system the file lives in.
  final FileSystemExplorer explorer;

  /// The path of the file, relative to the root of the explorer.
  final String path;

  /// Protobuf screen of [path].
  const PbFileScreen({super.key, required this.explorer, required this.path});

  @override
  State<PbFileScreen> createState() => _PbFileScreenState();
}

class _PbFileScreenState extends State<PbFileScreen> {
  FileSystemExplorer get explorer => widget.explorer;

  bool get isReadOnly => explorer.isReadOnly;

  late Future<void> _loading = _load();
  PbTree? _tree;
  FormatException? _formatError;
  var _size = 0;
  var _isDirty = false;
  var _showText = false;

  /// The text view, made once per change.
  String? _textCache;
  ExplorerTextFinder? _finder;
  late final _find = ExplorerFindController(search: _search);

  Future<void> _load() async {
    var bytes = await explorer.readAsBytes(widget.path);
    _size = bytes.length;
    _isDirty = false;
    _textCache = null;
    _finder = null;
    try {
      _tree = PbTree.decode(bytes);
      _formatError = null;
    } on FormatException catch (e) {
      _tree = null;
      _formatError = e;
    }
    _find.refresh();
    // The app bar and the status bar depend on what was read too.
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _find.dispose();
    super.dispose();
  }

  /// The whole file as text, like `protoc --decode_raw`.
  String get _text => _textCache ??= pbMessageToText(_tree!.message);

  List<TextRange> _search(String query, ExplorerFindMode mode) {
    if (_tree == null) {
      return const [];
    }
    var text = _text;
    var finder = _finder;
    if (finder == null || finder.text != text) {
      finder = _finder = ExplorerTextFinder(text);
    }
    return finder.find(query, mode);
  }

  /// Finds in the text view, showing it first.
  void _openFind() {
    if (_tree == null) {
      return;
    }
    if (!_showText) {
      setState(() => _showText = true);
    }
    _find.open();
  }

  void _toggleText() {
    setState(() {
      _showText = !_showText;
    });
    if (!_showText) {
      _find.close();
    }
  }

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

  void _changed() {
    setState(() {
      _isDirty = true;
      _size = _tree!.bytes.length;
      _textCache = null;
    });
    _find.refresh();
  }

  Future<void> _save() async {
    var tree = _tree;
    if (tree == null || !_isDirty) {
      return;
    }
    try {
      await explorer.writeAsBytes(widget.path, tree.bytes);
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
    if (!_isDirty) {
      _reload();
    }
  }

  Future<void> _copyText() async {
    var tree = _tree;
    if (tree == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: pbMessageToText(tree.message)));
    _snack('Copied as text');
  }

  void _toggle(PbNode node) => setState(() {
    node.expanded = !node.expanded;
  });

  /// The next free field number of [container].
  int _nextNumber(PbNode container) {
    var max = 0;
    for (var child in container.children) {
      if (child.number > max) {
        max = child.number;
      }
    }
    return max < pbMaxFieldNumber ? max + 1 : 1;
  }

  Future<void> _addField(PbNode container) async {
    var result = await showDialog<_PbFieldEdit>(
      context: context,
      builder: (context) => _PbFieldDialog(
        title: container.isRoot
            ? 'New field'
            : 'New field in ${container.number}',
        number: _nextNumber(container),
        formats: PbValueFormat.values,
        format: PbValueFormat.string,
      ),
    );
    if (result == null) {
      return;
    }
    container.add(result.number, result.value, view: result.format.view);
    _changed();
  }

  Future<void> _edit(PbNode node) async {
    var formats = pbEditFormatsOf(node.value, node.view);
    if (formats.isEmpty) {
      return;
    }
    var result = await showDialog<_PbFieldEdit>(
      context: context,
      builder: (context) => _PbFieldDialog(
        title: 'Field ${node.number}',
        number: node.number,
        value: node.value,
        formats: formats,
        format: formats.first,
      ),
    );
    if (result == null) {
      return;
    }
    if (result.number != node.number) {
      node.setNumber(result.number);
    }
    node.setValue(result.value, view: result.format.view);
    _changed();
  }

  Future<void> _renumber(PbNode node) async {
    var text = await objectEditorPromptText(
      context,
      title: 'Renumber field ${node.number}',
      initialValue: '${node.number}',
      labelText: 'Field number',
    );
    if (text == null) {
      return;
    }
    var number = int.tryParse(text.trim());
    if (number == null || number < 1 || number > pbMaxFieldNumber) {
      _snack('A field number is from 1 to $pbMaxFieldNumber');
      return;
    }
    if (number != node.number) {
      node.setNumber(number);
      _changed();
    }
  }

  Future<void> _delete(PbNode node) async {
    var confirmed = await objectEditorPromptConfirm(
      context,
      title: 'Delete field ${node.number}',
      message: node.isContainer ? 'Delete it and every field in it?' : null,
      confirmText: 'Delete',
    );
    if (!confirmed) {
      return;
    }
    node.remove();
    _changed();
  }

  Future<void> _pickView(PbNode node) async {
    var view = await showDialog<PbBytesView>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('View field ${node.number} as'),
        children: [
          for (var view in PbBytesView.values)
            SimpleDialogOption(
              onPressed: node.canView(view)
                  ? () => Navigator.of(context).pop(view)
                  : null,
              child: Row(
                children: [
                  Icon(
                    view == node.view
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    view.label,
                    style: node.canView(view)
                        ? null
                        : TextStyle(color: Theme.of(context).disabledColor),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (view != null) {
      setState(() {
        node.setView(view);
      });
    }
  }

  Future<void> _showDetails(PbNode node) async {
    var canEdit =
        !isReadOnly && pbEditFormatsOf(node.value, node.view).isNotEmpty;
    var edit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Field ${node.number}'),
        content: SingleChildScrollView(
          child: SelectionArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var (label, value) in pbNodeDetails(node))
                  _detailRow(label, value),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Close'),
          ),
          if (canEdit)
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Edit'),
            ),
        ],
      ),
    );
    if (edit == true && mounted) {
      await _edit(node);
    }
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value, style: _monospace)),
      ],
    ),
  );

  void _onRowAction(PbNode node, String action) {
    switch (action) {
      case 'details':
        _showDetails(node);
      case 'edit':
        _edit(node);
      case 'view':
        _pickView(node);
      case 'renumber':
        _renumber(node);
      case 'add':
        _addField(node);
      case 'delete':
        _delete(node);
      case 'copy':
        Clipboard.setData(ClipboardData(text: pbNodeCopyText(node)));
        _snack('Copied field ${node.number}');
    }
  }

  Widget _buildRow(PbTreeRow row) {
    var node = row.node;
    var theme = Theme.of(context);
    var isContainer = node.isContainer;
    var canEdit = pbEditFormatsOf(node.value, node.view).isNotEmpty;
    return InkWell(
      key: ValueKey(node),
      onTap: isContainer ? () => _toggle(node) : () => _showDetails(node),
      onLongPress: () => _showDetails(node),
      child: Padding(
        padding: EdgeInsets.only(left: 4.0 + row.depth * 18, right: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: isContainer
                  ? Icon(
                      node.expanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                    )
                  : null,
            ),
            Text(
              '${node.number}',
              style: _monospace.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 6),
            ExplorerChip(
              label: node.view?.label ?? pbWireTypeLabel(node.value.wireType),
              monospace: true,
              tone: isContainer
                  ? ExplorerChipTone.accent
                  : ExplorerChipTone.neutral,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                node.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _monospace,
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              tooltip: 'Field ${node.number}',
              onSelected: (action) => _onRowAction(node, action),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'details', child: Text('Details')),
                if (node.value is PbLengthDelimited)
                  const PopupMenuItem(value: 'view', child: Text('View as…')),
                const PopupMenuItem(value: 'copy', child: Text('Copy value')),
                if (!isReadOnly) ...[
                  if (canEdit)
                    const PopupMenuItem(value: 'edit', child: Text('Edit…')),
                  if (isContainer)
                    const PopupMenuItem(
                      value: 'add',
                      child: Text('Add a field…'),
                    ),
                  const PopupMenuItem(
                    value: 'renumber',
                    child: Text('Renumber…'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    var tree = _tree;
    if (tree == null) {
      return _buildFormatError();
    }
    if (_showText) {
      return Column(
        children: [
          ExplorerFindBar(controller: _find),
          Expanded(
            child: ExplorerTextView(text: _text, find: _find),
          ),
        ],
      );
    }
    var rows = tree.rows;
    if (rows.isEmpty) {
      return const Center(child: Text('No field'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: rows.length,
      itemBuilder: (context, index) => _buildRow(rows[index]),
    );
  }

  Widget _buildFormatError() {
    var error = _formatError;
    var offset = error?.offset;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text('Not a protobuf message'),
            const SizedBox(height: 4),
            Text(
              '${error?.message}${offset == null ? '' : ' at offset $offset'}',
              style: _monospace,
              textAlign: TextAlign.center,
            ),
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

  @override
  Widget build(BuildContext context) {
    var tree = _tree;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
        // The find shortcuts, showing the text view first.
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _openFind,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _openFind,
        const SingleActivator(LogicalKeyboardKey.f3): () =>
            _find.isOpen ? _find.next() : _openFind(),
        const SingleActivator(LogicalKeyboardKey.f3, shift: true):
            _find.previous,
      },
      child: Focus(
        autofocus: true,
        child: ExplorerScaffold(
          title: widget.path,
          isReadOnly: isReadOnly,
          stateChip: _isDirty
              ? const ExplorerChip(
                  label: 'unsaved',
                  icon: Icons.edit_outlined,
                  tone: ExplorerChipTone.accent,
                )
              : const ExplorerChip(label: 'saved', icon: Icons.check),
          actions: [
            if (tree != null) ...[
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Find in the text (Ctrl+F)',
                onPressed: _openFind,
              ),
              IconButton(
                icon: Icon(
                  _showText ? Icons.account_tree_outlined : Icons.notes,
                ),
                tooltip: _showText ? 'Show the tree' : 'Show as text',
                onPressed: _toggleText,
              ),
            ],
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload',
              onPressed: _reload,
            ),
            PopupMenuButton<VoidCallback>(
              onSelected: (action) => action(),
              itemBuilder: (context) => [
                if (tree != null) ...[
                  PopupMenuItem(
                    value: () => setState(tree.expandAll),
                    child: const ListTile(
                      leading: Icon(Icons.unfold_more),
                      title: Text('Expand all'),
                    ),
                  ),
                  PopupMenuItem(
                    value: () => setState(tree.collapseAll),
                    child: const ListTile(
                      leading: Icon(Icons.unfold_less),
                      title: Text('Collapse all'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _copyText,
                    child: const ListTile(
                      leading: Icon(Icons.copy_all_outlined),
                      title: Text('Copy as text'),
                    ),
                  ),
                ],
                PopupMenuItem(
                  value: _openHex,
                  child: const ListTile(
                    leading: Icon(Icons.data_array),
                    title: Text('Open in the hex editor'),
                  ),
                ),
              ],
            ),
          ],
          statusBar: ExplorerStatusBar(
            message: tree == null
                ? '$_size bytes'
                : '$_size bytes · ${tree.fields.length} top fields',
            trailing: [
              if (tree != null)
                const ExplorerChip(label: 'protobuf')
              else if (_formatError != null)
                const ExplorerChip(
                  label: 'invalid',
                  tone: ExplorerChipTone.danger,
                ),
            ],
          ),
          body: FutureBuilder<void>(
            future: _loading,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('${snapshot.error}'));
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildBody();
            },
          ),
          floatingActionButton: isReadOnly || tree == null
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'add',
                      tooltip: 'Add a top field',
                      onPressed: () => _addField(tree.root),
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'save',
                      tooltip: _isDirty ? 'Save (Ctrl+S)' : 'Nothing to save',
                      onPressed: _isDirty ? _save : null,
                      backgroundColor: _isDirty
                          ? null
                          : Theme.of(context).disabledColor,
                      child: const Icon(Icons.save),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// What the details of [node] list: each interpretation of its value.
List<(String, String)> pbNodeDetails(PbNode node) {
  var value = node.value;
  var details = <(String, String)>[
    ('Number', '${node.number}'),
    ('Wire', pbWireTypeLabel(value.wireType)),
  ];
  switch (value) {
    case PbVarint():
      details.addAll([
        ('uint64', value.toUnsignedString()),
        ('int64', '${value.toSignedBigInt()}'),
        ('int32', '${value.toInt32()}'),
        ('uint32', '${value.toUint32()}'),
        ('sint64', pbFormatValue(value, PbValueFormat.zigzag)),
        ('bool', '${value.toBool()}'),
        ('hex', '0x${value.toHex()}'),
      ]);
    case PbFixed32():
      details.addAll([
        ('fixed32', '${value.toUint32()}'),
        ('sfixed32', '${value.toInt32()}'),
        ('float', '${value.toFloat()}'),
        ('hex', '0x${value.toHex()}'),
      ]);
    case PbFixed64():
      details.addAll([
        ('fixed64', value.toUnsignedString()),
        ('sfixed64', '${value.toSignedBigInt()}'),
        ('double', '${value.toDouble()}'),
        ('hex', '0x${value.toHex()}'),
      ]);
    case PbGroup(:var message):
      details.add(('Fields', '${message.fields.length}'));
    case PbLengthDelimited():
      var bytes = value.rawBytes ?? const <int>[];
      details.add(('Length', '${bytes.length}'));
      details.add(('View', node.view?.label ?? ''));
      if (node.isContainer) {
        details.add(('Fields', '${node.children.length}'));
      }
      var text = value.tryDecodeString();
      if (text != null && !node.isContainer) {
        details.add(('string', text));
      }
      var packed = value.tryDecodePackedVarints();
      if (packed != null && node.view == PbBytesView.packedVarints) {
        details.add(('values', '${packed.length}'));
      }
      var shown = bytes.length > 256 ? bytes.sublist(0, 256) : bytes;
      details.add((
        'hex',
        '${pbFormatValue(PbBytes.fromList(shown), PbValueFormat.bytes)}'
            '${bytes.length > 256 ? ' …' : ''}',
      ));
  }
  return details;
}

/// What "copy value" puts in the clipboard: the text of a string, the text
/// format of a message, the value as the listing shows it otherwise.
String pbNodeCopyText(PbNode node) {
  var value = node.value;
  if (node.isContainer) {
    return pbMessageToText(node.message);
  }
  if (value is PbLengthDelimited && node.view == PbBytesView.string) {
    return value.tryDecodeString() ?? '';
  }
  if (value is PbLengthDelimited && node.view == PbBytesView.bytes) {
    return pbFormatValue(value, PbValueFormat.bytes);
  }
  return node.preview;
}

/// What the field dialog answers.
typedef _PbFieldEdit = ({int number, PbValue value, PbValueFormat format});

/// The dialog typing a field in: its number and its value, in one of
/// [formats].
class _PbFieldDialog extends StatefulWidget {
  final String title;
  final int number;
  final PbValue? value;
  final List<PbValueFormat> formats;
  final PbValueFormat format;

  const _PbFieldDialog({
    required this.title,
    required this.number,
    required this.formats,
    required this.format,
    this.value,
  });

  @override
  State<_PbFieldDialog> createState() => _PbFieldDialogState();
}

class _PbFieldDialogState extends State<_PbFieldDialog> {
  late final _numberController = TextEditingController(
    text: '${widget.number}',
  );
  late var _format = widget.format;
  late final _valueController = TextEditingController(text: _initialText);
  String? _error;

  String get _initialText {
    var value = widget.value;
    return value == null ? '' : pbFormatValue(value, _format);
  }

  @override
  void dispose() {
    _numberController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  bool get _isMultiline =>
      _format == PbValueFormat.string ||
      _format == PbValueFormat.bytes ||
      _format == PbValueFormat.packedVarints ||
      _format == PbValueFormat.packedFixed32 ||
      _format == PbValueFormat.packedFixed64;

  void _setFormat(PbValueFormat format) {
    setState(() {
      _format = format;
      _error = null;
      var value = widget.value;
      if (value != null) {
        // The same value, typed the other way.
        _valueController.text = pbFormatValue(value, format);
      }
    });
  }

  void _submit() {
    var number = int.tryParse(_numberController.text.trim());
    if (number == null || number < 1 || number > pbMaxFieldNumber) {
      setState(() => _error = 'A field number is from 1 to $pbMaxFieldNumber');
      return;
    }
    try {
      var value = pbParseValue(_valueController.text, _format);
      Navigator.of(context)
          .pop<_PbFieldEdit>((number: number, value: value, format: _format));
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _numberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Field number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PbValueFormat>(
              initialValue: _format,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: [
                for (var format in widget.formats)
                  DropdownMenuItem(value: format, child: Text(format.label)),
              ],
              onChanged: (format) {
                if (format != null) {
                  _setFormat(format);
                }
              },
            ),
            if (!_format.isEmptyContainer) ...[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('pbValue'),
                controller: _valueController,
                autofocus: true,
                style: _monospace,
                minLines: _isMultiline ? 3 : 1,
                maxLines: _isMultiline ? 12 : 1,
                decoration: InputDecoration(
                  labelText: 'Value',
                  border: const OutlineInputBorder(),
                  helperText: _helperOf(_format),
                ),
                onSubmitted: _isMultiline ? null : (_) => _submit(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: _submit, child: const Text('Ok')),
    ],
  );
}

String? _helperOf(PbValueFormat format) => switch (format) {
  PbValueFormat.integer ||
  PbValueFormat.fixed32 ||
  PbValueFormat.fixed64 => 'Decimal, or hex with 0x',
  PbValueFormat.zigzag => 'Signed decimal (sint32, sint64)',
  PbValueFormat.boolean => 'true or false',
  PbValueFormat.bytes => 'Hex bytes, spaces optional',
  PbValueFormat.packedVarints ||
  PbValueFormat.packedFixed32 ||
  PbValueFormat.packedFixed64 => 'Integers separated by commas',
  _ => null,
};

/// Pushes a [PbFileScreen] on the file [path] of [explorer].
Future<void> goToPbFileScreen(
  BuildContext context, {
  required FileSystemExplorer explorer,
  required String path,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => PbFileScreen(explorer: explorer, path: path),
  ),
);
