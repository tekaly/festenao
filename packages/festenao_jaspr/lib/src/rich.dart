/// Text with the two marks the copy uses: `**bold**` (an app's labels) and
/// `[text](url)` links.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

final _marks = RegExp(r'\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)]+)\)');

/// [text] as components: plain text, `strong` and `a`.
List<Component> rich(String text) {
  var components = <Component>[];
  var start = 0;
  for (var match in _marks.allMatches(text)) {
    if (match.start > start) {
      components.add(Component.text(text.substring(start, match.start)));
    }
    var bold = match.group(1);
    if (bold != null) {
      components.add(strong([Component.text(bold)]));
    } else {
      components.add(
        a(href: match.group(3)!, [Component.text(match.group(2)!)]),
      );
    }
    start = match.end;
  }
  if (start < text.length) {
    components.add(Component.text(text.substring(start)));
  }
  return components;
}
