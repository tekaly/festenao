import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// A widget that displays markdown content using the [GptMarkdown] package.
class FestenaoMarkdownWidget extends StatefulWidget {
  /// Whether to shrink the widget to fit its content.
  final bool? shrinkWrap;

  /// The markdown content to display.
  final String data;

  /// The constructor for [FestenaoMarkdownWidget].
  const FestenaoMarkdownWidget({
    super.key,
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
    return GptMarkdown(data);
  }
}
