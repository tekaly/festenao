# festenao_kiosk

A kiosk shell for a Flutter app: a hidden escape button that asks for a
numeric passcode (the [flutter_screen_lock](https://pub.dev/packages/flutter_screen_lock)
keypad), a settings screen to change that passcode, and the passcode kept in
the app preferences (`tekartik_prefs_sdb`). It brings no router and no state
management: it works with `Navigator`, `MaterialApp.routes` or go_router.

Flutter only, on [`material_ui`](https://pub.dev/packages/material_ui). Every
platform: the passcode is stored with SQLite (ffi) on Android, iOS, macOS,
Linux and Windows, in IndexedDB on the web (through
`tekartik_app_flutter_idb`).

It does not keep the app in front by itself: on Android, pair it with
[tekartik_kiosk](https://github.com/tekartikprj/android_tools/tree/main/packages/kiosk)
(lock task, watchdog) or a full screen mode.

## Getting started

Not on pub.dev, add it as a git dependency, with `material_ui`:

```yaml
dependencies:
  material_ui: ">=1.5.0"
  festenao_kiosk:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_kiosk
```

Wrap the whole app, above the `MaterialApp`, then put the escape button in a
corner of the kiosk screen:

```dart
import 'package:festenao_kiosk/festenao_kiosk.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(
    const FestenaoKioskApp(
      // Used until the operator sets one in the settings screen.
      defaultPasscode: '2468',
      child: MaterialApp(home: KioskScreen()),
    ),
  );
}

class KioskScreen extends StatelessWidget {
  const KioskScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Center(child: Text('Welcome')),
        Positioned(
          right: 0,
          bottom: 0,
          // A nearly invisible dot: the passcode keypad, then the settings.
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

A complete app is in [example/main.dart](example/main.dart).

## What to use

| API | What it does |
|---|---|
| `FestenaoKioskApp(child:, sdbFactory:, prefsName:, defaultPasscode:, passcodeLength:)` | Wraps the app, opens the prefs, gives the controller to every route. |
| `FestenaoKioskApp.of(context)` | The `FestenaoKioskController`. |
| `controller.checkPasscode(context)` | Shows the keypad; `true` once the right code is entered, `false` on cancel. |
| `controller.goToSettings(context)` | Pushes `FestenaoKioskSettingsScreen`. |
| `controller.passcode` / `setPasscode(value)` / `ready` | The code in effect, saving one, the prefs being open. |
| `FestenaoKioskEscapeButton(onUnlocked:)` | A small button that runs `onUnlocked` after `checkPasscode`. |
| `FestenaoKioskSettingsScreen`, `festenaoKioskSettingsRoute`, `festenaoKioskRoutes` | The settings screen, its path (`/kiosk-settings`) and a route map for `MaterialApp.routes`. |
| `kioskSanitizePasscode(raw, length:)` | Digits only, truncated or right padded with `0`. |

## Good to know

- The settings screen is not protected by itself: open it after
  `checkPasscode` (as the escape button above does), not from a visible menu.
- It shows the code in effect and saves only exactly `passcodeLength` digits.
  `setPasscode` stores what it is given; the code compared is
  `kioskSanitizePasscode` of it (`'12'` would need `1200`).
- The passcode is stored in clear in the app preferences: it keeps visitors
  out, not someone with access to the device storage.
- Linux and Windows: by default the prefs use
  `getSdbFactory(packageName: 'festenao_kiosk')`, which moves the databases
  folder of the whole app there (one shared SQLite factory, see
  `tekartik_app_flutter_idb`). Pass the app's own factory:
  `FestenaoKioskApp(sdbFactory: getSdbFactory(packageName: 'my_app'), ...)`.
- `FestenaoKioskApp` reads its parameters once, on its first build.
- Tests: `sdbFactory: sdbFactoryMemory` (from
  `package:tekartik_app_flutter_idb/sdb.dart`), and
  `await tester.runAsync(() => controller.ready)` in a `testWidgets` before
  reading the passcode; or a bare `FestenaoKioskController(prefsFactory:
  newPrefsFactoryMemory())` in a `FestenaoKioskScope`.

Agent skill: [festenao-kiosk-shell](skills/festenao-kiosk-shell/SKILL.md).
