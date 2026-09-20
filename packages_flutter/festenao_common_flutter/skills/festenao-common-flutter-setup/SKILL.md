---
name: festenao-common-flutter-setup
description: >-
  Use when setting up a festenao Flutter app on festenao_common_flutter: the
  barrel imports common_utils.dart (cv, tekartik_common_utils, app rx bloc),
  common_utils_flutter.dart (asset bundle utils, url strategy, cursor utils),
  common_utils_widget.dart (app widgets, BodyContainer, BusyIndicator,
  BusyScreenStateMixin, ContentNavigator, web splash),
  common_utils_sembast.dart, common_utils_support.dart, the dev menu
  (dev_menu_flutter.dart, dev_test_ui_flutter.dart: mainMenuFlutter, menu,
  item, write), festenaoFlavorContextDefault from festenao_flavor.dart, and
  the share link helpers of share_link.dart (appShareBaseUrl, appShareLink,
  ShareLinkItem, showShareLinksDialog, ShareLinkTile).
---

# Festenao common flutter setup (festenao_common_flutter)

`festenao_common_flutter` is the Flutter side of `festenao_common`: a set of
barrel libraries that pull the tekartik utilities a festenao app uses (one
import instead of ten), the default flavor of a build, a share link dialog,
plus the quizz widgets and the log screens documented in their own skills
(`festenao-common-flutter-quizz`, `festenao-common-flutter-log`).

## Guidelines

* Dependency (git, not on pub.dev):
  ```yaml
  dependencies:
    festenao_common_flutter:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_common_flutter
  ```
* Barrels, from the most generic to the widest (each re-exports the
  previous one):
  `package:festenao_common_flutter/common_utils.dart` (pure dart: `cv`
  json models `CvModelBase`/`CvField`, `festenao_common/festenao_audi.dart`,
  `tekartik_app_common_utils`, the rx bloc base, and `tekartik_common_utils`
  async / bool / byte_data / env (`kDartIsWeb`, `isDebug`) / hash_code / hex
  / int (`parseInt`) / iterable / num / string utils);
  `common_utils_flutter.dart` (adds `tekartik_app_flutter_common_utils`
  asset bundle and asset utils, the web `url_strategy` and `cursor_utils`,
  the rx flutter builders); `common_utils_widget.dart` (adds
  `tekartik_app_flutter_widget`: `app_widget`, `mini_ui`, `BodyContainer`,
  `BusyIndicator`, `BusyScreenStateMixin`, `cv_ui`, `tile_padding`, the
  theming widgets, plus `ContentNavigator`, `tekartik_app_rx_utils` and
  `tekartik_web_splash`). Pick the narrowest one a file needs.
* `common_utils_sembast.dart` is `festenao_common/festenao_sembast.dart`
  (sembast helpers) and `common_utils_support.dart` is
  `festenao_common/festenao_support.dart`; import them where those apis are
  used rather than the festenao_common paths, so the app depends on one
  package.
* Dev menu: `dev_menu_flutter.dart` exports `tekartik_app_dev_menu`
  (without its console `mainMenu`) and `tekartik_test_menu_flutter`:
  `mainMenuFlutter(() { menu('name', () { item('name', () {...}); }); })`
  builds the in-app test menu (`write` prints to its console);
  `dev_test_ui_flutter.dart` adds `package:dev_test` for the `test`/`group`
  style declarations in the same menu app.
* Flavor: `festenao_flavor.dart` re-exports
  `festenao_common/festenao_flavor.dart` (`FlavorContext`,
  `AppFlavorContext`, `toAppFlavorContext`, `tkCmsFlavorContextFromUri`...)
  and adds `festenaoFlavorContextDefault`: on the web the flavor read from
  `Uri.base` (`?flavor=dev`, `?dev`, a `my-app-dev` hosting sub domain,
  localhost is dev, anything else prod), otherwise `FlavorContext.dev` in
  debug builds and `FlavorContext.prod` in release. Use it as the default an
  explicit `--dart-define` or argument may override.
* Share links: `share_link.dart`. `appShareBaseUrl(defaultBaseUrl:)` is the
  app origin with a trailing `/` on the web (`Uri.base.origin`, never
  `Uri.base` itself, which is the current screen), `defaultBaseUrl` (the
  hosting url) off the web, `/` otherwise; `appShareLink('/playlist/123',
  defaultBaseUrl:)` builds the absolute link of an app location.
  `showShareLinksDialog(context, title:, links:, message:, onOpen:)` lists
  `ShareLinkItem(label:, url:)` rows, each a `ShareLinkTile` with a copy
  button (snack bar through `ScaffoldMessenger.maybeOf`) and an open button
  when `onOpen` is given.
* Never import `src/`; the public surface is the `lib/*.dart` files and
  `lib/log/log.dart`.

## Examples

### Flavor and app context at startup

```dart
import 'package:festenao_common_flutter/festenao_flavor.dart';

/// `myapp-dev` or `myapp-prod` depending on the build and, on the web, the
/// url (`?flavor=dev`, `my-app-dev.web.app`).
final appFlavorContext = festenaoFlavorContextDefault.toAppFlavorContext(
  baseAppId: 'myapp',
);

void main() {
  print('${appFlavorContext.appId} ${appFlavorContext.isDev}');
}
```

### Share dialog with copy and open buttons

```dart
import 'package:festenao_common_flutter/share_link.dart';
import 'package:flutter/material.dart';

Future<void> sharePlaylist(BuildContext context, String playlistId) {
  var viewUrl = appShareLink(
    '/playlist/$playlistId',
    defaultBaseUrl: 'https://myapp.web.app', // used off the web
  );
  return showShareLinksDialog(
    context,
    title: 'Share playlist',
    message: 'Anyone with the link can view it.',
    links: [
      ShareLinkItem(label: 'View', url: viewUrl),
      ShareLinkItem(label: 'Play', url: '$viewUrl?autoplay=1'),
    ],
    onOpen: (url) async {
      // launchUrl(Uri.parse(url)) with url_launcher, for example.
    },
  );
}
```

### A dev menu app

```dart
import 'package:festenao_common_flutter/dev_menu_flutter.dart';

void main() {
  mainMenuFlutter(() {
    menu('demo', () {
      item('hello', () {
        write('hello from the dev menu');
      });
    });
  });
}
```

### One import for models and utilities

```dart
import 'package:festenao_common_flutter/common_utils.dart';

class Note extends CvModelBase {
  final title = CvField<String>('title');

  @override
  CvFields get fields => [title];
}

void demo() {
  var note = Note()..title.v = 'Hello';
  print(note.toJson());
  print('web: $kDartIsWeb, count: ${parseInt('42')}');
}
```

## Common mistakes

* Building share links from `Uri.base` (the current screen url); use
  `appShareBaseUrl` / `appShareLink`.
* Importing `package:tekartik_common_utils/...` or `package:cv/...` next to
  the barrel: pick one, the barrel already exports them.
* Reading `festenaoFlavorContextDefault` and expecting `dev` on a release
  desktop or mobile build (it is `prod` there).
