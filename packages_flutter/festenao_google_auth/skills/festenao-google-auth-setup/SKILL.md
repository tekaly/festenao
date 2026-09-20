---
name: festenao-google-auth-setup
description: >-
  Use when a Festenao Flutter app needs firebase email + Google sign in screens:
  calling initFestenaoGoogleAuth(clientId:) at startup, or the re-exported
  tekartik firebase ui auth surface (firebaseUiAuthServiceFlutter,
  FirebaseUiAuthServiceFlutter.configureProviders, authFlutterScreen,
  authFlutterLoginScreen, authFlutterRegisterScreen,
  authFlutterLostPasswordScreen, authFlutterProfileScreen,
  authFlutterEmailVerificationScreen, FirebaseUiAuthOptions,
  firebaseUiAuthOptionsDefault, AuthScreenBloc) through
  package:festenao_google_auth/google_auth.dart.
---

# Google and email auth setup (festenao_google_auth)

`festenao_google_auth` is a thin glue package: it configures the native
`firebase_ui_auth` providers (email/password plus Google) for a Festenao app,
and re-exports the tekartik firebase ui auth widgets so an app only depends on
this one package for its whole sign in flow.

## Guidelines

* Dependency (not on pub.dev, git only):

  ```yaml
  dependencies:
    festenao_google_auth:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_google_auth
  ```

* Single import: `package:festenao_google_auth/google_auth.dart`. The library
  name is `google_auth.dart`, **not** `festenao_google_auth.dart` (the README
  is stale on that point). Never import `package:festenao_google_auth/src/...`.
* The only symbol this package defines is
  `Future<void> initFestenaoGoogleAuth({required String clientId})`. Call it
  once at startup, after the firebase app is initialized and before any auth
  screen is built. It calls `FirebaseUIAuth.configureProviders` with an
  `EmailAuthProvider()` and a `GoogleProvider(clientId: clientId)`, so both
  email/password and Google sign in are always enabled.
* The `clientId` is the **web** OAuth client id of the firebase project
  (`xxxx.apps.googleusercontent.com`). It is required by
  `firebase_ui_oauth_google` on every platform; keep it in the app's flavor
  config, not hard coded in the widget tree.
* Everything else the library exposes comes from the re-export of
  `package:tekartik_firebase_flutter_ui_auth/ui_auth.dart`:
  * screens as plain widget builders:
    `authFlutterScreen()` (login + register in one),
    `authFlutterLoginScreen()`, `authFlutterRegisterScreen()`,
    `authFlutterLostPasswordScreen()`, `authFlutterProfileScreen()`,
    `authFlutterEmailVerificationScreen()`. Each wraps its widget
    (`AuthFlutterScreen`, `AuthFlutterLoginScreen`, ...) in the
    `AuthScreenBloc` provider, so use the function, not the raw widget class,
    when you build a route.
  * `FirebaseUiAuthServiceFlutter` and its const instance
    `firebaseUiAuthServiceFlutter`, with `authScreen()`, `loginScreen()`,
    `registerScreen()`, `lostPasswordScreen({email})`, `profileScreen()`,
    `emailVerificationScreen()` and `configureProviders(...)`.
  * `FirebaseUiAuthOptions(registerEnabled:, lostPasswordEnabled:)`,
    `firebaseUiAuthOptionsDefault`, `AuthScreenBloc`, `AuthScreenBlocState`.
* Every screen function takes an optional `firebaseAuth:` (a tekartik
  `FirebaseAuth`); omit it to use the app's default instance. Do not add a
  direct dependency on `tekartik_firebase_auth` just to name that type — let
  it be inferred, or pass the value through.
* Alternative to `initFestenaoGoogleAuth` when the app must turn a provider
  off: `firebaseUiAuthServiceFlutter.configureProviders(googleAuthClientId:
  ..., noEmailPassword: true)`. Use one or the other, not both — the second
  call replaces the provider list.
* To hide the sign up or the forgot password entry point, build the login
  screen with `FirebaseUiAuthOptions`, or a
  `FirebaseUiAuthServiceFlutter(options: ...)` of your own; the const
  `firebaseUiAuthServiceFlutter` always uses
  `firebaseUiAuthOptionsDefault` (both enabled).
* Anti-patterns: calling `initFestenaoGoogleAuth` from `build()` (it must run
  once, at startup), depending on `firebase_ui_auth` / `firebase_ui_oauth_google`
  directly in the app just to configure providers, and pushing
  `AuthFlutterLoginScreen` directly (no bloc above it, it will throw).
* The package ships no widget test worth copying (`test/` holds a placeholder);
  test the app's routes instead, with a fake/memory `FirebaseAuth`.

## Examples

### Startup: configure the providers, then show the auth screen

```dart
import 'package:festenao_google_auth/google_auth.dart';
import 'package:flutter/material.dart';

/// Web OAuth client id of the firebase project (from the app flavor config).
const googleClientId = '000000000000-xxxxxxxx.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ... initialize the firebase app first, then:
  await initFestenaoGoogleAuth(clientId: googleClientId);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Festenao',
    home: Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: authFlutterScreen(),
    ),
  );
}
```

### Auth routes (login, register, lost password, profile)

```dart
import 'package:festenao_google_auth/google_auth.dart';
import 'package:flutter/material.dart';

/// Routes of the auth flow, each built through the bloc wrapping helpers.
Map<String, WidgetBuilder> authRoutes() => {
  '/login': (_) => Scaffold(body: authFlutterLoginScreen()),
  '/register': (_) => Scaffold(body: authFlutterRegisterScreen()),
  '/lost-password': (_) => Scaffold(body: authFlutterLostPasswordScreen()),
  '/verify-email': (_) => Scaffold(body: authFlutterEmailVerificationScreen()),
  '/profile': (_) => Scaffold(body: authFlutterProfileScreen()),
};
```

### Login only: no sign up, no forgot password

```dart
import 'package:festenao_google_auth/google_auth.dart';
import 'package:flutter/material.dart';

/// A locked down login screen: google + email/password, nothing else.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: authFlutterLoginScreen(
      options: const FirebaseUiAuthOptions(
        registerEnabled: false,
        lostPasswordEnabled: false,
      ),
    ),
  );
}
```

### Google only (no email/password), through the service

```dart
import 'package:festenao_google_auth/google_auth.dart';
import 'package:flutter/material.dart';

const googleClientId = '000000000000-xxxxxxxx.apps.googleusercontent.com';

/// Instead of [initFestenaoGoogleAuth], configure the providers by hand.
Widget buildGoogleOnlyAuth() {
  const service = FirebaseUiAuthServiceFlutter(
    options: FirebaseUiAuthOptions(registerEnabled: false),
  );
  service.configureProviders(
    googleAuthClientId: googleClientId,
    noEmailPassword: true,
  );
  return service.authScreen();
}
```
