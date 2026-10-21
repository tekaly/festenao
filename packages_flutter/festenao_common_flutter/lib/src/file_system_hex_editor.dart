import 'dart:convert';
import 'dart:math';

import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'explorer_ui/explorer_chip.dart';
import 'explorer_ui/explorer_find.dart';
import 'explorer_ui/explorer_scaffold.dart';
import 'explorer_ui/explorer_text_style.dart';
import 'object_editor/object_editor_dialogs.dart';

/// How many bytes a row of the copied dump holds.
const fileSystemHexBytesPerRow = 16;

/// The row widths [FileSystemHexLayout.auto] picks from.
const fileSystemHexBytesPerRowChoices = [4, 8, 16, 24, 32, 48, 64];

/// The offset of a row, as a hex dump prints it: 8 hex digits.
String fileSystemHexOffset(int offset) =>
    offset.toRadixString(16).padLeft(8, '0');

/// [bytes] as the hex pair of each one, space separated, padded to
/// [bytesPerRow] so the columns line up on the last row.
String fileSystemHexBytes(
  List<int> bytes, {
  int bytesPerRow = fileSystemHexBytesPerRow,
}) {
  var pairs = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .toList();
  while (pairs.length < bytesPerRow) {
    pairs.add('  ');
  }
  return pairs.join(' ');
}

/// [byte] as the text column of a hex dump shows it: a printable ascii one
/// as itself, anything else as a dot.
String fileSystemHexChar(int byte) =>
    byte >= 0x20 && byte < 0x7f ? String.fromCharCode(byte) : '.';

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

/// Which column of the dump a position is in.
enum FileSystemHexColumn {
  /// The bytes in hex.
  hex,

  /// The bytes as text.
  text,
}

/// What a character position of a row points at: the byte of the row, its
/// column and, in hex, which of its two digits.
typedef FileSystemHexHit = ({
  int index,
  FileSystemHexColumn column,
  int nibble,
});

/// Where everything sits in a row of the dump, in characters of the
/// monospace font: the offset, two spaces, the hex pairs (one more space
/// every 8 bytes), two spaces, the text column between bars, like
/// `hexdump -C`.
class FileSystemHexLayout {
  /// The bytes of a row.
  final int bytesPerRow;

  /// The characters of the offset column.
  static const offsetChars = 8;

  /// Layout of [bytesPerRow] bytes a row.
  const FileSystemHexLayout(this.bytesPerRow);

  /// The widest layout of [fileSystemHexBytesPerRowChoices] fitting in
  /// [chars] characters, the narrowest one when none does.
  factory FileSystemHexLayout.auto(int chars) {
    var best = fileSystemHexBytesPerRowChoices.first;
    for (var choice in fileSystemHexBytesPerRowChoices) {
      if (FileSystemHexLayout(choice).rowChars <= chars) {
        best = choice;
      }
    }
    return FileSystemHexLayout(best);
  }

  /// Where the hex pair of the byte [index] of the row starts.
  int hexStart(int index) => offsetChars + 2 + index * 3 + index ~/ 8;

  /// The characters of the hex column.
  int get hexChars => bytesPerRow * 3 - 1 + (bytesPerRow - 1) ~/ 8;

  /// Where the text column starts, after its opening bar.
  int get textStart => offsetChars + 2 + hexChars + 3;

  /// The characters of a whole row, closing bar included.
  int get rowChars => textStart + bytesPerRow + 1;

  /// What the character [position] of a row points at, null for the offset
  /// and the gaps around the columns.
  FileSystemHexHit? hitTest(int position) {
    if (position >= textStart && position < textStart + bytesPerRow) {
      return (
        index: position - textStart,
        column: FileSystemHexColumn.text,
        nibble: 0,
      );
    }
    var hexStart = this.hexStart(0);
    if (position < hexStart || position >= hexStart + hexChars) {
      return null;
    }
    // The space after a pair goes with it.
    for (var index = bytesPerRow - 1; index >= 0; index--) {
      var start = this.hexStart(index);
      if (position >= start) {
        return (
          index: index,
          column: FileSystemHexColumn.hex,
          nibble: min(position - start, 1),
        );
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is FileSystemHexLayout && other.bytesPerRow == bytesPerRow;

  @override
  int get hashCode => bytesPerRow;
}

/// Above this size the utf8 preview is not even tried.
const _textPreviewMaxSize = 256 * 1024;

const _monospace = explorerMonospaceTextStyle;

/// A screen showing, and editing when the explorer allows it, a file as hex.
///
/// The classic dump — offset, the bytes of the row in hex, the same bytes as
/// text, side by side — with as many bytes a row as the width holds (or as
/// picked), plus, above it, the whole content decoded as text when it is
/// valid utf8, which is what tells a mislabelled text file from a real binary
/// one at a glance.
///
/// Tapping a byte, in either column, selects it in both. Then typing edits
/// it: hex digits in the hex column, characters in the text column, the
/// arrows move, delete and backspace remove, insert adds a zero byte, ctrl+S
/// saves. Ctrl+F finds text (any: case and accents ignored, or exact; utf8,
/// latin1 otherwise) or hex bytes, the matches highlighted in both columns. Without a keyboard, the bar of the selection writes, inserts,
/// deletes and retypes the whole row, as a long press on a row does.
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

  /// The bytes a row, null to fit the width.
  int? _bytesPerRow;

  /// The selected byte, from 0 to the length (the end, where typing
  /// appends), null when none is.
  int? _selection;
  var _column = FileSystemHexColumn.hex;

  /// The hex digit typed next in the selected byte: 0 the high one.
  var _nibble = 0;

  final _focusNode = FocusNode(debugLabel: 'hex');
  final _scrollController = ScrollController();

  /// The layout of the last build, for the keys and the scrolling.
  var _layout = const FileSystemHexLayout(fileSystemHexBytesPerRow);
  var _rowExtent = 20.0;

  String? _textCache;
  var _textCacheValid = false;

  late final _find = ExplorerFindController(search: _search)
    ..addListener(_onFind);
  ExplorerBytesFinder? _finder;
  var _revealCount = 0;

  Future<Uint8List> _load() async {
    var bytes = await explorer.readAsBytes(widget.path);
    _bytes = bytes.toList();
    _isDirty = false;
    _textCacheValid = false;
    _finder = null;
    _find.refresh();
    if (_selection != null) {
      _selection = min(_selection!, _bytes.length);
    }
    // The status bar depends on what was read too.
    if (mounted) {
      setState(() {});
    }
    return bytes;
  }

  @override
  void dispose() {
    _find.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<TextRange> _search(String query, ExplorerFindMode mode) =>
      (_finder ??= ExplorerBytesFinder(_bytes)).find(query, mode);

  /// Highlights the matches; selects the current one when the user moved to
  /// it, in the column it was found in.
  void _onFind() {
    if (!mounted) {
      return;
    }
    var match = _find.currentMatch;
    if (match != null && _find.revealCount != _revealCount) {
      _revealCount = _find.revealCount;
      _selection = min(match.start, _bytes.length);
      _column = _find.mode == ExplorerFindMode.hex
          ? FileSystemHexColumn.hex
          : FileSystemHexColumn.text;
      _nibble = 0;
      _ensureVisible();
    }
    setState(() {});
  }

  /// The whole content as text, null when it is not valid utf8 (or too big
  /// to try) — which is what makes the preview worth showing or not.
  String? get _text {
    if (!_textCacheValid) {
      _textCacheValid = true;
      _textCache = null;
      if (_bytes.length <= _textPreviewMaxSize) {
        try {
          _textCache = const Utf8Decoder().convert(_bytes);
        } catch (_) {
          _textCache = null;
        }
      }
    }
    return _textCache;
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _changed() {
    _isDirty = true;
    _textCacheValid = false;
    // Found again in the new bytes, the view staying where it is.
    _finder = null;
    _find.refresh();
  }

  Future<void> _save() async {
    if (isReadOnly || !_isDirty) {
      return;
    }
    try {
      await explorer.writeAsBytes(widget.path, _bytes);
      setState(() => _isDirty = false);
      _snack('Saved ${widget.path}');
    } catch (e) {
      _snack('$e');
    }
  }

  int get _bytesPerRowShown => _layout.bytesPerRow;

  /// The rows, one more when the end is selected on a full last row.
  int get _rowCount {
    var row = _bytesPerRowShown;
    var length = _bytes.length + (_selection == _bytes.length ? 1 : 0);
    return max(1, (length + row - 1) ~/ row);
  }

  /// Retypes the bytes of the row starting at [offset].
  Future<void> _editRow(int offset) async {
    var end = (offset + _bytesPerRowShown).clamp(0, _bytes.length);
    var row = _bytes.sublist(offset, end);
    var text = await objectEditorPromptText(
      context,
      title: fileSystemHexOffset(offset),
      initialValue: fileSystemHexBytes(row, bytesPerRow: 0),
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
    if (parsed.length > _bytesPerRowShown) {
      _snack('At most $_bytesPerRowShown bytes in a row');
      return;
    }
    setState(() {
      _bytes.replaceRange(offset, end, parsed);
      _changed();
    });
  }

  /// Asks for bytes, in hex or as text, null when cancelled.
  Future<List<int>?> _promptBytes(String title) async {
    var result = await showDialog<List<int>>(
      context: context,
      builder: (context) => _HexBytesDialog(title: title),
    );
    return result;
  }

  Future<void> _append() async {
    var bytes = await _promptBytes('Append');
    if (bytes == null || bytes.isEmpty) {
      return;
    }
    setState(() {
      _bytes.addAll(bytes);
      _changed();
    });
  }

  /// Overwrites the bytes from the selection with typed ones, the file
  /// growing when they go past its end.
  Future<void> _overwriteAtSelection() async {
    var index = _selection;
    if (index == null) {
      return;
    }
    var bytes = await _promptBytes('Write at ${fileSystemHexOffset(index)}');
    if (bytes == null || bytes.isEmpty) {
      return;
    }
    setState(() {
      var end = min(index + bytes.length, _bytes.length);
      _bytes.replaceRange(index, end, bytes);
      _selection = min(index + bytes.length, _bytes.length);
      _changed();
    });
  }

  Future<void> _insertAtSelection() async {
    var index = _selection;
    if (index == null) {
      return;
    }
    var bytes = await _promptBytes('Insert at ${fileSystemHexOffset(index)}');
    if (bytes == null || bytes.isEmpty) {
      return;
    }
    setState(() {
      _bytes.insertAll(index, bytes);
      _selection = index + bytes.length;
      _changed();
    });
  }

  void _deleteAt(int index) {
    if (isReadOnly || index < 0 || index >= _bytes.length) {
      return;
    }
    setState(() {
      _bytes.removeAt(index);
      _selection = min(index, _bytes.length);
      _nibble = 0;
      _changed();
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

  void _select(int index, {FileSystemHexColumn? column, int nibble = 0}) {
    setState(() {
      _selection = index.clamp(0, _bytes.length);
      if (column != null) {
        _column = column;
      }
      _nibble = nibble;
    });
    _ensureVisible();
  }

  /// Scrolls so that the selected row shows.
  void _ensureVisible() {
    var index = _selection;
    if (index == null || !_scrollController.hasClients) {
      return;
    }
    var position = _scrollController.position;
    var top = (index ~/ _bytesPerRowShown) * _rowExtent;
    if (top < position.pixels) {
      position.jumpTo(top);
    } else if (top + _rowExtent >
        position.pixels + position.viewportDimension) {
      position.jumpTo(
        min(
          position.maxScrollExtent,
          top + _rowExtent - position.viewportDimension,
        ),
      );
    }
  }

  /// Types the hex digit [digit] in the selected byte.
  void _typeHexDigit(int digit) {
    var index = _selection!;
    setState(() {
      if (index == _bytes.length) {
        _bytes.add(0);
        _nibble = 0;
      }
      var byte = _bytes[index];
      if (_nibble == 0) {
        _bytes[index] = (digit << 4) | (byte & 0x0f);
        _nibble = 1;
      } else {
        _bytes[index] = (byte & 0xf0) | digit;
        _nibble = 0;
        _selection = index + 1;
      }
      _changed();
    });
    _ensureVisible();
  }

  /// Types [text] in the text column: its bytes (latin1 when it fits, utf8
  /// otherwise) overwrite from the selection.
  void _typeText(String text) {
    var index = _selection!;
    var bytes = text.codeUnits.every((unit) => unit < 0x100)
        ? text.codeUnits
        : utf8.encode(text);
    setState(() {
      var end = min(index + bytes.length, _bytes.length);
      _bytes.replaceRange(index, end, bytes);
      _selection = index + bytes.length;
      _nibble = 0;
      _changed();
    });
    _ensureVisible();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    var keyboard = HardwareKeyboard.instance;
    var key = event.logicalKey;
    if ((keyboard.isControlPressed || keyboard.isMetaPressed) &&
        key == LogicalKeyboardKey.keyS) {
      _save();
      return KeyEventResult.handled;
    }
    var index = _selection;
    if (index == null) {
      return KeyEventResult.ignored;
    }
    var row = _bytesPerRowShown;
    int? move;
    if (key == LogicalKeyboardKey.arrowLeft) {
      move = index - 1;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      move = index + 1;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      move = index - row;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      move = index + row;
    } else if (key == LogicalKeyboardKey.home) {
      move = index - index % row;
    } else if (key == LogicalKeyboardKey.end) {
      move = min(index - index % row + row - 1, _bytes.length);
    } else if (key == LogicalKeyboardKey.pageUp) {
      move = index - row * 16;
    } else if (key == LogicalKeyboardKey.pageDown) {
      move = index + row * 16;
    }
    if (move != null) {
      _select(move.clamp(0, _bytes.length));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      setState(() {
        _column = _column == FileSystemHexColumn.hex
            ? FileSystemHexColumn.text
            : FileSystemHexColumn.hex;
        _nibble = 0;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      setState(() => _selection = null);
      return KeyEventResult.handled;
    }
    if (isReadOnly) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _deleteAt(index - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete) {
      _deleteAt(index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.insert) {
      setState(() {
        _bytes.insert(index, 0);
        _nibble = 0;
        _changed();
      });
      return KeyEventResult.handled;
    }
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    var character = event.character;
    if (character == null || character.isEmpty) {
      return KeyEventResult.ignored;
    }
    if (_column == FileSystemHexColumn.hex) {
      var digit = int.tryParse(character, radix: 16);
      if (digit == null || character.length != 1) {
        return KeyEventResult.ignored;
      }
      _typeHexDigit(digit);
      return KeyEventResult.handled;
    }
    if (character.codeUnitAt(0) < 0x20) {
      return KeyEventResult.ignored;
    }
    _typeText(character);
    return KeyEventResult.handled;
  }

  /// The width of a character of the monospace font.
  double _charWidth(BuildContext context) {
    var painter = TextPainter(
      text: const TextSpan(text: '0123456789', style: _monospace),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    var width = painter.width / 10;
    _rowExtent = painter.height + 4;
    painter.dispose();
    return width;
  }

  void _onTapRow(int rowOffset, double dx, double charWidth) {
    _focusNode.requestFocus();
    var hit = _layout.hitTest((dx - 8) ~/ charWidth);
    if (hit == null) {
      return;
    }
    var index = rowOffset + hit.index;
    if (index > _bytes.length) {
      // Past the end: the end, where typing appends.
      index = _bytes.length;
    }
    _select(index, column: hit.column, nibble: hit.nibble);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: explorerFindShortcuts(_find),
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
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
            '$_rowCount rows of $_bytesPerRowShown',
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
          icon: const Icon(Icons.search),
          tooltip: 'Find (Ctrl+F)',
          onPressed: _find.toggle,
        ),
        PopupMenuButton<int>(
          tooltip: 'Bytes per row',
          icon: const Icon(Icons.view_column_outlined),
          onSelected: (value) => setState(() {
            _bytesPerRow = value == 0 ? null : value;
          }),
          itemBuilder: (context) => [
            CheckedPopupMenuItem(
              value: 0,
              checked: _bytesPerRow == null,
              child: const Text('Fit the width'),
            ),
            for (var choice in fileSystemHexBytesPerRowChoices)
              CheckedPopupMenuItem(
                value: choice,
                checked: _bytesPerRow == choice,
                child: Text('$choice bytes per row'),
              ),
          ],
        ),
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
          return Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _onKeyEvent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExplorerFindBar(
                  controller: _find,
                  modes: ExplorerFindMode.values,
                ),
                _buildHeader(),
                // Above the dump, where the floating buttons never are.
                if (_selection != null) _buildSelectionBar(context),
                Expanded(child: _buildDump(context)),
              ],
            ),
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
                  tooltip: _isDirty ? 'Save (Ctrl+S)' : 'Nothing to save',
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

  Widget _buildDump(BuildContext context) {
    var charWidth = _charWidth(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        var chars = ((constraints.maxWidth - 16) / charWidth).floor();
        var layout = _bytesPerRow == null
            ? FileSystemHexLayout.auto(chars)
            : FileSystemHexLayout(_bytesPerRow!);
        if (layout != _layout) {
          _layout = layout;
          // The status bar, built before the width was known, says it too.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }
        var theme = Theme.of(context);
        var colors = theme.colorScheme;
        var offsetStyle = _monospace.copyWith(color: colors.outline);
        var textStyle = _monospace.copyWith(color: colors.secondary);
        var findStyles = explorerFindStyles(context);
        var matches = _find.matches;
        var currentMatch = _find.current;
        var selectedStyle = TextStyle(
          backgroundColor: colors.primary,
          color: colors.onPrimary,
        );
        var echoStyle = TextStyle(backgroundColor: colors.primaryContainer);
        var rowWidth = layout.rowChars * charWidth + 16;
        var list = ListView.builder(
          controller: _scrollController,
          itemExtent: _rowExtent,
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: _rowCount,
          itemBuilder: (context, rowIndex) {
            var offset = rowIndex * layout.bytesPerRow;
            var end = min(offset + layout.bytesPerRow, _bytes.length);
            var spans = <InlineSpan>[
              TextSpan(text: fileSystemHexOffset(offset), style: offsetStyle),
              const TextSpan(text: '  '),
            ];
            var selection = _selection;
            // The style of the find match holding the byte [index], null
            // for none; the indexes come in order.
            var matchIndex = explorerFirstRangeEndingAfter(matches, offset);
            TextStyle? matchStyleOf(int index) {
              while (matchIndex < matches.length &&
                  matches[matchIndex].end <= index) {
                matchIndex++;
              }
              if (matchIndex < matches.length &&
                  matches[matchIndex].start <= index) {
                return matchIndex == currentMatch
                    ? findStyles.current
                    : findStyles.match;
              }
              return null;
            }

            for (var i = 0; i < layout.bytesPerRow; i++) {
              var index = offset + i;
              var gap = i == layout.bytesPerRow - 1
                  ? ''
                  : (i % 8 == 7 ? '  ' : ' ');
              String pair;
              if (index < end) {
                pair = _bytes[index].toRadixString(16).padLeft(2, '0');
              } else if (index == _bytes.length && selection == index) {
                pair = '__';
              } else {
                pair = '  ';
              }
              spans.add(
                TextSpan(
                  text: pair,
                  style: selection == index
                      ? (_column == FileSystemHexColumn.hex
                            ? selectedStyle
                            : echoStyle)
                      : matchStyleOf(index),
                ),
              );
              spans.add(TextSpan(text: gap));
            }
            spans.add(TextSpan(text: '  |', style: offsetStyle));
            matchIndex = explorerFirstRangeEndingAfter(matches, offset);
            for (var i = 0; i < layout.bytesPerRow; i++) {
              var index = offset + i;
              String char;
              if (index < end) {
                char = fileSystemHexChar(_bytes[index]);
              } else if (index == _bytes.length && selection == index) {
                char = '_';
              } else {
                // The closing bar follows the last byte, like hexdump -C.
                break;
              }
              spans.add(
                TextSpan(
                  text: char,
                  style: selection == index
                      ? (_column == FileSystemHexColumn.text
                            ? selectedStyle
                            : echoStyle)
                      : (matchStyleOf(index) ?? textStyle),
                ),
              );
            }
            spans.add(TextSpan(text: '|', style: offsetStyle));
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _onTapRow(offset, details.localPosition.dx, charWidth),
              onLongPress: isReadOnly ? null : () => _editRow(offset),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text.rich(
                  TextSpan(style: _monospace, children: spans),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                ),
              ),
            );
          },
        );
        if (rowWidth <= constraints.maxWidth) {
          return list;
        }
        // A forced width wider than the screen scrolls sideways.
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: rowWidth, child: list),
          ),
        );
      },
    );
  }

  Widget _buildSelectionBar(BuildContext context) {
    var index = _selection!;
    var theme = Theme.of(context);
    var atEnd = index >= _bytes.length;
    var info = StringBuffer('@ 0x${index.toRadixString(16)} ($index)');
    if (!atEnd) {
      var byte = _bytes[index];
      info.write(
        ' · 0x${byte.toRadixString(16).padLeft(2, '0')} $byte '
        "'${fileSystemHexChar(byte)}'",
      );
      if (index + 2 <= _bytes.length) {
        info.write(' · u16 ${_bytes[index] | (_bytes[index + 1] << 8)}');
      }
      if (index + 4 <= _bytes.length) {
        var value =
            _bytes[index] |
            (_bytes[index + 1] << 8) |
            (_bytes[index + 2] << 16) |
            (_bytes[index + 3] * 0x1000000);
        info.write(' · u32 $value');
      }
    } else {
      info.write(' · end of file');
    }
    var text = Text(
      info.toString(),
      style: _monospace.copyWith(fontSize: 12),
      overflow: TextOverflow.ellipsis,
    );
    var buttons = [
      if (!isReadOnly) ...[
        IconButton(
          tooltip: 'Retype the row',
          icon: const Icon(Icons.edit_note, size: 20),
          onPressed: () => _editRow(index - index % _bytesPerRowShown),
        ),
        IconButton(
          tooltip: 'Write bytes here',
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: _overwriteAtSelection,
        ),
        IconButton(
          tooltip: 'Insert bytes here (Insert)',
          icon: const Icon(Icons.input, size: 20),
          onPressed: _insertAtSelection,
        ),
        IconButton(
          tooltip: 'Delete this byte (Delete)',
          icon: const Icon(Icons.backspace_outlined, size: 20),
          onPressed: atEnd ? null : () => _deleteAt(index),
        ),
      ],
      IconButton(
        tooltip: 'Unselect (Escape)',
        icon: const Icon(Icons.close, size: 20),
        onPressed: () => setState(() => _selection = null),
      ),
    ];
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: LayoutBuilder(
          // On a narrow screen, the buttons go below the values, which
          // would not show otherwise.
          builder: (context, constraints) => constraints.maxWidth < 560
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: text,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: buttons,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: text),
                    ...buttons,
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    var text = _text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Theme.of(context).highlightColor,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Text(text, style: _monospace),
                ),
              ),
            ),
        ],
        const Divider(height: 8),
      ],
    );
  }
}

/// Asks for bytes, typed in hex or as text (utf8).
class _HexBytesDialog extends StatefulWidget {
  final String title;

  const _HexBytesDialog({required this.title});

  @override
  State<_HexBytesDialog> createState() => _HexBytesDialogState();
}

class _HexBytesDialogState extends State<_HexBytesDialog> {
  final _controller = TextEditingController();
  var _asText = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_asText) {
      Navigator.of(context).pop(utf8.encode(_controller.text));
      return;
    }
    var bytes = fileSystemHexParse(_controller.text);
    if (bytes == null) {
      setState(() => _error = 'Not a run of hex bytes');
      return;
    }
    Navigator.of(context).pop(bytes);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Hex')),
              ButtonSegment(value: true, label: Text('Text')),
            ],
            selected: {_asText},
            onSelectionChanged: (selected) => setState(() {
              _asText = selected.single;
              _error = null;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            style: _monospace,
            decoration: InputDecoration(
              labelText: _asText ? 'Text (utf8)' : 'Bytes, in hex',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
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
