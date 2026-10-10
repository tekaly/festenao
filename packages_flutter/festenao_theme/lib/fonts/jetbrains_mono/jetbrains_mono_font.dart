import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../src/font_family.dart';

/// JetBrains Mono font family
const jetBrainsMonoFontFamily = 'JetBrains Mono';

/// The JetBrains Mono NL (no ligatures) files: regular, medium (500), semi
/// bold (600) and bold (700), registered by `loadFestenaoFonts()`.
const FestenaoFontFamily jetBrainsMonoFont = (
  family: jetBrainsMonoFontFamily,
  package: 'festenao_theme',
  files: [
    'fonts/jetbrains_mono/JetBrainsMonoNL-Regular.ttf',
    'fonts/jetbrains_mono/JetBrainsMonoNL-Medium.ttf',
    'fonts/jetbrains_mono/JetBrainsMonoNL-SemiBold.ttf',
    'fonts/jetbrains_mono/JetBrainsMonoNL-Bold.ttf',
  ],
);

var _licenseAdded = false;

/// Add JetBrains Mono license, once (`loadFestenaoFonts()` calls it).
/// Don't forget the asset in pubspec.yaml
/// - packages/festenao_theme/fonts/jetbrains_mono/OFL.txt
void addJetBrainsMonoLicense() {
  if (_licenseAdded) {
    return;
  }
  _licenseAdded = true;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'packages/festenao_theme/fonts/jetbrains_mono/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(['JetBrains Mono'], license);
  });
}
