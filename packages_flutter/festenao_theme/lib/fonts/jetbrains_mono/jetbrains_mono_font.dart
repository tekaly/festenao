import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// JetBrains Mono font family
const jetBrainsMonoFontFamily = 'JetBrains Mono';

/// Add JetBrains Mono license
/// Don't forget the asset in pubspec.yaml
/// - packages/festenao_theme/fonts/jetbrains_mono/OFL.txt
void addJetBrainsMonoLicense() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'packages/festenao_theme/fonts/jetbrains_mono/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(['JetBrains Mono'], license);
  });
}
