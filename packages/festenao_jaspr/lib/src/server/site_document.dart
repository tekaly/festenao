import 'dart:io';

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:markdown/markdown.dart' show markdownToHtml;

/// The html of the markdown file at [path], relative to the site package
/// (the current directory of `jaspr build`, `jaspr serve` and the tests).
String markdownFileHtml(String path) =>
    markdownToHtml(File(path).readAsStringSync());

/// The markdown file at [path] rendered in a `div` of [classes] (legal
/// pages from `content/legal/<name>.<lang>.md`).
class MarkdownFile extends StatelessComponent {
  /// The file, relative to the site package.
  final String path;

  /// The css classes of the `div`.
  final String? classes;

  /// A markdown file.
  const MarkdownFile(this.path, {super.key, this.classes});

  @override
  Component build(BuildContext context) =>
      div(classes: classes, [RawText(markdownFileHtml(path))]);
}

/// The document of every page of a static site: theme color, color scheme,
/// [head] (icons...), preloaded fonts, the stylesheet at [cssPath] inlined
/// (the first paint needs no second request), then [body] (the router).
Component siteDocument({
  required String title,
  required Component body,
  String? themeColor,
  String? colorScheme,
  List<String> preloadFonts = const [],
  String? cssPath = 'styles/site.css',
  List<Component> head = const [],
}) => Document(
  title: title,
  head: [
    if (themeColor != null) meta(name: 'theme-color', content: themeColor),
    if (colorScheme != null) meta(name: 'color-scheme', content: colorScheme),
    ...head,
    for (var font in preloadFonts)
      link(
        rel: 'preload',
        href: font,
        as: 'font',
        type: 'font/woff2',
        attributes: const {'crossorigin': ''},
      ),
    if (cssPath != null)
      Component.element(
        tag: 'style',
        children: [RawText(File(cssPath).readAsStringSync())],
      ),
  ],
  body: body,
);
