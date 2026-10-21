import 'dart:math';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_app_text/diacritic.dart';

import '../file_system_hex_editor.dart' show fileSystemHexParse;

/// How the find bar matches what is typed.
enum ExplorerFindMode {
  /// The quick one: the query trimmed, case and accents ignored on both
  /// sides (`removeDiacritics` then lower case).
  any('Any', 'Ignore case and accents'),

  /// The query as typed, case and accents included.
  exact('Exact', 'Case and accents as typed'),

  /// Bytes typed in hex, spaces optional (binary content only).
  hex('Hex', 'Bytes in hex');

  /// What the mode chip says.
  final String label;

  /// What the mode chip explains.
  final String tooltip;

  const ExplorerFindMode(this.label, this.tooltip);
}

/// The most matches a find lists, the counter saying `+` beyond.
const explorerFindMaxMatches = 10000;

/// [query] as the any mode looks for it: trimmed, without diacritics, lower
/// case.
String explorerAnyQuery(String query) =>
    query.trim().removeDiacritics().toLowerCase();

/// A text normalized for the any mode — without diacritics, lower case —
/// remembering where each of its code units comes from in the source.
///
/// Removing diacritics changes the length (a combining accent goes, `Æ`
/// becomes `AE`), so a match in the normalized text is mapped back to the
/// source range it covers.
class ExplorerAnyText {
  /// The text normalized.
  final String normalized;

  /// For each code unit of [normalized], the index in the source of the code
  /// unit it comes from.
  final List<int> _sourceIndexes;

  /// The length of the source.
  final int _sourceLength;

  ExplorerAnyText._(this.normalized, this._sourceIndexes, this._sourceLength);

  /// [source] normalized.
  factory ExplorerAnyText(String source) {
    var units = <int>[];
    var indexes = <int>[];
    var cache = <int, String>{};
    for (var i = 0; i < source.length; i++) {
      var unit = source.codeUnitAt(i);
      if (unit < 0x80) {
        // Ascii: lower case only, the common case kept fast.
        units.add(unit >= 0x41 && unit <= 0x5a ? unit + 0x20 : unit);
        indexes.add(i);
        continue;
      }
      var piece = cache[unit] ??= String.fromCharCode(unit)
          .removeDiacritics()
          .toLowerCase();
      for (var j = 0; j < piece.length; j++) {
        units.add(piece.codeUnitAt(j));
        indexes.add(i);
      }
    }
    return ExplorerAnyText._(
      String.fromCharCodes(units),
      indexes,
      source.length,
    );
  }

  /// The source range the normalized range [start] to [end] covers: up to
  /// the next normalized character, so that a combining accent that went
  /// away is part of the match, and at least the whole last source
  /// character (a match on the `a` of `Æ` covers it).
  TextRange sourceRange(int start, int end) {
    var next = end < _sourceIndexes.length
        ? _sourceIndexes[end]
        : _sourceLength;
    return TextRange(
      start: _sourceIndexes[start],
      end: max(next, _sourceIndexes[end - 1] + 1),
    );
  }
}

/// The non overlapping ranges of [query] in [text], at most [max].
List<TextRange> _indexesOf(String text, String query, int max) {
  var ranges = <TextRange>[];
  if (query.isEmpty) {
    return ranges;
  }
  var start = 0;
  while (ranges.length < max) {
    var index = text.indexOf(query, start);
    if (index < 0) {
      break;
    }
    ranges.add(TextRange(start: index, end: index + query.length));
    start = index + query.length;
  }
  return ranges;
}

/// Finds in a text, keeping what the any mode needs between two finds.
class ExplorerTextFinder {
  /// The text searched.
  final String text;

  ExplorerAnyText? _any;

  /// Finder in [text].
  ExplorerTextFinder(this.text);

  /// The ranges of [text] matching [query] in [mode] (hex finds nothing in a
  /// text), at most [max].
  List<TextRange> find(
    String query,
    ExplorerFindMode mode, {
    int max = explorerFindMaxMatches,
  }) {
    switch (mode) {
      case ExplorerFindMode.exact:
        return _indexesOf(text, query, max);
      case ExplorerFindMode.any:
        var normalizedQuery = explorerAnyQuery(query);
        if (normalizedQuery.isEmpty) {
          return const [];
        }
        var any = _any ??= ExplorerAnyText(text);
        return [
          for (var range in _indexesOf(any.normalized, normalizedQuery, max))
            any.sourceRange(range.start, range.end),
        ];
      case ExplorerFindMode.hex:
        return const [];
    }
  }
}

/// [bytes] as text for a find: each valid utf8 sequence as its character,
/// any other byte as its latin1 one; with, for each code unit and one past
/// the end, the offset of the byte it starts at.
({String text, List<int> byteOffsets}) explorerBytesAsText(List<int> bytes) {
  var units = <int>[];
  var offsets = <int>[];
  var length = bytes.length;
  var i = 0;
  bool isContinuation(int index) =>
      index < length && bytes[index] & 0xc0 == 0x80;
  while (i < length) {
    var byte = bytes[i];
    var codePoint = -1;
    var size = 1;
    if (byte >= 0xc2 && byte <= 0xdf && isContinuation(i + 1)) {
      codePoint = ((byte & 0x1f) << 6) | (bytes[i + 1] & 0x3f);
      size = 2;
    } else if (byte >= 0xe0 &&
        byte <= 0xef &&
        isContinuation(i + 1) &&
        isContinuation(i + 2)) {
      var value =
          ((byte & 0x0f) << 12) |
          ((bytes[i + 1] & 0x3f) << 6) |
          (bytes[i + 2] & 0x3f);
      // Neither over long nor a surrogate.
      if (value >= 0x800 && (value < 0xd800 || value > 0xdfff)) {
        codePoint = value;
        size = 3;
      }
    } else if (byte >= 0xf0 &&
        byte <= 0xf4 &&
        isContinuation(i + 1) &&
        isContinuation(i + 2) &&
        isContinuation(i + 3)) {
      var value =
          ((byte & 0x07) << 18) |
          ((bytes[i + 1] & 0x3f) << 12) |
          ((bytes[i + 2] & 0x3f) << 6) |
          (bytes[i + 3] & 0x3f);
      if (value >= 0x10000 && value <= 0x10ffff) {
        codePoint = value;
        size = 4;
      }
    }
    if (codePoint < 0) {
      // Ascii, or a byte that is not utf8: its latin1 character.
      units.add(byte);
      offsets.add(i);
    } else if (codePoint >= 0x10000) {
      var value = codePoint - 0x10000;
      units
        ..add(0xd800 + (value >> 10))
        ..add(0xdc00 + (value & 0x3ff));
      offsets
        ..add(i)
        ..add(i);
    } else {
      units.add(codePoint);
      offsets.add(i);
    }
    i += size;
  }
  offsets.add(length);
  return (text: String.fromCharCodes(units), byteOffsets: offsets);
}

/// Finds in bytes, as text (utf8, latin1 otherwise) or as hex, keeping what
/// the text modes need between two finds.
class ExplorerBytesFinder {
  /// The bytes searched.
  final List<int> bytes;

  ({String text, List<int> byteOffsets})? _decoded;
  ExplorerTextFinder? _textFinder;

  /// Finder in [bytes].
  ExplorerBytesFinder(this.bytes);

  /// The byte ranges matching [query] in [mode], at most [max]; nothing when
  /// a hex query is not hex.
  List<TextRange> find(
    String query,
    ExplorerFindMode mode, {
    int max = explorerFindMaxMatches,
  }) {
    if (mode == ExplorerFindMode.hex) {
      var pattern = fileSystemHexParse(query);
      if (pattern == null || pattern.isEmpty) {
        return const [];
      }
      return _findBytes(pattern, max);
    }
    var decoded = _decoded ??= explorerBytesAsText(bytes);
    var finder = _textFinder ??= ExplorerTextFinder(decoded.text);
    var offsets = decoded.byteOffsets;
    return [
      for (var range in finder.find(query, mode, max: max))
        TextRange(start: offsets[range.start], end: offsets[range.end]),
    ];
  }

  List<TextRange> _findBytes(List<int> pattern, int max) {
    var ranges = <TextRange>[];
    var last = bytes.length - pattern.length;
    var first = pattern.first;
    var start = 0;
    while (start <= last && ranges.length < max) {
      if (bytes[start] == first) {
        var matches = true;
        for (var j = 1; j < pattern.length; j++) {
          if (bytes[start + j] != pattern[j]) {
            matches = false;
            break;
          }
        }
        if (matches) {
          ranges.add(TextRange(start: start, end: start + pattern.length));
          start += pattern.length;
          continue;
        }
      }
      start++;
    }
    return ranges;
  }
}

/// The index of the first of the sorted [ranges] ending after [offset],
/// `ranges.length` when none does.
int explorerFirstRangeEndingAfter(List<TextRange> ranges, int offset) {
  var low = 0;
  var high = ranges.length;
  while (low < high) {
    var middle = (low + high) >> 1;
    if (ranges[middle].end <= offset) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low;
}

/// The state of a find bar: open or not, the query, the mode, the matches
/// and the current one.
///
/// A screen gives it [search], listens to it to highlight [matches] and
/// reveal [currentMatch], and calls [refresh] when its content changes.
class ExplorerFindController extends ChangeNotifier {
  /// Finds the query in the content, the ranges sorted.
  final List<TextRange> Function(String query, ExplorerFindMode mode) search;

  /// The field of the query.
  final textController = TextEditingController();

  /// The focus of [textController]'s field.
  final focusNode = FocusNode(debugLabel: 'find');

  var _isOpen = false;
  var _mode = ExplorerFindMode.any;
  List<TextRange> _matches = const [];
  var _current = -1;
  var _revealCount = 0;

  /// Find controller over [search].
  ExplorerFindController({required this.search});

  /// True when the bar shows.
  bool get isOpen => _isOpen;

  /// What is looked for.
  String get query => textController.text;

  /// How it is looked for.
  ExplorerFindMode get mode => _mode;

  /// The matches, sorted, empty when closed.
  List<TextRange> get matches => _matches;

  /// The index of the current match in [matches], -1 when none.
  int get current => _current;

  /// The current match, null when none.
  TextRange? get currentMatch =>
      _current >= 0 && _current < _matches.length ? _matches[_current] : null;

  /// Counts the moves the user asked for (typing, next, previous, mode): a
  /// screen scrolls [currentMatch] into view when it changes, and not when
  /// the matches are only found again after an edit ([refresh]).
  int get revealCount => _revealCount;

  /// True when the matches stopped at [explorerFindMaxMatches].
  bool get isTruncated => _matches.length >= explorerFindMaxMatches;

  /// Opens the bar (again), its query selected for typing over.
  void open() {
    if (!_isOpen) {
      _isOpen = true;
      _refresh(0, reveal: true);
    }
    textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: textController.text.length,
    );
    focusNode.requestFocus();
    notifyListeners();
  }

  /// Closes the bar, dropping the matches (the query stays for next time).
  void close() {
    if (!_isOpen) {
      return;
    }
    _isOpen = false;
    _matches = const [];
    _current = -1;
    notifyListeners();
  }

  /// Opens or closes the bar.
  void toggle() => _isOpen ? close() : open();

  /// The query changed: finds again from the current match.
  void queryChanged() => _refresh(currentMatch?.start ?? 0, reveal: true);

  /// Looks for the query in [mode] instead.
  void setMode(ExplorerFindMode mode) {
    if (mode != _mode) {
      _mode = mode;
      _refresh(currentMatch?.start ?? 0, reveal: true);
    }
  }

  /// The content changed: finds again, keeping near the current match,
  /// without moving the view.
  void refresh() {
    if (_isOpen) {
      _refresh(currentMatch?.start ?? 0, reveal: false);
    }
  }

  void _refresh(int from, {required bool reveal}) {
    if (reveal) {
      _revealCount++;
    }
    _matches = _isOpen && query.isNotEmpty ? search(query, _mode) : const [];
    if (_matches.isEmpty) {
      _current = -1;
    } else {
      var index = _matches.indexWhere((match) => match.start >= from);
      _current = index < 0 ? 0 : index;
    }
    notifyListeners();
  }

  /// Goes to the next match, back to the first after the last.
  void next() {
    if (_matches.isEmpty) {
      return;
    }
    _current = (_current + 1) % _matches.length;
    _revealCount++;
    notifyListeners();
  }

  /// Goes to the previous match, to the last before the first.
  void previous() {
    if (_matches.isEmpty) {
      return;
    }
    _current = (_current - 1 + _matches.length) % _matches.length;
    _revealCount++;
    notifyListeners();
  }

  /// What the counter says: `3 / 12`, `No match`, nothing before typing.
  String get counter {
    if (query.isEmpty) {
      return '';
    }
    if (_matches.isEmpty) {
      return _mode == ExplorerFindMode.hex && fileSystemHexParse(query) == null
          ? 'Not hex'
          : 'No match';
    }
    return '${_current + 1} / ${_matches.length}${isTruncated ? '+' : ''}';
  }

  @override
  void dispose() {
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }
}

/// The styles of the matches: every one, and the current one.
({TextStyle match, TextStyle current}) explorerFindStyles(
  BuildContext context,
) {
  var colors = Theme.of(context).colorScheme;
  return (
    match: TextStyle(
      backgroundColor: colors.tertiaryContainer,
      color: colors.onTertiaryContainer,
    ),
    current: TextStyle(
      backgroundColor: colors.tertiary,
      color: colors.onTertiary,
    ),
  );
}

/// The shortcuts of a screen with a find bar: ctrl+F opens it, F3 and
/// shift+F3 go to the next and previous match.
Map<ShortcutActivator, VoidCallback> explorerFindShortcuts(
  ExplorerFindController controller,
) => {
  const SingleActivator(LogicalKeyboardKey.keyF, control: true):
      controller.open,
  const SingleActivator(LogicalKeyboardKey.keyF, meta: true): controller.open,
  const SingleActivator(LogicalKeyboardKey.f3): () {
    controller.isOpen ? controller.next() : controller.open();
  },
  const SingleActivator(LogicalKeyboardKey.f3, shift: true):
      controller.previous,
};

/// The find bar: the query, the modes, the counter, previous, next, close.
///
/// Enter goes to the next match, shift+enter to the previous one, escape
/// closes. It shows only while [controller] is open.
class ExplorerFindBar extends StatelessWidget {
  /// Its state.
  final ExplorerFindController controller;

  /// The modes offered, [ExplorerFindMode.hex] for binary content only.
  final List<ExplorerFindMode> modes;

  /// Find bar of [controller].
  const ExplorerFindBar({
    super.key,
    required this.controller,
    this.modes = const [ExplorerFindMode.any, ExplorerFindMode.exact],
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.isOpen) {
        return const SizedBox.shrink();
      }
      var theme = Theme.of(context);
      var field = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, shift: true):
              controller.previous,
          const SingleActivator(LogicalKeyboardKey.escape): controller.close,
        },
        child: TextField(
          key: const ValueKey('explorerFind'),
          controller: controller.textController,
          focusNode: controller.focusNode,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, size: 20),
            prefixIconConstraints: const BoxConstraints(minWidth: 32),
            hintText: controller.mode == ExplorerFindMode.hex
                ? 'Find bytes (hex)'
                : 'Find',
          ),
          onChanged: (_) => controller.queryChanged(),
          onSubmitted: (_) {
            controller.next();
            controller.focusNode.requestFocus();
          },
          // Keeps the focus in the field, enter after enter.
          onEditingComplete: () {},
        ),
      );
      var modeChips = Wrap(
        spacing: 4,
        children: [
          for (var mode in modes)
            Tooltip(
              message: mode.tooltip,
              child: ChoiceChip(
                label: Text(mode.label),
                selected: controller.mode == mode,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) => controller.setMode(mode),
              ),
            ),
        ],
      );
      var navigation = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(controller.counter, style: theme.textTheme.bodySmall),
          IconButton(
            tooltip: 'Previous (shift+enter)',
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: controller.matches.isEmpty ? null : controller.previous,
          ),
          IconButton(
            tooltip: 'Next (enter)',
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: controller.matches.isEmpty ? null : controller.next,
          ),
          IconButton(
            tooltip: 'Close (escape)',
            icon: const Icon(Icons.close),
            onPressed: controller.close,
          ),
        ],
      );
      return Material(
        color: theme.colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 600
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(child: field),
                          navigation,
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: modeChips,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: field),
                      modeChips,
                      const SizedBox(width: 8),
                      navigation,
                    ],
                  ),
          ),
        ),
      );
    },
  );
}
