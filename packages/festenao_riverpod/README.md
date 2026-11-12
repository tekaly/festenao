# festenao_riverpod

Dart only riverpod providers shared by the Festenao apps: the platform
services (file system, sdb factory), the app flavor, the firebase services,
the per user projects database, and the project commands of an app with no
backend. The app overrides the providers without a default once, at its
root; everything below reads the services from the providers instead of the
`Xxx.instance` globals. A Flutter app adds `festenao_riverpod_flutter`
(`festenaoFlutterProviderOverrides`, the platform defaults).

## Getting started

Not on pub.dev, a git dependency (with `riverpod`, or `flutter_riverpod` in a
Flutter app for its `ProviderScope`):

```yaml
dependencies:
  festenao_riverpod:
    git:
      url: https://github.com/tekaly/festenao
      path: packages/festenao_riverpod
```

The smallest container: a flavor, a memory file system and sdb factory,
then a provider read (`example/main.dart` runs it):

```dart
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:idb_shim/sdb.dart';
import 'package:riverpod/riverpod.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

void main() {
  var container = ProviderContainer(
    overrides: [
      festenaoAppFlavorContextProvider.overrideWithValue(
        FestenaoAppFlavorContext(
          packageName: 'com.example.myapp',
          appFlavorContext: AppFlavorContext.testLocal,
        ),
      ),
      festenaoFileSystemProvider.overrideWithValue(newFileSystemMemory()),
      festenaoSdbFactoryProvider.overrideWithValue(newSdbFactoryMemory()),
    ],
  );
  // ignore: avoid_print
  print(container.read(festenaoAppFlavorContextProvider).appId);
  container.dispose();
}
```

## The providers

| Provider | Default |
| --- | --- |
| `festenaoFileSystemProvider` | `fileSystemDefault` (io or web) |
| `festenaoSdbFactoryProvider` | `sdbFactoryWeb` on the web, `sdbFactorySqflite` elsewhere, sandboxed under the flavor's unique app name |
| `festenaoAppFlavorContextProvider` | none: override it |
| `festenaoFirebaseAppProvider` | `FirebaseApp.instance` |
| `festenaoFirebaseContextProvider` (auth, firestore) | none: override it with `festenaoFirebaseContextOverrides(context)`, which binds the app provider too |
| `festenaoFirebaseAuthProvider`, `festenaoFirestoreProvider`, `festenaoFirebaseUserProvider`, `festenaoFirebaseUserIdProvider`, `festenaoFbIdentityProvider` | derived from the context |
| `festenaoUserProjectsSdbManagerProvider` | none: override it with `festenaoUserProjectsSdbManagerOverride(factory:, app:)` |
| `festenaoUserProjectsSdbProvider` | the manager's current per user database |

The projects of an app with **no backend** (firestore rules only, see
`festenao_dartff/festenao_firebase_no_api_context.dart`):
`festenaoProjectsFsProvider`, `festenaoProjectsBootstrapProvider`,
`festenaoUserProjectsProvider`, `festenaoUserProjectProvider(id)`,
`festenaoProjectPublicAccessProvider(id)`, and the commands of
`festenaoNoApiProjectsProvider` (`createProject`, `renameProject`,
`setUserAccess`, `setPublicAccess`, `deleteProject`, `refresh`).

## What to know

- Reading a provider without a default and without its override throws a
  `ProviderException` wrapping an `UnimplementedError`.
- `festenaoSdbFactoryProvider` defaults to sqflite outside the web: right
  for Flutter mobile, but a Dart VM program or a desktop app without the ffi
  setup must override it (`sdbFactoryIo` of `idb_shim/sdb.dart`, or
  `sdbFactoryFromSqflite(databaseFactoryFfi)` of `idb_sqflite`).
- The generated providers (`@riverpod`) are auto dispose: the projects
  manager is closed when nothing listens to it any more, and a new one is
  opened on the next read. Watch it (or `container.listen`) for as long as
  the app needs it.
- With admin credentials (the admin sdk) the auth never has a current user:
  `festenaoFirebaseUserProvider` stays loading, use
  `festenaoFbIdentityProvider` (the service account identity).
- The `.g.dart` files are committed: after editing an `@riverpod` function
  run `dart run build_runner build` in the package.

The package skills (`skills/festenao-riverpod-providers`,
`skills/festenao-riverpod-no-api-projects`) have the full setup, tests on
memory backends and the no backend project flow.
