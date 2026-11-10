# `festenao_google_auth` Package

## Purpose

This package provides a simple and reusable way to configure Firebase Authentication with email and Google providers for Flutter applications in the "festenao" project.

## Implementation Details

The package contains a single function, `initFestenaoGoogleAuth`, which sets the Firebase UI providers for email and Google sign-in through `firebaseUiAuthServiceFlutter.configureProviders` (lazy: applied by the first auth screen), and re-exports `package:tekartik_firebase_flutter_ui_auth/ui_auth.dart`.

## File Layout

-   `lib/google_auth.dart`: The public library (the function and the re-export).
-   `lib/src/festenao_google_auth.dart`: `initFestenaoGoogleAuth`.
-   `example/main.dart`: A minimal app (firebase app, auth, account screen).
-   `skills/festenao-google-auth-setup/SKILL.md`: The agent skill.
-   `pubspec.yaml`: Defines the package's dependencies and metadata.
-   `README.md`: Provides documentation for the package.
-   `DESIGN.md`: The design document for the package.
-   `IMPLEMENTATION.md`: The implementation plan for the package (history).
