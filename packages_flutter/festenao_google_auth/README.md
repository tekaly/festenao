# festenao_google_auth

A Flutter package to configure Firebase UI for Google and email authentication in the Festenao project.

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  festenao_google_auth:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_google_auth
```

## Usage

Import the package:

```dart
import 'package:festenao_google_auth/festenao_google_auth.dart';
```

Initialize the providers at the start of your application:

```dart
await initFestenaoGoogleAuth(clientId: 'YOUR_GOOGLE_CLIENT_ID');
```
