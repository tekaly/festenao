# festenao_google_auth

Email/password and Google sign in for a festenao Flutter app, on the native
Firebase UI screens (`firebase_ui_auth`, `firebase_ui_oauth_google`):

- `initFestenaoGoogleAuth(clientId:)` sets the two providers;
- `package:festenao_google_auth/google_auth.dart` re-exports the screens of
  [tekartik_firebase_flutter_ui_auth](https://github.com/tekartik/firebase_ui.dart/tree/main/packages/firebase_flutter_ui_auth)
  (`authFlutterScreen`, `firebaseUiAuthServiceFlutter`, ...).

## Getting started

Not on pub.dev, add the git dependency, with the Flutter firebase app and
auth the screens run on:

```yaml
dependencies:
  festenao_google_auth:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_google_auth
  tekartik_firebase_flutter:
    git:
      url: https://github.com/tekartik/firebase_flutter
      path: firebase_flutter
  tekartik_firebase_auth_flutter:
    git:
      url: https://github.com/tekartik/firebase_flutter
      path: auth_flutter
  material_ui: ">=1.5.0"
```

```dart
import 'package:festenao_google_auth/google_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_firebase_auth_flutter/auth_flutter.dart';
import 'package:tekartik_firebase_flutter/firebase_flutter.dart';

/// The Google OAuth client id of the running platform (here the web one).
const googleClientId = '000000000000-xxxxxxxx.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The native configuration of the project (flutterfire configure).
  var app = await firebaseFlutter.initializeAppAsync();
  var auth = firebaseAuthServiceFlutter.auth(app);
  // Nothing starts here: the first auth screen sets the providers.
  await initFestenaoGoogleAuth(clientId: googleClientId);
  runApp(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  // Welcome, sign in / create account, account details.
                  builder: (_) => authFlutterScreen(firebaseAuth: auth),
                ),
              ),
              child: const Text('Account'),
            ),
          ),
        ),
      ),
    ),
  );
}
```

The same app is in [example/main.dart](example/main.dart).

## Platforms

The native Firebase Auth platforms: Android, iOS, macOS and the web. Not
Linux nor Windows: there, use `FirebaseUiAuthServiceBasic`
(`tekartik_firebase_ui_auth`) with a REST or local auth.

## What to know

- `initFestenaoGoogleAuth` is lazy, as
  `firebaseUiAuthServiceFlutter.configureProviders` that it calls: the
  providers are set by the first auth screen, so Google Sign-In does not
  start (nor set its `g_state` cookie on the web) before the user opens one.
  Build the screens through the package (`authFlutterScreen`,
  `firebaseUiAuthServiceFlutter.loginScreen()`, ...), never the
  `firebase_ui_auth` screens directly.
- `clientId` goes to Google Sign-In on every platform but Android (which
  reads `google-services.json`): pass the web client id on the web, the iOS
  client id on iOS and macOS.
- One provider list: the last `initFestenaoGoogleAuth` /
  `configureProviders` call made before the first auth screen wins. For
  Google only, call `firebaseUiAuthServiceFlutter.configureProviders(
  googleAuthClientId: ..., noEmailPassword: true)` instead.
- The screens use the default `FirebaseAuth` when none is given: create it
  first (`firebaseAuthServiceFlutter.auth(app)`), or pass it.
- English by default; for other languages add
  `FirebaseUiAuthServiceBasicLocalizations.delegate`
  (`tekartik_firebase_ui_auth`) and `FirebaseUILocalizations.delegate`
  (`firebase_ui_localizations`) to the `MaterialApp`.
- Web: `google_sign_in_web` loads Google's script at startup (no cookie):
  list it in the privacy policy of the app.

Package skill (for AI coding agents, `skills/`): `festenao-google-auth-setup`.
Install it in an app depending on it with:

```bash
dart run skills@ get -p festenao_google_auth
```
