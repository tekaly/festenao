# festenao_kiosk

Reusable kiosk-mode shell, extracted from the UI pattern in
`android_tools/packages/web_kiosk_app`: a settings screen for a
configurable passcode, a passcode-protected "escape" hatch, and
router-agnostic screens — no go_router or riverpod dependency.

## Usage

```dart
import 'package:festenao_kiosk/festenao_kiosk.dart';

void main() {
  runApp(
    FestenaoKioskApp(
      // sdbFactory defaults to the platform sdb factory.
      child: MaterialApp.router(routerConfig: myRouter),
    ),
  );
}
```

Anywhere below, get the controller and use its helpers:

```dart
var kiosk = FestenaoKioskApp.of(context);
await kiosk.goToSettings(context);
var unlocked = await kiosk.checkPasscode(context);
```

Or drop in the ready-made escape button:

```dart
FestenaoKioskEscapeButton(
  onUnlocked: () => Navigator.of(context).pop(),
)
```

To wire the settings screen into your own router, use
`festenaoKioskSettingsRoute` (a plain path string) or
`festenaoKioskRoutes` (a `Map<String, WidgetBuilder>` for
`MaterialApp.routes`) — both work with go_router just as well as with
`Navigator`.
