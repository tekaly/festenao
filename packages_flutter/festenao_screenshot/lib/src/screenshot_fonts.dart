import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The package config of the package or workspace the test runs in (a pub
/// workspace keeps it at its root, up the parents), null when not found.
File? _packageConfigFile() {
  var dir = Directory.current.absolute;
  while (true) {
    var file = File('${dir.path}/.dart_tool/package_config.json');
    if (file.existsSync()) {
      return file;
    }
    var parent = dir.parent;
    if (parent.path == dir.path) {
      return null;
    }
    dir = parent;
  }
}

/// The root directory of the package [name] from the package config of the
/// current directory, null when it is not in it.
String? screenshotPackageRoot(String name) {
  var file = _packageConfigFile();
  if (file == null) {
    return null;
  }
  var config = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  for (var package in config['packages'] as List<Object?>) {
    package as Map<String, Object?>;
    if (package['name'] == name) {
      var root = file.absolute.uri.resolve(package['rootUri'] as String);
      var path = root.toFilePath();
      return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    }
  }
  return null;
}

/// Where the flutter sdk keeps the fonts a running app is given.
String get _materialFontsPath {
  // dart is `<flutter>/bin/cache/dart-sdk/bin/dart`.
  var flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  return '$flutterRoot/bin/cache/artifacts/material_fonts';
}

var _fontsLoaded = false;

/// Loads the real text and icon fonts, once: the test harness draws every
/// glyph as a box otherwise.
///
/// - the fonts the app declares (its `FontManifest.json`: the families of its
///   pubspec and of its dependencies, the material icons and symbols);
/// - Roboto (the family the material text styles ask for) and the material
///   icons from the flutter sdk, the cupertino icons when the app depends on
///   `cupertino_icons`;
/// - the families of festenao_theme when the app depends on it, under their
///   bare names (`Poppins`, `JetBrains Mono`, which only resolve in a running
///   app that declares them) and their package names, JetBrains Mono also as
///   `monospace` and `Courier New`;
/// - DejaVu Sans (from the system, when installed) for the glyphs the app
///   fonts lack, see [patchFontFallbacks].
Future<void> loadScreenshotFonts() async {
  if (_fontsLoaded) {
    return;
  }
  _fontsLoaded = true;
  var loaded = <String>{};

  Future<void> loadFiles(String family, List<String> paths) async {
    if (loaded.contains(family)) {
      return;
    }
    var loader = FontLoader(family);
    var found = false;
    for (var path in paths) {
      var file = File(path);
      if (file.existsSync()) {
        loader.addFont(
          file.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
        );
        found = true;
      }
    }
    if (found) {
      await loader.load();
      loaded.add(family);
    } else {
      stderr.writeln('no font for $family, it will draw as boxes');
    }
  }

  // The app fonts, as declared.
  try {
    var manifest = (jsonDecode(
      await rootBundle.loadString('FontManifest.json'),
    ) as List).cast<Map<String, Object?>>();
    for (var entry in manifest) {
      var family = entry['family'] as String;
      var loader = FontLoader(family);
      for (var font in (entry['fonts'] as List).cast<Map<String, Object?>>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
      loaded.add(family);
    }
  } catch (e) {
    stderr.writeln('no FontManifest.json: $e');
  }

  var materialFonts = _materialFontsPath;
  await loadFiles('Roboto', [
    for (var style in [
      'Regular',
      'Italic',
      'Medium',
      'MediumItalic',
      'Bold',
      'BoldItalic',
      'Light',
      'Black',
    ])
      '$materialFonts/Roboto-$style.ttf',
  ]);
  await loadFiles('MaterialIcons', [
    '$materialFonts/MaterialIcons-Regular.otf',
  ]);
  var cupertinoIcons = screenshotPackageRoot('cupertino_icons');
  if (cupertinoIcons != null) {
    await loadFiles('CupertinoIcons', [
      '$cupertinoIcons/assets/CupertinoIcons.ttf',
    ]);
  }

  var festenaoTheme = screenshotPackageRoot('festenao_theme');
  if (festenaoTheme != null) {
    var fonts = '$festenaoTheme/lib/fonts';
    var poppins = [
      for (var style in [
        'Regular',
        'Italic',
        'Medium',
        'MediumItalic',
        'SemiBold',
        'SemiBoldItalic',
        'Bold',
        'BoldItalic',
        'ExtraBold',
        'Light',
      ])
        '$fonts/poppins/Poppins-$style.ttf',
    ];
    for (var family in ['Poppins', 'packages/festenao_theme/Poppins']) {
      await loadFiles(family, poppins);
    }
    var mono = [
      for (var weight in ['Regular', 'Medium', 'SemiBold', 'Bold'])
        '$fonts/jetbrains_mono/JetBrainsMonoNL-$weight.ttf',
    ];
    for (var family in [
      'monospace',
      'Courier New',
      'JetBrains Mono',
      'packages/festenao_theme/JetBrains Mono',
    ]) {
      await loadFiles(family, mono);
    }
  }
  await loadFiles(_fallbackFontFamily, [
    for (var name in ['DejaVuSans', 'DejaVuSans-Bold'])
      '/usr/share/fonts/truetype/dejavu/$name.ttf',
  ]);
}

/// The family a real app draws the text that names no family with, on
/// Android (the desktop and web ones are alike).
const _platformFontFamily = 'Roboto';

/// The family drawing the glyphs the loaded fonts lack.
const _fallbackFontFamily = 'DejaVu Sans';

/// Gives the painted text the font fallbacks of a real app: the platform
/// font for the text that names no family, a system font for the glyphs the
/// app fonts lack.
///
/// The test harness has no fallback at all: a missing glyph is a box, and so
/// is the text that names no family, whatever font is loaded. A button style
/// built with a bare `TextStyle` drops the theme family that way. The painted
/// paragraphs are patched in place, until their widget rebuilds, so
/// `ScreenshotSession` patches them right before each shot.
void patchFontFallbacks(WidgetTester tester) {
  for (var object in tester.allRenderObjects) {
    if (object is RenderParagraph) {
      var text = object.text;
      if (text is TextSpan && text.style?.fontFamilyFallback == null) {
        var style = text.style ?? const TextStyle();
        object.text = TextSpan(
          text: text.text,
          children: text.children,
          style: style.copyWith(
            fontFamily: style.fontFamily ?? _platformFontFamily,
            fontFamilyFallback: [_fallbackFontFamily],
          ),
          recognizer: text.recognizer,
          mouseCursor: text.mouseCursor,
          onEnter: text.onEnter,
          onExit: text.onExit,
          semanticsLabel: text.semanticsLabel,
          locale: text.locale,
          spellOut: text.spellOut,
        );
      }
    }
  }
}
