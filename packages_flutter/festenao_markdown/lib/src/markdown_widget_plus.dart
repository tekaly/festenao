import 'package:festenao_theme/legacy_material.dart';
// flutter_markdown_plus (1.0.12) is still built on the legacy library.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as legacy show Theme;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_ui/material_ui.dart';

export 'package:flutter_markdown_plus/flutter_markdown_plus.dart'
    show MarkdownStyleSheet, MarkdownTapLinkCallback;

/// Shows the markdown [data] (GitHub flavored, rendered by
/// flutter_markdown_plus `MarkdownBody`), styled from the app's material_ui
/// theme.
///
/// It does not scroll: keep [shrinkWrap] (the default) inside a `ListView` or
/// a `Column`. Restyle it with the material_ui `Theme`, [textScaler] or
/// [styleSheet]; the `Theme` of `package:flutter/material.dart` is ignored.
class FestenaoMarkdownWidget extends StatefulWidget {
  /// Whether to shrink the widget to fit its content (`true` by default);
  /// `false` or `null` fill bounded constraints.
  final bool? shrinkWrap;

  /// The markdown content to display.
  final String data;

  /// The text scaler to use for scaling the text (null keeps the theme's).
  final TextScaler? textScaler;

  /// Styles on top of the ones derived from the theme (merged: the text
  /// styles are merged, the other values replaced).
  final MarkdownStyleSheet? styleSheet;

  /// Called when a link is tapped, with its text, href and title; links do
  /// nothing without it.
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
