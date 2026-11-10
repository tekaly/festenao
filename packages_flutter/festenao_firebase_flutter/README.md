# festenao_firebase_flutter

The Flutter (FlutterFire) Firebase packages of a festenao app, in one
dependency. It has no library of its own: it brings

| Package | Import | What |
|---|---|---|
| `tekartik_firebase_flutter` | `firebase_flutter.dart` | the `FirebaseApp` (`firebaseFlutter`) |
| `tekartik_firebase_auth_flutter` | `auth_flutter.dart` | Auth (`firebaseAuthServiceFlutter`) |
| `tekartik_firebase_firestore_flutter` | `firestore_flutter.dart` | Firestore (`firestoreServiceFlutter`) |
| `tekartik_firebase_storage_flutter` | `storage_flutter.dart` | Storage (`storageServiceFlutter`) |
| `tekartik_firebase_flutter_ui_auth` | `ui_auth.dart` | the native sign in screens (`firebaseUiAuthServiceFlutter`) |
| `tekaly_assets` | - | the common assets (logo, fonts) |

No REST nor functions package: add `tekartik_firebase_rest` or
`tekartik_firebase_functions_call_flutter` yourself when needed.

## Getting started

Not on pub.dev. Add the bundle, and also list each package the app imports
(the `depend_on_referenced_packages` lint wants them in the app pubspec):

```yaml
dependencies:
  festenao_firebase_flutter:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_firebase_flutter
  tekartik_firebase_flutter:
    git:
      url: https://github.com/tekartik/firebase_flutter
      path: firebase_flutter
  tekartik_firebase_firestore_flutter:
    git:
      url: https://github.com/tekartik/firebase_flutter
      path: firestore_flutter
```

Configure the native project first (`flutterfire configure`), then create
the app once, before `runApp`, and the products from it:

```dart
import 'package:flutter/widgets.dart';
import 'package:tekartik_firebase_firestore_flutter/firestore_flutter.dart';
import 'package:tekartik_firebase_flutter/firebase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var app = await firebaseFlutter.initializeAppAsync();
  var firestore = firestoreServiceFlutter.firestore(app);
  var snapshot = await firestore.doc('public/hello').get();
  runApp(
    Center(
      child: Text(
        'public/hello exists: ${snapshot.exists}',
        textDirection: TextDirection.ltr,
      ),
    ),
  );
}
```

[example/main.dart](example/main.dart) creates every product of the bundle
(firestore, storage, auth and the sign in screens).

## Platforms

The FlutterFire platforms: Android, iOS, macOS and the web (and the other
platforms your FlutterFire plugin versions support). The native Auth and its
sign in screens: Android, iOS, macOS and the web only; on Linux and Windows
use a REST or local auth (`FirebaseUiAuthServiceBasic` for the screens).

See the README and skills of each bundled package (the
[firebase_flutter](https://github.com/tekartik/firebase_flutter) repository,
[tekartik_firebase_flutter_ui_auth](https://github.com/tekartik/firebase_ui.dart/tree/main/packages/firebase_flutter_ui_auth))
for the options, the emulators and the pitfalls; `festenao_google_auth` adds
Google sign in to the screens.
