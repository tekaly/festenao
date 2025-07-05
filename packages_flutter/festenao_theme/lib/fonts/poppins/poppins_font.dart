import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Poppins font family
const poppinsFontFamily = 'Poppins';

/// Add poppins license
void addPoppinsLicense() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'packages/festenao_theme/fonts/poppins/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
}
