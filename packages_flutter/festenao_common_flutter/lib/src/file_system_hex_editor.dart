import 'dart:convert';

import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:festenao_theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'explorer_ui/explorer_chip.dart';
import 'explorer_ui/explorer_scaffold.dart';
import 'object_editor/object_editor_dialogs.dart';

/// How many bytes a row of the hex dump holds.
const fileSystemHexBytesPerRow = 16;

/// The offset of a row, as a hex dump prints it: 8 hex digits.
String fileSystemHexOffset(int offset) =>
    offset.toRadixString(16).padLeft(8, '0');

/// [bytes] as the hex pair of each one, space separated, padded to
/// [fileSystemHexBytesPerRow] so the columns line up on the last row.
String fileSystemHexBytes(List<int> bytes) {
  var pairs = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .toList();
  while (pairs.length < fileSystemHexBytesPerRow) {
    pairs.add('  ');
  }
  return pairs.join(' ');
}

/// [bytes] as the text column of a hex dump: the printable ascii ones as
/// themselves, everything else as a dot.
String fileSystemHexText(List<int> bytes) => String.fromCharCodes(
  bytes.map((byte) => byte >= 0x20 && byte < 0x7f ? byte : 0x2e),
);

/// The hex pairs [text] holds, null when it is not a run of them.
///
/// It takes what a row of the dump shows back, spaces optional, so a row can
/// be retyped as `48 65 6c 6c 6f` or `48656c6c6f`.
List<int>? fileSystemHexParse(String text) {
  var cleaned = text.replaceAll(RegExp(r'\s+'), '');
  if (cleaned.isEmpty) {
    return [];
  }
  if (cleaned.length.isOdd) {
    return null;
  }
  var bytes = <int>[];
  for (var i = 0; i < cleaned.length; i += 2) {
    var byte = int.tryParse(cleaned.substring(i, i + 2), radix: 16);
    if (byte == null) {
      return null;
    }
    bytes.add(byte);
  }
  return bytes;
}

/// A screen showing, and editing when the explorer allows it, a file as hex.
///
/// The classic dump — offset, the bytes of the row in hex, the printable ones
/// as text — plus, above it, the whole content decoded as text when it is
/// valid utf8, which is what tells a mislabelled text file from a real binary
/// one at a glance.
///
/// A row is edited by tapping it and retyping its bytes; the row may be given
/// fewer or more of them, so the file grows and shrinks from its end.
class FileSystemHexFileScreen extends StatefulWidget {
  /// The file system the file lives in.
  final FileSystemExplorer explorer;

  /// The path of the file, relative to the root of the explorer.
  final String path;

  /// Hex screen of [path].
  const FileSystemHexFileScreen({
    super.key,
    required this.explorer,
    required this.path,
  });

  @override
  State<FileSystemHexFileScreen> createState() =>
      _FileSystemHexFileScreenState();
}

class _FileSystemHexFileScreenState extends State<FileSystemHexFileScreen> {
  FileSystemExplorer get explorer => widget.explorer;

  bool get isReadOnly => explorer.isReadOnly;

  late Future<Uint8List> _loading = _load();
  var _bytes = <int>[];
  var _isDirty = false;
  var _showText = true;

  Future<Uint8List> _load() async {
    var bytes = await explorer.readAsBytes(widget.path);
    _bytes = bytes.toList();
    _isDirty = false;
    return bytes;
  }

  /// The whole content as text, null when it is not valid utf8 — which is what
  /// makes the preview worth showing or not.
  String? get _text {
    try {
      return const Utf8Decoder().convert(_bytes);
    } catch (_) {
      return null;
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
    try {
      await explorer.writeAsBytes(widget.path, _bytes);
      setState(() => _isDirty = false);
      _snack('Saved ${widget.path}');
    } catch (e) {
      _snack('$e');
    }
  }

  /// Retypes the bytes of the row starting at [offset].
  Future<void> _editRow(int offset) async {
    var end = (offset + fileSystemHexBytesPerRow).clamp(0, _bytes.length);
    var row = _bytes.sublist(offset, end);
    var text = await objectEditorPromptText(
      context,
      title: fileSystemHexOffset(offset),
      initialValue: fileSystemHexBytes(row).trim(),
      labelText: 'Bytes, in hex',
    );
    if (text == null) {
      return;
    }
    var parsed = fileSystemHexParse(text);
    if (parsed == null) {
      _snack('Not a run of hex bytes');
      return;
    }
    if (parsed.length > fileSystemHexBytesPerRow) {
      _snack('At most $fileSystemHexBytesPerRow bytes in a row');
      return;
    }
    setState(() {
      _bytes.replaceRange(offset, end, parsed);
      _isDirty = true;
    });
  }

  Future<void> _append() async {
    var text = await objectEditorPromptText(
      context,
      title: 'Append',
      labelText: 'Bytes, in hex',
    );
    if (text == null || text.isEmpty) {
      return;
    }
    var parsed = fileSystemHexParse(text);
    if (parsed == null) {
      _snack('Not a run of hex bytes');
      return;
    }
    setState(() {
      _bytes.addAll(parsed);
      _isDirty = true;
    });
  }

  Future<void> _copy() async {
    var lines = <String>[];
    for (
      var offset = 0;
      offset < _bytes.length;
      offset += fileSystemHexBytesPerRow
    ) {
      var end = (offset + fileSystemHexBytesPerRow).clamp(0, _bytes.length);
      var row = _bytes.sublist(offset, end);
      lines.add(
        '${fileSystemHexOffset(offset)}  ${fileSystemHexBytes(row)}  '
        '|${fileSystemHexText(row)}|',
      );
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    _snack('Copied the dump');
  }

  int get _rowCount =>
      (_bytes.length + fileSystemHexBytesPerRow - 1) ~/
      fileSystemHexBytesPerRow;

  @override
  Widget build(BuildContext context) {
    var monospace = const TextStyle(
      fontFamily: festenaoMonospaceFontFamily,
      fontSize: 13,
    );
    return ExplorerScaffold(
      title: widget.path,
      isReadOnly: isReadOnly,
      stateChip: _isDirty
          ? const ExplorerChip(
              label: 'unsaved',
              icon: Icons.edit_outlined,
              tone: ExplorerChipTone.accent,
            )
          : const ExplorerChip(label: 'saved', icon: Icons.check),
      statusBar: ExplorerStatusBar(
        message:
            '${_bytes.length} bytes · '
            '$_rowCount rows of $fileSystemHexBytesPerRow',
        trailing: [
          ExplorerChip(
            label: '0x${_bytes.length.toRadixString(16)}',
            monospace: true,
          ),
          ExplorerChip(label: _text == null ? 'binary' : 'utf8'),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.copy_all_outlined),
          tooltip: 'Copy the dump',
          onPressed: _copy,
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Reload',
          onPressed: () => setState(() {
            _loading = _load();
          }),
        ),
      ],
      body: FutureBuilder<Uint8List>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var text = _text;
          return ListView.builder(
            itemCount: _rowCount + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildHeader(text, monospace);
              }
              var offset = (index - 1) * fileSystemHexBytesPerRow;
              var end = (offset + fileSystemHexBytesPerRow).clamp(
                0,
                _bytes.length,
              );
              var row = _bytes.sublist(offset, end);
              return InkWell(
                onTap: isReadOnly ? null : () => _editRow(offset),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Text(
                    '${fileSystemHexOffset(offset)}  '
                    '${fileSystemHexBytes(row)}  '
                    '|${fileSystemHexText(row)}|',
                    style: monospace,
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: isReadOnly
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'append',
                  tooltip: 'Append bytes',
                  onPressed: _append,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'save',
                  tooltip: _isDirty ? 'Save' : 'Nothing to save',
                  onPressed: _isDirty ? _save : null,
                  backgroundColor: _isDirty
                      ? null
                      : Theme.of(context).disabledColor,
                  child: const Icon(Icons.save),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(String? text, TextStyle monospace) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          '${_bytes.length} '
          '${_bytes.length == 1 ? 'byte' : 'bytes'}'
          '${_isDirty ? ' (unsaved)' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      if (text != null) ...[
        ListTile(
          dense: true,
          leading: Icon(_showText ? Icons.expand_more : Icons.chevron_right),
          title: const Text('Text preview (utf8)'),
          onTap: () => setState(() {
            _showText = !_showText;
          }),
        ),
        if (_showText)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).highlightColor,
            child: Text(text, style: monospace),
          ),
      ],
      const Divider(),
    ],
  );
}

/// Pushes a [FileSystemHexFileScreen] on the file [path] of [explorer].
Future<void> goToFileSystemHexFileScreen(
  BuildContext context, {
  required FileSystemExplorer explorer,
  required String path,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => FileSystemHexFileScreen(explorer: explorer, path: path),
  ),
);
