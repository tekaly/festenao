# festenao_screenshot

Screenshots of a Flutter app in `flutter test`: the widgets, the router and
the in memory backends are the real ones, nothing needs a display. Used by
the festenao harnesses (`festenao_theme/example`,
`festenao_dashboard_base_app/example/demo`) and the private festenao ones.

- `loadScreenshotFonts()`: the real fonts (the app `FontManifest.json`,
  Roboto and the material icons of the flutter sdk, the cupertino icons, the
  festenao_theme families under their bare and package names, DejaVu Sans as
  the fallback), once; the test harness draws every glyph as a box
  otherwise.
- `patchFontFallbacks(tester)`: the font fallbacks of a real app on the
  painted text, done before each shot.
- `ScreenshotSession`: `open`, `setSize`, `settle`, `waitFor`, `tap`,
  `back`, `shot(name, prefix:)` writing `[<prefix>_]NN_<name>.png` (numbered
  per directory and prefix), `shotNamed(fileName)`, a name filter (`only`,
  `wantsNext`, `skip`), the errors the screens reported.
- `runScreenshots(description, body, directory:)`: the widget test around a
  session, in real async, fonts loaded, shadows drawn, no debug banner.
- `screenshotNames(value)`: the names of a comma separated `--dart-define`.

```dart
import 'dart:io';

import 'package:festenao_screenshot/festenao_screenshot.dart';
import 'package:flutter/material.dart';

void main() {
  runScreenshots('my app', (session) async {
    await session.open(const MyApp(), size: const Size(400, 860));
    await session.shot('home');
    await session.tapText('Settings');
    await session.shot('settings');
  }, directory: Directory('.local/screenshots'));
}
```

The app adds it as a dev dependency and runs
`flutter test tool/screenshot_test.dart`.
