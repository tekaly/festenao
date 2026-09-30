---
name: festenao-media-base-app-usage
description: >-
  Use when bootstrapping a quick festenao demo or media Flutter app on
  festenao_media_base_app, the one dependency facade over the festenao Flutter
  toolkit: festenao_widget.dart (BodyContainer, TilePadding, poppinsThemeData1
  / themeData1, mini ui muiScreenWidget / muiItem / muiMenu / muiSnack /
  muiBuildContext, ContentNavigator.pushBuilder, webSplashReady /
  webSplashHide, ValueStreamBuilder, cv ui), festenao_flutter.dart
  (setPathUrlStrategy, hideCursor / showCursor, asset utils, rx blocs),
  festenao_common.dart (cv json, AutoDisposeStateBaseBloc, sleep, tekartik
  common utils) and festenao_support.dart (tkcms auth and support for the
  tools); also the youtube player, markdown, icon and theme packages it
  brings as dependencies and the tekaly_assets splash files it declares.
---

# festenao_media_base_app usage

`festenao_media_base_app` has no code of its own: four libraries re-export
the festenao Flutter toolkit so a demo or media app (karaoke, audio,
youtube, markdown viewer) depends on one package and imports one facade.
Its `lib/main.dart` is the stock Flutter counter, not an API.

```dart
import 'package:festenao_media_base_app/festenao_widget.dart';
import 'package:flutter/material.dart';

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

## Guidelines

* Dependency (git, not on pub.dev):
  ```yaml
  dependencies:
    festenao_media_base_app:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_media_base_app
  ```
* The four facades, from the narrowest up (each one exports the previous):
  * `package:festenao_media_base_app/festenao_common.dart`, dart only
    (`festenao_common_flutter/common_utils.dart`): the `cv` json models,
    the audi blocs (`AutoDisposeStateBaseBloc`, `audiAddStreamSubscription`),
    `tekartik_common_utils` (`sleep`, `unawait`, string, num, iterable,
    hex utils) and the rx blocs.
  * `festenao_flutter.dart` adds the Flutter utils: `setPathUrlStrategy` /
    `setHashUrlStrategy` / `webUsePathUrlStrategy`, `hideCursor` /
    `showCursor` (web), the asset bundle helpers (`getAssetList`),
    `webSplashReady` / `webSplashHide`.
  * `festenao_widget.dart` adds `festenao_theme` (`poppinsThemeData1`,
    `poppinsThemeDataLight1`, `themeData1`, `themeDataLight1`),
    `BodyContainer(child:, width: 840)`, `TilePadding`, the mini ui
    (`muiScreenWidget`, `muiBodyWidget`, `muiItem`, `muiMenu`, `muiSnack`,
    `muiGetString`, `muiSelectString`, `muiConfirm`, `muiBuildContext`),
    `ContentNavigator`, `ValueStreamBuilder`, the busy indicators and the
    cv ui widgets. Import this one in screens.
  * `festenao_support.dart`: `tkcms_common/tkcms_auth.dart` and
    `tkcms_support.dart`, for the dart tools of the app (`bin/`, `tool/`).
* Splash: `webSplashReady()` first thing in `main`, `webSplashHide()` once
  the first screen can draw (the apps wait about 300 ms after `runApp`);
  both are no-ops off the web. The package's pubspec declares the
  `tekaly_assets` logo and `tekaly_splash.js`, so they are bundled with the
  app, but the app's `web/index.html` still needs the
  `<div id="app_splash" class="app-loading">` markup of
  `tekartik_web_splash`. `?splash` in the url keeps it visible,
  `?splash=5000` for 5 s.
* Theme: `poppinsThemeData1({seedColor})` uses the Poppins font bundled by
  `festenao_theme`, nothing to declare in the app; `themeData1()` keeps the
  default font. Both float the snack bars.
* Not re-exported although they are dependencies of this package:
  `festenao_youtube_player`, `festenao_markdown`, `festenao_icon`. Import
  them by their own package name and list them in your pubspec too, or the
  `depend_on_referenced_packages` lint fires (the package silences it with
  `ignore_for_file` on every facade).
* Quick screens: `muiScreenWidget(title, () { muiItem(name, () async {...});
  muiMenu(name, () {...}); })` is a menu screen; inside an item
  `muiBuildContext` is the context to navigate or `muiSnack` with. Push a
  widget without a route table with
  `ContentNavigator.pushBuilder<void>(context, builder: (_) => const MyScreen())`.
* Layout: `BodyContainer` centers its child in an 840 px column on wide
  screens, `TilePadding` gives the 16 px horizontal tile padding.

## Examples

### A demo app: splash, url strategy, theme, menu

```dart
import 'package:festenao_media_base_app/festenao_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  webSplashReady();
  if (kIsWeb) {
    setPathUrlStrategy();
  }
  runApp(const DemoApp());
  sleep(300).then((_) => webSplashHide());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Media demo',
    theme: poppinsThemeData1(),
    home: const DemoMenu(),
  );
}

class DemoMenu extends StatelessWidget {
  const DemoMenu({super.key});

  @override
  Widget build(BuildContext context) => muiScreenWidget('Media demo', () {
    muiItem('Player', () {
      ContentNavigator.pushBuilder<void>(
        muiBuildContext,
        builder: (_) => const PlayerScreen(),
      );
    });
    muiItem('Snack', () async {
      await muiSnack(muiBuildContext, 'Hello');
    });
  });
}

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Player')),
    body: ListView(
      children: const [
        BodyContainer(child: TilePadding(child: Text('Player goes here'))),
      ],
    ),
  );
}
```

### A stream driven tile with the audi bloc and ValueStreamBuilder

```dart
import 'package:festenao_media_base_app/festenao_widget.dart';
import 'package:flutter/material.dart';

/// A counter bloc: `add` publishes a new state, disposed with the widget.
class CounterBloc extends AutoDisposeStateBaseBloc<int> {
  CounterBloc() {
    add(0);
  }

  void increment() => add((state.valueOrNull ?? 0) + 1);
}

class CounterTile extends StatelessWidget {
  final CounterBloc bloc;

  const CounterTile({super.key, required this.bloc});

  @override
  Widget build(BuildContext context) => ValueStreamBuilder<int>(
    stream: bloc.state,
    builder: (context, snapshot) => ListTile(
      title: Text('count ${snapshot.data ?? 0}'),
      onTap: bloc.increment,
    ),
  );
}
```

## Common mistakes

* A blank page that never goes away on the web: `webSplashHide()` never
  called, or the `app_splash` div missing so `webSplashReady()` has
  nothing to hide (`?splash` in the url is the other cause).
* `Undefined name 'YoutubePlayer'` with only this package imported: the
  youtube, markdown and icon packages are dependencies, not exports.
