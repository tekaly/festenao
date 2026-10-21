import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'explorer_find.dart';
import 'explorer_text_style.dart';

/// A read only text, in the monospace font, a line per row (no wrapping, it
/// scrolls sideways), selectable, its [find] matches highlighted and the
/// current one scrolled into view.
///
/// Built line by line, so a long text (a big protobuf dump) costs only what
/// shows.
class ExplorerTextView extends StatefulWidget {
  /// The text.
  final String text;

  /// The find bar whose matches are highlighted, none when null.
  final ExplorerFindController? find;

  /// Text view of [text].
  const ExplorerTextView({super.key, required this.text, this.find});

  @override
  State<ExplorerTextView> createState() => _ExplorerTextViewState();
}

class _ExplorerTextViewState extends State<ExplorerTextView> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  late List<int> _lineStarts;
  var _maxLineLength = 0;
  var _charWidth = 8.0;
  var _lineExtent = 18.0;
  var _revealCount = 0;

  @override
  void initState() {
    super.initState();
    _splitLines();
    widget.find?.addListener(_onFind);
  }

  @override
  void didUpdateWidget(ExplorerTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _splitLines();
    }
    if (oldWidget.find != widget.find) {
      oldWidget.find?.removeListener(_onFind);
      widget.find?.addListener(_onFind);
    }
  }

  @override
  void dispose() {
    widget.find?.removeListener(_onFind);
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  void _splitLines() {
    var text = widget.text;
    _lineStarts = [0];
    _maxLineLength = 0;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x0a) {
        _maxLineLength = max(_maxLineLength, i - _lineStarts.last);
        _lineStarts.add(i + 1);
      }
    }
    _maxLineLength = max(_maxLineLength, text.length - _lineStarts.last);
  }

  /// The line holding the code unit [offset].
  int _lineOf(int offset) {
    var low = 0;
    var high = _lineStarts.length - 1;
    while (low < high) {
      var middle = (low + high + 1) >> 1;
      if (_lineStarts[middle] <= offset) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low;
  }

  void _onFind() {
    var find = widget.find!;
    var match = find.currentMatch;
    setState(() {});
    if (match == null || find.revealCount == _revealCount) {
      return;
    }
    _revealCount = find.revealCount;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(match));
  }

  /// Scrolls [match] into view, a third down the screen.
  void _reveal(TextRange match) {
    if (!mounted) {
      return;
    }
    var line = _lineOf(match.start);
    if (_vertical.hasClients) {
      var position = _vertical.position;
      var top = line * _lineExtent;
      if (top < position.pixels ||
          top + _lineExtent > position.pixels + position.viewportDimension) {
        position.jumpTo(
          (top - position.viewportDimension / 3).clamp(
            0.0,
            position.maxScrollExtent,
          ),
        );
      }
    }
    if (_horizontal.hasClients) {
      var position = _horizontal.position;
      var left = (match.start - _lineStarts[line]) * _charWidth;
      var right = (match.end - _lineStarts[line]) * _charWidth + 24;
      if (left < position.pixels ||
          right > position.pixels + position.viewportDimension) {
        position.jumpTo(
          (left - position.viewportDimension / 3).clamp(
            0.0,
            position.maxScrollExtent,
          ),
        );
      }
    }
  }

  void _measure(BuildContext context) {
    var painter = TextPainter(
      text: const TextSpan(
        text: '0123456789',
        style: explorerMonospaceTextStyle,
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    _charWidth = painter.width / 10;
    _lineExtent = painter.height + 2;
    painter.dispose();
  }

  TextSpan _lineSpan(int line, ({TextStyle match, TextStyle current}) styles) {
    var text = widget.text;
    var start = _lineStarts[line];
    var end = line + 1 < _lineStarts.length
        ? _lineStarts[line + 1] - 1
        : text.length;
    var find = widget.find;
    var matches = find?.matches ?? const <TextRange>[];
    if (matches.isEmpty) {
      return TextSpan(text: text.substring(start, end));
    }
    var children = <TextSpan>[];
    var position = start;
    for (
      var index = explorerFirstRangeEndingAfter(matches, start);
      index < matches.length && matches[index].start < end;
      index++
    ) {
      var match = matches[index];
      var from = max(match.start, start);
      var to = min(match.end, end);
      if (from > position) {
        children.add(TextSpan(text: text.substring(position, from)));
      }
      children.add(
        TextSpan(
          text: text.substring(from, to),
          style: index == find!.current ? styles.current : styles.match,
        ),
      );
      position = to;
    }
    if (position < end) {
      children.add(TextSpan(text: text.substring(position, end)));
    }
    return TextSpan(children: children);
  }

  @override
  Widget build(BuildContext context) {
    _measure(context);
    var styles = explorerFindStyles(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = max(constraints.maxWidth, _maxLineLength * _charWidth + 32);
        return Scrollbar(
          controller: _horizontal,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: SelectionArea(
                child: ListView.builder(
                  controller: _vertical,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemExtent: _lineExtent,
                  itemCount: _lineStarts.length,
                  itemBuilder: (context, line) => Text.rich(
                    _lineSpan(line, styles),
                    style: explorerMonospaceTextStyle,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
