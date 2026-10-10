import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../src/font_family.dart';

/// Poppins font family
const poppinsFontFamily = 'Poppins';

/// The Poppins files of the festenao themes: regular, italic, medium (500),
/// semi bold (600) and bold (700), registered by `loadFestenaoFonts()`.
const FestenaoFontFamily poppinsFont = (
  family: poppinsFontFamily,
  package: 'festenao_theme',
  files: [
    'fonts/poppins/Poppins-Regular.ttf',
    'fonts/poppins/Poppins-Italic.ttf',
    'fonts/poppins/Poppins-Medium.ttf',
    'fonts/poppins/Poppins-SemiBold.ttf',
    'fonts/poppins/Poppins-Bold.ttf',
  ],
);

/// Poppins extra bold (800), added to the `Poppins` family for an app
/// drawing heavier headings: `loadFestenaoFonts(extra: [poppinsExtraBoldFont])`.
const FestenaoFontFamily poppinsExtraBoldFont = (
  family: poppinsFontFamily,
  package: 'festenao_theme',
  files: ['fonts/poppins/Poppins-ExtraBold.ttf'],
);

var _licenseAdded = false;

/// Add poppins license, once (`loadFestenaoFonts()` calls it).
/// Don't forget to the asset in pubspec.yaml
/// - packages/festenao_theme/fonts/poppins/OFL.txt
void addPoppinsLicense() {
  if (_licenseAdded) {
    return;
  }
  _licenseAdded = true;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'packages/festenao_theme/fonts/poppins/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(['Poppins'], license);
  });
}
