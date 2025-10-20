import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Poppins font family
const poppinsFontFamily = 'Poppins';

/// Add poppins license
/// Don't forget to the asset in pubspec.yaml
/// - packages/festenao_theme/fonts/poppins/OFL.txt
void addPoppinsLicense() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'packages/festenao_theme/fonts/poppins/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
}
