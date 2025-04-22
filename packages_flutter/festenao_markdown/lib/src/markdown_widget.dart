import 'package:flutter/material.dart';
import 'package:markdown_widget/widget/all.dart';

/// A widget that displays markdown content using the [MarkdownWidget] package.
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
    return MarkdownWidget(data: data, shrinkWrap: widget.shrinkWrap ?? false);
  }
}
