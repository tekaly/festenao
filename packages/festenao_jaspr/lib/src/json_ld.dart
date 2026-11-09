import 'dart:convert';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// [data] as JSON for a `<script type="application/ld+json">`: every `<`
/// is escaped as `\u003c` (still valid JSON, the same value once decoded).
///
/// Escaping `</` only is not enough: a value holding `<!--` then `<script`
/// (an event description) puts the html parser in a state where the
/// closing `</script>` no longer ends the element, the rest of the page
/// would be read as the script.
String jsonLdEncode(Map<String, Object?> data) =>
    jsonEncode(data).replaceAll('<', r'\u003c');

/// The `<script type="application/ld+json">` of [data].
Component jsonLdScript(Map<String, Object?> data) => script(
  attributes: const {'type': 'application/ld+json'},
  content: jsonLdEncode(data),
);
