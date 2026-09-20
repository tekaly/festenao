---
name: festenao-kiosk-shell
description: >-
  Use when a Flutter app runs in kiosk mode and needs a passcode protected way
  out plus a persisted operator setting: FestenaoKioskApp (sdbFactory,
  prefsName, defaultPasscode, passcodeLength), FestenaoKioskApp.of(context),
  FestenaoKioskController (ready, passcode, passcodeOrNull, setPasscode,
  goToSettings, checkPasscode), FestenaoKioskEscapeButton,
  FestenaoKioskSettingsScreen, FestenaoKioskScope, festenaoKioskSettingsRoute,
  festenaoKioskRoutes and kioskSanitizePasscode from
  package:festenao_kiosk/festenao_kiosk.dart.
---

# Kiosk shell (festenao_kiosk)

`festenao_kiosk` is a router-agnostic kiosk shell: it wraps the app in an
inherited scope carrying a passcode (persisted with `tekartik_prefs_sdb`), a
settings screen to change it, and a discreet escape button that runs a callback
only after the passcode has been entered on the `flutter_screen_lock` keypad.
It pulls in neither go_router nor riverpod.

## Guidelines

* Dependency (not on pub.dev, git only):

  ```yaml
  dependencies:
    festenao_kiosk:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_kiosk
  ```

* Single import: `package:festenao_kiosk/festenao_kiosk.dart` (it exports
  everything). Never import `package:festenao_kiosk/src/...`.
* Wrap the whole app once, **above** the `MaterialApp` / `MaterialApp.router`:
  `FestenaoKioskApp(child: ...)`. Optional parameters: `sdbFactory` (defaults
  to `getSdbFactory(packageName: 'festenao_kiosk')`, i.e. sqflite on
  mobile/desktop, IndexedDB on web), `prefsName` (default `'festenao_kiosk'`),
  `defaultPasscode` (default `'0000'`), `passcodeLength` (default `4`).
* Read the controller with `FestenaoKioskApp.of(context)` from any descendant.
  It asserts when no `FestenaoKioskApp` is above. `FestenaoKioskScope` is the
  raw `InheritedWidget` behind it — do not use it directly.
* `FestenaoKioskController`:
  * `ready` is a lazy `Future<void>` that opens the prefs; `await` it before
    trusting `passcodeOrNull` or calling `setPasscode`. Getters are safe to
    call earlier, they just return the defaults.
  * `passcodeOrNull` is the raw stored string (null until one is saved);
    `passcode` is the sanitized value actually compared against, always
    `passcodeLength` digits.
  * `setPasscode(value)` awaits `ready`, stores the **raw** string and saves;
    sanitizing happens on read, so `'12ab34'` is stored as is and matched as
    `'1234'`.
  * `goToSettings(context)` pushes a `MaterialPageRoute` with
    `FestenaoKioskSettingsScreen` — it uses `Navigator`, so it works under any
    router as long as a `Navigator` is in scope.
  * `checkPasscode(context)` shows the `flutter_screen_lock` keypad and
    resolves to `true` only when the right code was entered (`false` on cancel
    or on an unmounted context). Always `await` it and re-check
    `context.mounted` before navigating.
* `kioskSanitizePasscode(raw, {int length = 4})` is the pure function behind
  `passcode`: it drops non-digits, truncates to `length`, and right-pads with
  `'0'` (`'7'` -> `'7000'`, `''` -> `'0000'`, `'123456'` -> `'1234'`). Use it
  when validating operator input yourself.
* `FestenaoKioskEscapeButton({required VoidCallback onUnlocked, Widget? child})`
  is the ready-made hatch: a nearly invisible dot `IconButton` by default that
  calls `onUnlocked` only after `checkPasscode` succeeded. Put it in a screen
  corner (a `Stack` / `Positioned`), pass `child:` to change the glyph.
* Routing: `festenaoKioskSettingsRoute` is the plain path constant
  (`'/kiosk-settings'`) and `festenaoKioskRoutes` is a
  `Map<String, WidgetBuilder>` ready for `MaterialApp(routes: ...)`. With
  go_router, reuse the constant as a `GoRoute(path: ...)` and build
  `const FestenaoKioskSettingsScreen()` yourself — the package deliberately
  has no router dependency.
* Anti-patterns: calling `FestenaoKioskApp.of(context)` from `initState`
  (inherited widget lookup — do it in `didChangeDependencies` or `build`);
  building a `FestenaoKioskController` by hand in app code (only tests do,
  with an explicit `prefsFactory`); putting `FestenaoKioskApp` below the
  `MaterialApp`, which loses the scope for pushed routes.
* Tests: pass `sdbFactory: sdbFactoryMemory` (from
  `package:tekartik_app_flutter_idb/sdb.dart`) to keep everything in memory,
  and use a unique `prefsName` per test. In `testWidgets`, the sdb open does
  real async work that fake-async cannot advance: run
  `await tester.runAsync(() => controller.ready)` before asserting on the
  passcode. Unit-test a bare `FestenaoKioskController(prefsFactory:
  getPrefsFactorySdb(sdbFactoryMemory), prefsName: ...)` without any widget.

## Examples

### Wrapping the app and escaping kiosk mode

```dart
import 'package:festenao_kiosk/festenao_kiosk.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    const FestenaoKioskApp(
      // sdbFactory defaults to the platform sdb factory.
      passcodeLength: 6,
      child: MaterialApp(home: KioskHomeScreen()),
    ),
  );
}

/// The full screen kiosk content, with a discreet escape button.
class KioskHomeScreen extends StatelessWidget {
  /// Constructor.
  const KioskHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Center(child: Text('Kiosk content')),
        Positioned(
          right: 0,
          bottom: 0,
          child: FestenaoKioskEscapeButton(
            onUnlocked: () =>
                FestenaoKioskApp.of(context).goToSettings(context),
          ),
        ),
      ],
    ),
  );
}
```

### Guarding an action with the passcode

```dart
import 'package:festenao_kiosk/festenao_kiosk.dart';
import 'package:flutter/material.dart';

/// A long press that only exits the current screen once unlocked.
class ExitKioskArea extends StatelessWidget {
  /// Constructor.
  const ExitKioskArea({super.key});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: () async {
      var kiosk = FestenaoKioskApp.of(context);
      var unlocked = await kiosk.checkPasscode(context);
      if (unlocked && context.mounted) {
        Navigator.of(context).pop();
      }
    },
    child: const SizedBox(width: 64, height: 64),
  );
}
```

### Settings route: MaterialApp routes, or go_router

```dart
import 'package:festenao_kiosk/festenao_kiosk.dart';
import 'package:flutter/material.dart';

/// Plain Navigator 1 route table, merged with the app's own routes.
Map<String, WidgetBuilder> appRoutes() => {
  ...festenaoKioskRoutes,
  '/': (_) => const Scaffold(body: Center(child: Text('home'))),
};

/// With go_router, reuse the path constant and build the screen:
/// `GoRoute(path: festenaoKioskSettingsRoute,
///   builder: (_, _) => const FestenaoKioskSettingsScreen())`.
const settingsPath = festenaoKioskSettingsRoute;
```

### Unit test against in-memory storage

```dart
import 'package:festenao_kiosk/festenao_kiosk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_app_flutter_idb/sdb.dart';
import 'package:tekartik_prefs_sdb/prefs.dart';

void main() {
  test('passcode is sanitized on read', () async {
    var controller = FestenaoKioskController(
      prefsFactory: getPrefsFactorySdb(sdbFactoryMemory),
      prefsName: 'kiosk_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    await controller.ready;
    expect(controller.passcodeOrNull, isNull);
    expect(controller.passcode, '0000');

    await controller.setPasscode('12ab34');
    expect(controller.passcodeOrNull, '12ab34');
    expect(controller.passcode, kioskSanitizePasscode('12ab34'));
  });
}
```
