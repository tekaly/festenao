---
name: festenao-markdown-widget
description: >-
  Use when a Festenao Flutter screen has to render a markdown string (CMS page
  text, help/about content, an LLM answer): the FestenaoMarkdownWidget widget
  (data, shrinkWrap, textScaler) and the interchangeable entry points
  package:festenao_markdown/markdown.dart, markdown_plus.dart and
  gpt_markdown.dart, which wrap flutter_markdown_plus MarkdownBody and
  MarkdownStyleSheet behind a single indirection.
---

# Markdown widget (festenao_markdown)

`festenao_markdown` is a one-widget indirection layer: apps render markdown
through `FestenaoMarkdownWidget` instead of depending on a markdown package
directly, so the underlying renderer (today `flutter_markdown_plus`) can be
swapped without touching the apps.

## Guidelines

* Dependency (not on pub.dev, git only):

  ```yaml
  dependencies:
    festenao_markdown:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_markdown
  ```

* Import `package:festenao_markdown/markdown.dart` unless you have a reason
  not to. `markdown_plus.dart` (the concrete `flutter_markdown_plus` backed
  one) and `gpt_markdown.dart` (kept for LLM-rendering call sites) both
  re-export the same `FestenaoMarkdownWidget` today — they are aliases, so a
  screen can be moved between them with only its import line changing. Never
  import `package:festenao_markdown/src/...`.
* Never import `flutter_markdown_plus`, `markdown` or `MarkdownBody` in app
  code: that is exactly the coupling this package exists to prevent.
* `FestenaoMarkdownWidget({required String data, bool? shrinkWrap = true,
  TextScaler? textScaler})` — that is the whole API. `data` is the raw markdown
  string; there is no `onTapLink`, `selectable` or `styleSheet` parameter, and
  no async/file loading: read the text yourself and pass the `String`.
* It renders a `MarkdownBody` styled from `MarkdownStyleSheet.fromTheme(
  Theme.of(context))`, so it inherits the ambient `ThemeData` — change the
  app/section theme (or wrap it in a `Theme`) to restyle headings and code
  blocks. `textScaler` is applied on top of that style sheet; a null
  `textScaler` keeps the theme's own scaling.
* `MarkdownBody` does **not** scroll. `shrinkWrap: true` (the default) sizes it
  to its content, which is what you want inside a `ListView`,
  `SingleChildScrollView` or `Column`. Pass `shrinkWrap: false` only when the
  widget is given bounded constraints (inside an `Expanded`, a `SizedBox`), and
  provide the scrolling yourself.
* It needs a `Material`/`Theme` ancestor (`Theme.of(context)`): inside a
  `MaterialApp` in the app, and inside a `MaterialApp` in widget tests.
* Testing: `testWidgets` + `pumpWidget(MaterialApp(home: Scaffold(body:
  FestenaoMarkdownWidget(data: '# Hello'))))`, then
  `expect(find.text('Hello'), findsOneWidget)` — the heading markers are
  consumed by the renderer, so match the plain text. The package's own
  `test/festenao_markdown_test.dart` does this once per entry point, with
  import prefixes, to assert the three libraries stay interchangeable.

## Examples

### A markdown page from CMS/help text

```dart
import 'package:festenao_markdown/markdown.dart';
import 'package:flutter/material.dart';

/// Scrollable screen rendering a markdown document.
class MarkdownPageScreen extends StatelessWidget {
  /// Page title.
  final String title;

  /// Raw markdown content.
  final String content;

  /// Constructor.
  const MarkdownPageScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    // MarkdownBody does not scroll: shrinkWrap inside a scrollable.
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [FestenaoMarkdownWidget(data: content)],
    ),
  );
}
```

### Bounded, scaled, themed

```dart
import 'package:festenao_markdown/markdown.dart';
import 'package:flutter/material.dart';

/// A fixed height markdown preview, slightly smaller than the body text,
/// restyled through the ambient theme.
class MarkdownPreview extends StatelessWidget {
  /// Raw markdown content.
  final String content;

  /// Constructor.
  const MarkdownPreview({super.key, required this.content});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 200,
    child: SingleChildScrollView(
      child: Theme(
        data: Theme.of(context).copyWith(
          // The style sheet is built from the ambient theme.
          textTheme: Theme.of(context).textTheme.apply(bodyColor: Colors.grey),
        ),
        child: FestenaoMarkdownWidget(
          data: content,
          textScaler: const TextScaler.linear(0.9),
        ),
      ),
    ),
  );
}
```

### Widget test

```dart
import 'package:festenao_markdown/markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the markdown text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FestenaoMarkdownWidget(data: '# Hello\n\nSome *body*.'),
        ),
      ),
    );
    expect(find.byType(FestenaoMarkdownWidget), findsOneWidget);
    // Markers are consumed by the renderer, match the plain text.
    expect(find.text('Hello'), findsOneWidget);
  });
}
```
