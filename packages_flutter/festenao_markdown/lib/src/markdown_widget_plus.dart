import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// A widget that displays markdown content using the [MarkdownWidget] package.
class FestenaoMarkdownWidget extends StatefulWidget {
  /// Whether to shrink the widget to fit its content.
  final bool? shrinkWrap;

  /// The markdown content to display.
  final String data;

  /// The text scaler to use for scaling the text.
  final TextScaler? textScaler;

  /// The constructor for [FestenaoMarkdownWidget].
  const FestenaoMarkdownWidget({
    super.key,
    this.textScaler,
    required this.data,
    this.shrinkWrap = true,
  });

  @override
  State<FestenaoMarkdownWidget> createState() => _FestenaoMarkdownWidgetState();
}

class _FestenaoMarkdownWidgetState extends State<FestenaoMarkdownWidget> {
  @override
  Widget build(BuildContext context) {
    var data = widget.data;
    return MarkdownBody(
      data: data,
      styleSheet: MarkdownStyleSheet.fromTheme(
        Theme.of(context),
      ).copyWith(textScaler: widget.textScaler),
      shrinkWrap: widget.shrinkWrap ?? false,
    );
  }
}
