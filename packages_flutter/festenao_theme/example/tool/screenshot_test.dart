/// Screenshots of every festenao theme preset, light and dark, on the
/// gallery pages, at a phone and a desk size.
///
/// ```
/// flutter test tool/screenshot_test.dart
/// flutter test tool/screenshot_test.dart --dart-define=FESTENAO_THEME_SCREENSHOT_DIR=.local/themes_2
/// flutter test tool/screenshot_test.dart --dart-define=FESTENAO_THEME_SCREENSHOT_ONLY=arcade,nocturne
/// ```
///
/// The pngs land in `.local/themes` (git ignored):
/// `<preset>_<light|dark>_<desktop|phone>_<page>.png`.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:festenao_theme/design.dart';
import 'package:festenao_theme_example/src/gallery_app.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _directory = String.fromEnvironment(
  'FESTENAO_THEME_SCREENSHOT_DIR',
  defaultValue: '.local/themes',
);

final _only = const String.fromEnvironment('FESTENAO_THEME_SCREENSHOT_ONLY')
    .split(',')
    .map((id) => id.trim())
    .where((id) => id.isNotEmpty)
    .toSet();

const _phone = Size(400, 860);
const _desktop = Size(1440, 900);
const _pixelRatio = 2.0;

final _rootKey = GlobalKey();

Future<void> _loadFonts() async {
  var manifest = (jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List).cast<Map<String, Object?>>();
  for (var entry in manifest) {
    var loader = FontLoader(entry['family'] as String);
    for (var font in (entry['fonts'] as List).cast<Map<String, Object?>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = _pixelRatio;
  tester.view.physicalSize = size * _pixelRatio;
  await tester.binding.setSurfaceSize(size);
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _settle(tester);
  var exception = tester.takeException();
  if (exception != null) {
    // ignore: avoid_print
    print('$name: $exception');
  }
  var boundary =
      tester.renderObject(find.byKey(_rootKey)) as RenderRepaintBoundary;
  var image = await boundary.toImage(pixelRatio: _pixelRatio);
  var bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  var file = File('$_directory/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote ${file.path}');
}

void main() {
  testWidgets('theme screenshots', (tester) async {
    await tester.runAsync(() async {
      debugDisableShadows = false;
      try {
        await _loadFonts();
        var controller = GalleryController();
        await tester.pumpWidget(
          RepaintBoundary(
            key: _rootKey,
            child: GalleryApp(controller: controller),
          ),
        );
        for (var preset in festenaoThemePresets) {
          if (_only.isNotEmpty && !_only.contains(preset.id)) {
            continue;
          }
          controller.selectPreset(preset);
          for (var brightness in [Brightness.light, Brightness.dark]) {
            controller.selectBrightness(brightness);
            var mode = brightness.name;
            for (var (size, sizeName, pages) in [
              (_desktop, 'desktop', GalleryPage.values),
              (_phone, 'phone', [GalleryPage.overview, GalleryPage.access]),
            ]) {
              await _setSize(tester, size);
              for (var page in pages) {
                controller.selectPage(page);
                await _shot(
                  tester,
                  '${preset.id}_${mode}_${sizeName}_${page.name}',
                );
              }
            }
          }
        }
      } finally {
        debugDisableShadows = true;
      }
    });
    await tester.binding.setSurfaceSize(null);
  });
}
