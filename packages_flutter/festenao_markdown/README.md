# festenao_markdown

One widget, `FestenaoMarkdownWidget`, to show a markdown string (CMS text,
help pages, an LLM answer) in a festenao Flutter app. Apps go through it
instead of a markdown package, so the renderer (today
[flutter_markdown_plus](https://pub.dev/packages/flutter_markdown_plus),
GitHub flavored markdown) can change without touching them.

Flutter only, on [`material_ui`](https://pub.dev/packages/material_ui). Every
platform (Android, iOS, macOS, Linux, Windows, web): plain Dart, no plugin.

## Getting started

Not on pub.dev, add it as a git dependency, with `material_ui`:

```yaml
dependencies:
  material_ui: ">=1.5.0"
  festenao_markdown:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_markdown
```

```dart
import 'package:festenao_markdown/markdown.dart';
import 'package:material_ui/material_ui.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('About')),
    // The widget does not scroll: put it in a scrollable.
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        FestenaoMarkdownWidget(
          data: '# Festival\n\nThree days of **music**, see the [program](https://example.com).',
        ),
      ],
    ),
  );
}
```

A complete app is in [example/main.dart](example/main.dart).

## The widget

`FestenaoMarkdownWidget({required String data, bool? shrinkWrap = true,
TextScaler? textScaler, MarkdownStyleSheet? styleSheet,
MarkdownTapLinkCallback? onTapLink})`:

- `data`: the markdown text. No loading: read the file or the document
  yourself and pass the string.
- `shrinkWrap`: `true` (default) sizes it to its content, for a `ListView`, a
  `Column`, a `SingleChildScrollView`; `false` (or `null`) fills bounded
  constraints (an `Expanded`, a `SizedBox`).
- Styles come from the app's material_ui theme; `textScaler` and `styleSheet`
  (merged over them) adjust them.
- `onTapLink(text, href, title)`: links do nothing without it (open `href`
  with url_launcher, or route inside the app).

`package:festenao_markdown/markdown.dart`, `markdown_plus.dart` and
`gpt_markdown.dart` export the same widget (and `MarkdownStyleSheet`,
`MarkdownTapLinkCallback`): use `markdown.dart`.

## Good to know

- Restyle with the material_ui `Theme` (or `styleSheet`), not the `Theme` of
  `package:flutter/material.dart`: the widget maps the material_ui theme
  (festenao_theme's legacy material bridge) and ignores the other one.
- Images with an http(s) url are loaded from the network.
- Do not import flutter_markdown_plus or `package:markdown` in app code: that
  is the coupling this package removes.

Agent skill: [festenao-markdown-widget](skills/festenao-markdown-widget/SKILL.md).
