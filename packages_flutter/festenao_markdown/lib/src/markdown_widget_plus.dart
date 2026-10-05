import 'package:festenao_theme/legacy_material.dart';
import 'package:flutter/material.dart' as legacy show Theme;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_ui/material_ui.dart';

export 'package:flutter_markdown_plus/flutter_markdown_plus.dart'
    show MarkdownStyleSheet, MarkdownTapLinkCallback;

/// A widget that displays markdown content using the [MarkdownWidget] package.
class FestenaoMarkdownWidget extends StatefulWidget {
  /// Whether to shrink the widget to fit its content.
  final bool? shrinkWrap;

  /// The markdown content to display.
  final String data;

  /// The text scaler to use for scaling the text.
  final TextScaler? textScaler;

  /// Styles on top of the ones derived from the theme.
  final MarkdownStyleSheet? styleSheet;

  /// Called when a link is tapped.
  final MarkdownTapLinkCallback? onTapLink;

  /// The constructor for [FestenaoMarkdownWidget].
  const FestenaoMarkdownWidget({
    super.key,
    this.textScaler,
    required this.data,
    this.shrinkWrap = true,
    this.styleSheet,
    this.onTapLink,
  });

  @override
  State<FestenaoMarkdownWidget> createState() => _FestenaoMarkdownWidgetState();
}

class _FestenaoMarkdownWidgetState extends State<FestenaoMarkdownWidget> {
  @override
  Widget build(BuildContext context) {
    var data = widget.data;
    // flutter_markdown_plus is built on package:flutter/material.dart: the
    // theme it reads is the flutter one the bridge derives from the app's.
    return legacyMaterialLeaf(
      Builder(
        builder: (context) {
          var styleSheet = MarkdownStyleSheet.fromTheme(
            legacy.Theme.of(context),
          ).copyWith(textScaler: widget.textScaler);
          var custom = widget.styleSheet;
          if (custom != null) {
            styleSheet = styleSheet.merge(custom);
          }
          return MarkdownBody(
            data: data,
            styleSheet: styleSheet,
            onTapLink: widget.onTapLink,
            shrinkWrap: widget.shrinkWrap ?? false,
          );
        },
      ),
    );
  }
}
