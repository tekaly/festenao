import 'dart:convert';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// [data] as JSON for a `<script type="application/ld+json">`: a `</`
/// inside the json would close the script element, it is escaped.
String jsonLdEncode(Map<String, Object?> data) =>
    jsonEncode(data).replaceAll('</', r'<\/');

/// The `<script type="application/ld+json">` of [data].
Component jsonLdScript(Map<String, Object?> data) => script(
  attributes: const {'type': 'application/ld+json'},
  content: jsonLdEncode(data),
);
