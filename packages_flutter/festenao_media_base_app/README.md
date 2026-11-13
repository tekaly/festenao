# festenao_media_base_app

One dependency for a quick festenao demo or media app (karaoke, audio,
youtube, markdown viewer): it has no code of its own, four libraries
re-export the festenao Flutter toolkit (theme, mini ui menus, splash, url
strategy, blocs, cv). Its `lib/main.dart` is the stock Flutter counter, not
an API.

## Getting started

Not on pub.dev, a git dependency:

```yaml
dependencies:
  festenao_media_base_app:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_media_base_app
```

```dart
import 'package:festenao_media_base_app/festenao_widget.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  webSplashReady();
  runApp(
    MaterialApp(
      theme: poppinsThemeData1(),
      home: const Scaffold(body: Center(child: Text('ready'))),
    ),
  );
  sleep(300).then((_) => webSplashHide());
}
```

Platforms: every Flutter platform; the splash and cursor helpers act on the
web only (no-ops elsewhere). Flutter 3.50 deprecates
`package:flutter/material.dart`: import `package:material_ui/material_ui.dart`
(a dependency of this package) instead.

## The libraries

From the narrowest up, each one exporting the previous:

- `festenao_common.dart`: dart only, cv json models, blocs, tekartik common
  utils (`sleep`, ...);
- `festenao_flutter.dart`: url strategy, web cursor, asset helpers,
  `webSplashReady` / `webSplashHide`;
- `festenao_widget.dart`: festenao_theme (`poppinsThemeData1`, `themeData1`),
  `BodyContainer`, `TilePadding`, the mini ui (`muiScreenWidget`, `muiItem`,
  ...), `ContentNavigator`, `ValueStreamBuilder`. Import this one in screens;
- `festenao_support.dart`: tkcms auth and support, for the dart tools.

## What to know

- The youtube player, markdown and icon packages are dependencies, not
  exports: import them by their own name and list them in your pubspec.
- The web splash needs the `app_splash` markup of `tekartik_web_splash` in
  `web/index.html`, and `webSplashHide()` once the first screen draws.

More, with examples: the `festenao-media-base-app-usage` skill
(`skills/festenao-media-base-app-usage/SKILL.md`).
