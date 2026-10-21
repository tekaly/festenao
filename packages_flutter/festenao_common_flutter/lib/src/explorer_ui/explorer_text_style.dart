import 'package:festenao_theme/theme.dart';
import 'package:material_ui/material_ui.dart';

/// The fonts the monospace text falls back on when the festenao monospace
/// font is not registered (an app that does not call `loadFestenaoFonts`):
/// the platform monospace ones, so that columns still line up.
const explorerMonospaceFontFallback = <String>[
  'monospace',
  'DejaVu Sans Mono',
  'Liberation Mono',
  'Noto Sans Mono',
  'Menlo',
  'Consolas',
  'Courier New',
];

/// The monospace text of the explorers: hex dumps, text files, protobuf
/// text, raw values.
const explorerMonospaceTextStyle = TextStyle(
  fontFamily: festenaoMonospaceFontFamily,
  fontFamilyFallback: explorerMonospaceFontFallback,
  fontSize: 13,
);
