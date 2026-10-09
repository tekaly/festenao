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
/// `<preset>_<light|dark>_<desktop|phone>_<page>.png`. The fonts and the
/// session come from `festenao_screenshot`.
library;

import 'dart:io';

import 'package:festenao_screenshot/festenao_screenshot.dart';
import 'package:festenao_theme/design.dart';
import 'package:festenao_theme_example/src/gallery_app.dart';
import 'package:material_ui/material_ui.dart';

const _directory = String.fromEnvironment(
  'FESTENAO_THEME_SCREENSHOT_DIR',
  defaultValue: '.local/themes',
);

/// The presets to shoot (their ids), all when empty.
final _only = screenshotNames(
  const String.fromEnvironment('FESTENAO_THEME_SCREENSHOT_ONLY'),
);

const _phone = Size(400, 860);
const _desktop = Size(1440, 900);

void main() {
  runScreenshots(
    'theme screenshots',
    (session) async {
      var controller = GalleryController();
      await session.tester.pumpWidget(
        session.wrap(GalleryApp(controller: controller)),
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
            await session.setSize(size);
            for (var page in pages) {
              controller.selectPage(page);
              await session.shotNamed(
                '${preset.id}_${mode}_${sizeName}_${page.name}',
              );
            }
          }
        }
      }
    },
    directory: Directory(_directory),
    // The other presets stay when only some are shot.
    clearPngs: _only.isEmpty,
    // The screens see the pixel ratio of the pngs.
    devicePixelRatio: 2,
    settleRounds: 12,
  );
}
