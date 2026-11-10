---
name: festenao-google-auth-setup
description: >-
  Use when a Festenao Flutter app needs firebase email + Google sign in screens:
  calling initFestenaoGoogleAuth(clientId:) at startup (lazy: Google Sign-In
  starts at the first auth screen, GDPR), which Google client id per
  platform, or the re-exported tekartik firebase ui auth surface
  (firebaseUiAuthServiceFlutter, FirebaseUiAuthServiceFlutter.configureProviders,
  authFlutterScreen, authFlutterLoginScreen, authFlutterRegisterScreen,
  authFlutterLostPasswordScreen, authFlutterProfileScreen,
  authFlutterEmailVerificationScreen, FirebaseUiAuthOptions,
  firebaseUiAuthOptionsDefault, AuthScreenBloc) through
  package:festenao_google_auth/google_auth.dart.
---

# Google and email auth setup (festenao_google_auth)

`festenao_google_auth` is a thin glue package: it sets the native
`firebase_ui_auth` providers (email/password plus Google) for a Festenao app,
and re-exports the tekartik firebase ui auth screens so an app depends on
this one package for its sign in flow (plus the Flutter firebase app and
auth it runs on).

## Guidelines

* Dependency (not on pub.dev, git only), with the Flutter firebase app and
  auth the app creates:

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

* Single import: `package:festenao_google_auth/google_auth.dart` (the
  library is `google_auth.dart`, there is no `festenao_google_auth.dart`).
  Never import `package:festenao_google_auth/src/...`.
* Platforms: Android, iOS, macOS and the web (native Firebase Auth). Not
  Linux nor Windows: there use `FirebaseUiAuthServiceBasic`
  (`tekartik_firebase_ui_auth`) with a REST or local auth.
* The only symbol this package defines is
  `Future<void> initFestenaoGoogleAuth({required String clientId})`. Call it
  once at startup, before any auth screen is built. It calls
  `firebaseUiAuthServiceFlutter.configureProviders(googleAuthClientId:
  clientId)`: email/password and Google, for the default firebase app.
  Lazy: the providers are set by the first auth screen, so Google Sign-In
  does not start (nor set its `g_state` cookie on the web) before the user
  opens one, and the call may come before `Firebase.initializeApp`.
* The `clientId` goes to `GoogleSignIn` on every platform but Android (which
  reads `google-services.json`): the web OAuth client id on the web, the iOS
  client id on iOS and macOS (`xxxx.apps.googleusercontent.com`). Keep them
  in the app's flavor config, picked by platform, not hard coded in the
  widget tree.
* Everything else the library exposes comes from the re-export of
  `package:tekartik_firebase_flutter_ui_auth/ui_auth.dart`:
  * `authFlutterScreen()`: the shared tekartik account screen (welcome, sign
    in / create account buttons, account details) that opens the native
    screens. The native screens alone: `authFlutterLoginScreen()`,
    `authFlutterRegisterScreen()`, `authFlutterLostPasswordScreen()`,
    `authFlutterProfileScreen()`, `authFlutterEmailVerificationScreen()`.
    Each function wraps its widget (`AuthFlutterScreen`,
    `AuthFlutterLoginScreen`, ...) in the `AuthScreenBloc` provider, so use
    the function, not the raw widget class, when you build a route. Each is
    a full screen (its own scaffold): push it as a route.
  * `FirebaseUiAuthServiceFlutter` and its const instance
    `firebaseUiAuthServiceFlutter`, with `authScreen()`, `loginScreen()`,
    `registerScreen()`, `lostPasswordScreen({email})`, `profileScreen()`,
    `emailVerificationScreen()` and `configureProviders(...)`.
  * `FirebaseUiAuthOptions(registerEnabled:, lostPasswordEnabled:)`,
    `firebaseUiAuthOptionsDefault`, `AuthScreenBloc`, `AuthScreenBlocState`.
* Every screen function takes an optional `firebaseAuth:` (a tekartik
  `FirebaseAuth` of `tekartik_firebase_auth_flutter`); omitted, the default
  instance is used, which exists once the app created it
  (`firebaseAuthServiceFlutter.auth(app)`). Passing it is clearer.
* One provider list, applied by the first auth screen: the last
  `initFestenaoGoogleAuth` / `configureProviders` call made before it wins.
  For Google only, call `firebaseUiAuthServiceFlutter.configureProviders(
  googleAuthClientId: ..., noEmailPassword: true)` at startup instead of
  `initFestenaoGoogleAuth`.
* To hide the sign up entry point, build the login screen with
  `FirebaseUiAuthOptions(registerEnabled: false)`, or a
  `FirebaseUiAuthServiceFlutter(options: ...)` of your own; the const
  `firebaseUiAuthServiceFlutter` always uses `firebaseUiAuthOptionsDefault`.
  `lostPasswordEnabled: false` is honoured by the basic screens only: the
  native `firebase_ui_auth` sign in screen always shows its "Forgot
  password?" button.
* Localization: English by default; for other languages add
  `FirebaseUiAuthServiceBasicLocalizations.delegate`
  (`tekartik_firebase_ui_auth`) and `FirebaseUILocalizations.delegate`
  (`firebase_ui_localizations`) to the `MaterialApp`.
* Web, GDPR: `google_sign_in_web` loads Google's script at startup (no
  cookie, but the request reaches Google): list it in the privacy policy.
* Anti-patterns: setting the providers from `build()` (once, at startup),
  depending on `firebase_ui_auth` / `firebase_ui_oauth_google` directly in
  the app to configure providers, building `firebase_ui_auth` screens
  (`SignInScreen`...) directly (the lazy providers are never set), pushing
  `AuthFlutterLoginScreen` directly (no bloc above it, it throws), importing
  `package:flutter/material.dart` in new code (Flutter beta deprecates it:
  use `package:material_ui/material_ui.dart`).
* Tests: without a firebase app, `initFestenaoGoogleAuth` returns and sets
  nothing; the first auth screen then throws "You must call
  Firebase.initializeApp()". Test the app's routes with a fake or memory
  `FirebaseAuth` and `FirebaseUiAuthServiceBasic`.

## Examples

### Startup: create the auth, set the providers, open the account screen

```dart
import 'package:festenao_google_auth/google_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_firebase_auth_flutter/auth_flutter.dart';
import 'package:tekartik_firebase_flutter/firebase_flutter.dart';

/// Google OAuth client id of the running platform (from the flavor config).
const googleClientId = '000000000000-xxxxxxxx.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var app = await firebaseFlutter.initializeAppAsync();
  var auth = firebaseAuthServiceFlutter.auth(app);
  await initFestenaoGoogleAuth(clientId: googleClientId);
  runApp(MyApp(auth: auth));
}

class MyApp extends StatelessWidget {
  final FirebaseAuth auth;

  const MyApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Festenao',
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Festenao')),
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => authFlutterScreen(firebaseAuth: auth),
              ),
            ),
            child: const Text('Account'),
          ),
        ),
      ),
    ),
  );
}
```

### Auth routes (login, register, lost password, profile)

```dart
import 'package:festenao_google_auth/google_auth.dart';
import 'package:material_ui/material_ui.dart';

/// Routes of the auth flow, each built through the bloc wrapping helpers.
Map<String, WidgetBuilder> authRoutes() => {
  '/account': (_) => authFlutterScreen(),
  '/login': (_) => authFlutterLoginScreen(),
  '/register': (_) => authFlutterRegisterScreen(),
  '/lost-password': (_) => authFlutterLostPasswordScreen(),
  '/verify-email': (_) => authFlutterEmailVerificationScreen(),
  '/profile': (_) => authFlutterProfileScreen(),
};
```

### Login only: no sign up

```dart
import 'package:festenao_google_auth/google_auth.dart';
import 'package:material_ui/material_ui.dart';

/// A login screen without the register switch (accounts made elsewhere).
Widget signInOnlyScreen() => authFlutterLoginScreen(
  options: const FirebaseUiAuthOptions(registerEnabled: false),
);
```

### Google only (no email/password), set at startup

```dart
import 'package:festenao_google_auth/google_auth.dart';

const googleClientId = '000000000000-xxxxxxxx.apps.googleusercontent.com';

/// Instead of [initFestenaoGoogleAuth], once at startup.
void configureGoogleOnlyAuth() {
  firebaseUiAuthServiceFlutter.configureProviders(
    googleAuthClientId: googleClientId,
    noEmailPassword: true,
  );
}
```
