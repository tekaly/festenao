---
name: festenao-screenshot
description: >-
  Use when writing or running a screenshot harness of a Flutter app with
  festenao_screenshot (flutter test, no display): runScreenshots,
  ScreenshotSession (open, setSize, settle, waitFor, tap, tapText,
  tapTooltip, back, shot with prefix and numbering, shotNamed, only,
  wantsNext, skip, resetIndex, wrap, errors), loadScreenshotFonts,
  patchFontFallbacks, screenshotNames, screenshotPackageRoot, and why text
  draws as boxes or shadows as black outlines in a widget test.
---

# Screenshots in flutter test (festenao_screenshot)

`festenao_screenshot` renders the screens of an app as pngs through the
flutter test pipeline: the real widgets, router and in memory backends, no
display. A harness is a `tool/screenshot_test.dart` run with `flutter test`.

## Guidelines

* Dependency (git, not on pub.dev), as a dev dependency next to
  `flutter_test`:
  ```yaml
  dev_dependencies:
    festenao_screenshot:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_screenshot
  ```
  One import: `package:festenao_screenshot/festenao_screenshot.dart`.
* `runScreenshots(description, body, directory:)` declares the widget test:
  it runs `body` inside `tester.runAsync` (databases, streams and timers on
  real time, frames pumped by hand), loads the fonts, draws the shadows
  (the test binding outlines elevated widgets in black otherwise), hides the
  debug banner, removes the previous pngs of `directory` (and `clear`)
  unless `only` filters or `clearPngs` is false, and lists the errors the
  screens reported at the end. `createSession` plugs in a subclass.
* Sizes: `session.open(widget, size:)` or `session.setSize(size)` set the
  window in logical pixels; the pngs are `pixelRatio` (2) times larger and
  the screens see `devicePixelRatio` (1 by default; 2 to match the pngs).
* An app pumped by the harness itself (to keep its router or container) is
  wrapped with `session.wrap(app)`: the shots capture that boundary.
* `session.settle()` alternates 50 ms pumps and 10 ms real delays,
  `settleRounds` times (20 by default): raise it for slow backends.
  `waitFor(finder)` settles until something is found.
* `back()` taps the material_ui `BackButton` of the app bar, whatever its
  tooltip language; without one it falls back to the navigator, which only
  finds an English "Back" tooltip.
* Files: `shot(name, prefix: 'phone')` writes `phone_NN_<name>.png`, NN
  counted per directory and prefix (`resetIndex` restarts it, `skip`
  counts one without writing); `shotNamed('phone_05b_variant')` writes the
  name as given. `directory:` writes elsewhere (a user management folder).
* Filter: `only: screenshotNames(const String.fromEnvironment('X_ONLY'))`
  keeps the shots whose name, file name or `<prefix>_<name>` is listed; test
  `session.wantsNext(name, prefix:)` before navigating, `skip` otherwise to
  keep the numbering.
* Fonts: `loadScreenshotFonts` loads the app `FontManifest.json`, Roboto
  and the material icons from the flutter sdk, the cupertino icons and the
  festenao_theme families when the app depends on them (bare and package
  names, JetBrains Mono also as `monospace`), DejaVu Sans when installed.
  `patchFontFallbacks` (done before each shot) gives family-less text Roboto
  and the DejaVu fallback: in a test such text draws as boxes.

## Examples

### A phone harness on a router, with a filter

```dart
import 'dart:io';

import 'package:festenao_screenshot/festenao_screenshot.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

const _only = String.fromEnvironment('APP_SCREENSHOT_ONLY');

Future<void> _shotAt(
  ScreenshotSession session,
  GoRouter router,
  String name,
  String location,
) async {
  if (!session.wantsNext(name, prefix: 'phone')) {
    session.skip(prefix: 'phone');
    return;
  }
  router.go(location);
  await session.shot(name, prefix: 'phone');
}

void main() {
  runScreenshots(
    'screenshots',
    (session) async {
      var router = GoRouter(routes: [/* ... */]);
      await session.setSize(const Size(400, 860));
      await session.tester.pumpWidget(
        session.wrap(MaterialApp.router(routerConfig: router)),
      );
      await session.settle();
      for (var (name, location) in [('home', '/'), ('about', '/about')]) {
        await _shotAt(session, router, name, location);
      }
    },
    directory: Directory('.local/screenshots'),
    only: screenshotNames(_only),
    devicePixelRatio: 2,
  );
}
```

### A session of a repository layout

```dart
import 'dart:io';

import 'package:festenao_screenshot/festenao_screenshot.dart';
import 'package:flutter_test/flutter_test.dart';

class RepoSession extends ScreenshotSession {
  final Directory userDirectory;

  RepoSession(WidgetTester tester, String root, String app)
    : userDirectory = Directory('$root/user_management/$app'),
      super(tester, directory: Directory('$root/$app'));

  /// The user management screens, in their own folder.
  Future<File?> userShot(String name) => shot(name, directory: userDirectory);
}
```

## Common mistakes

* Text as boxes: a font not loaded (the app family not declared and not in
  festenao_theme), or text with no family (a bare `TextStyle`) shot without
  `patchFontFallbacks`.
* A hang: awaiting a backend outside `runAsync`, or `pumpAndSettle` on a
  screen with an endless animation; use `settle`.
* Shots of a filtered run renumbered: navigate only when `wantsNext`, and
  `skip` otherwise.
