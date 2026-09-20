---
name: festenao-riverpod-providers
description: >-
  Use when wiring the shared riverpod providers of a festenao app (dart or
  flutter) with festenao_riverpod: festenaoFileSystemProvider,
  festenaoSdbFactoryProvider, festenaoAppFlavorContextProvider,
  festenaoFirebaseAppProvider, festenaoFirebaseContextProvider with
  festenaoFirebaseContextOverrides, the derived festenaoFirebaseAuthProvider,
  festenaoFirestoreProvider, festenaoFirebaseUserProvider and
  festenaoFirebaseUserIdProvider, the per user projects database
  (festenaoUserProjectsSdbManagerProvider, festenaoUserProjectsSdbManagerOverride,
  festenaoUserProjectsSdbProvider, UserProjectsSdbManager, UserProjectsSdb),
  and overriding them in a ProviderContainer for tests (memory file system,
  sdb factory, local firebase).
---

# Festenao riverpod providers (festenao_riverpod)

`festenao_riverpod` holds the dart-only riverpod providers every festenao
app shares: the platform services (file system, sdb factory), the app flavor,
the firebase services and the per user projects database. The app overrides
the ones without a default once, at its root, and everything below reads the
services instead of the `Xxx.instance` globals.

## Guidelines

* Dependency (git, not on pub.dev), with `riverpod` (`flutter_riverpod` in
  a Flutter app for `ProviderScope`):
  ```yaml
  dependencies:
    festenao_riverpod:
      git:
        url: https://github.com/tekaly/festenao
        path: packages/festenao_riverpod
      version: '>=1.0.0'
  ```
* Import `package:festenao_riverpod/festenao_riverpod.dart`. It re-exports
  `FestenaoAppFlavorContext` (`festenao_common/festenao_flavor.dart`) and
  `UserProjectsSdb`, `UserProjectsSdbManager`, `SdbUserProject`
  (`festenao_common/data/festenao_projects_sdb.dart`). `Override` and
  `ProviderException` come from `package:riverpod/misc.dart`,
  `ProviderContainer`, `Provider`, `StreamProvider`, `Ref` from
  `package:riverpod/riverpod.dart`; the auth helpers such as
  `signInOrUpWithEmailAndPassword` from `package:tkcms_common/tkcms_auth.dart`.
* Providers with a default: `festenaoFileSystemProvider` (`FileSystem`,
  `fileSystemDefault`: io or web), `festenaoSdbFactoryProvider`
  (`SdbFactory`, `sdbFactoryWeb` on the web, `sdbFactorySqflite` elsewhere,
  sandboxed under `appFlavorContext.appFlavorContext.uniqueAppName`, so it
  needs the flavor override), `festenaoFirebaseAppProvider`
  (`FirebaseApp.instance`, the last initialized app).
* Providers the app must override, reading them otherwise throws a
  `ProviderException` wrapping `UnimplementedError`:
  `festenaoAppFlavorContextProvider` (`FestenaoAppFlavorContext(packageName:,
  appFlavorContext:)` or `.base(basePackageName:, appFlavorContext:)`),
  `festenaoFirebaseContextProvider` (`FirebaseContext`: auth, firestore,
  storage...) and `festenaoUserProjectsSdbManagerProvider`.
* `festenaoFirebaseContextOverrides(firebaseContext)` returns the two
  overrides binding `festenaoFirebaseContextProvider` and
  `festenaoFirebaseAppProvider` to the same context; spread it in the root
  overrides so the two never disagree. Derived from it:
  `festenaoFirebaseAuthProvider`, `festenaoFirestoreProvider`,
  `festenaoFirebaseUserProvider` (`StreamProvider<User?>` on
  `auth.onCurrentUser`, loading until the first auth state: a router
  redirect waits for it before sending anyone to sign in) and
  `festenaoFirebaseUserIdProvider` (`String?`, null while unknown or signed
  out).
* `festenaoUserProjectsSdbManagerOverride(factory:, app:, name:,
  identityBloc:)` builds the override of
  `festenaoUserProjectsSdbManagerProvider`: a `UserProjectsSdbManager` on
  `factory`, syncing to the firestore of `festenaoFirebaseAppProvider`
  (`firebaseApp.firestore()`), with a `TkCmsFbIdentityBloc` on that app's
  auth (or the given `identityBloc`) calling `manager.setCurrentUser`. The
  manager, bloc and subscription are disposed with the provider; it also
  sets `globalFestenaoFirestoreDatabaseOrNull` (compat). `app` is the
  firestore app id (`appFlavorContext.appId`). Override the firebase app
  (or context) in the same list.
* `festenaoUserProjectsSdbProvider` (`StreamProvider<UserProjectsSdb?>`)
  follows `manager.onCurrentDb`: null until the manager has a database, then
  a per user database synced to `app/<app>/user_prv/<userId>/data/projects`
  when signed in, a plain local one when signed out. Read `.value?.userId`
  to know which user it belongs to.
* Flutter apps: `festenao_riverpod_flutter` adds
  `festenaoFlutterProviderOverrides`, which builds the platform defaults of
  these providers; add `festenaoFirebaseContextOverrides` next to it.
* Tests: `ProviderContainer(overrides: [...])` with
  `addTearDown(container.dispose)`; `container.listen(provider, (previous,
  next) {})` keeps a stream provider alive; memory backends:
  `newFileSystemMemory()` (`fs_shim/fs_memory.dart`), `sdbFactoryMemory` /
  `newSdbFactoryMemory()` (`idb_shim/sdb.dart`),
  `newFirebaseMemory().initializeApp()` (`tekartik_firebase_local`),
  `newFirestoreMemory()` (`tekartik_firebase_firestore_sembast`), and for a
  full local context with auth
  `initFirebaseServicesLocalSdb(sdbFactory:, projectId:).init()`
  (`tkcms_common/tkcms_firestore.dart`), closed in tear down.
* The `.g.dart` files are committed: after editing an `@riverpod` function
  run `dart run build_runner build` in the package.

## Examples

### The root overrides of an app

```dart
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:idb_shim/sdb.dart';
import 'package:riverpod/misc.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Pass the result to `ProviderScope(overrides:)` or
/// `ProviderContainer(overrides:)`, once.
List<Override> myAppOverrides({
  required FirebaseContext firebaseContext,
  required SdbFactory sdbFactory,
  required FlavorContext flavorContext,
}) {
  var appFlavorContext = FestenaoAppFlavorContext.base(
    basePackageName: 'com.example.myapp',
    appFlavorContext: flavorContext.toAppFlavorContext(baseAppId: 'myapp'),
  );
  return [
    festenaoAppFlavorContextProvider.overrideWithValue(appFlavorContext),
    festenaoSdbFactoryProvider.overrideWithValue(sdbFactory),
    ...festenaoFirebaseContextOverrides(firebaseContext),
    festenaoUserProjectsSdbManagerOverride(
      factory: sdbFactory,
      app: appFlavorContext.appId,
    ),
  ];
}
```

### A provider built on the shared ones

```dart
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:riverpod/riverpod.dart';

/// The projects database of the signed in user, null until the auth and the
/// manager agree on the same user.
final myUserProjectsSdbProvider = Provider<UserProjectsSdb?>((ref) {
  var userId = ref.watch(festenaoFirebaseUserIdProvider);
  var sdb = ref.watch(festenaoUserProjectsSdbProvider).value;
  if (userId == null || sdb?.userId != userId) {
    return null;
  }
  return sdb;
});

/// True once the auth has emitted, whatever the answer.
final authReadyProvider = Provider<bool>(
  (ref) => ref.watch(festenaoFirebaseUserProvider).hasValue,
);
```

### Test container on memory backends

```dart
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:idb_shim/sdb.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_auth.dart'; // signInOrUpWithEmailAndPassword
import 'package:tkcms_common/tkcms_firestore.dart';

final _appFlavorContext = FestenaoAppFlavorContext(
  packageName: 'com.example.test',
  appFlavorContext: FlavorContext.test.toAppFlavorContext(baseAppId: 'myapp'),
);

void main() {
  late ProviderContainer container;
  late FirebaseContext firebaseContext;

  setUp(() async {
    var sdbFactory = newSdbFactoryMemory();
    firebaseContext = await initFirebaseServicesLocalSdb(
      sdbFactory: newSdbFactoryMemory(),
      projectId: 'myapp-test',
    ).init();
    container = ProviderContainer(
      overrides: [
        festenaoAppFlavorContextProvider.overrideWithValue(_appFlavorContext),
        festenaoFileSystemProvider.overrideWithValue(newFileSystemMemory()),
        festenaoSdbFactoryProvider.overrideWithValue(sdbFactory),
        ...festenaoFirebaseContextOverrides(firebaseContext),
        festenaoUserProjectsSdbManagerOverride(
          factory: sdbFactory,
          app: _appFlavorContext.appId,
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await firebaseContext.close();
    });
  });

  test('the projects db follows the signed in user', () async {
    // Keep the stream providers alive for the test.
    container.listen(festenaoFirebaseUserProvider, (previous, next) {});
    container.listen(festenaoUserProjectsSdbProvider, (previous, next) {});

    var credential = await container
        .read(festenaoFirebaseAuthProvider)
        .signInOrUpWithEmailAndPassword(
          email: 'user@example.com',
          password: 'test1234',
        );
    var userId = credential.user.uid;
    while (container.read(festenaoUserProjectsSdbProvider).value?.userId !=
        userId) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(container.read(festenaoFirebaseUserIdProvider), userId);
  });
}
```

### Must-override providers throw until overridden

```dart
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:riverpod/misc.dart'; // ProviderException
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

void main() {
  test('festenaoAppFlavorContextProvider must be overridden', () {
    var container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      () => container.read(festenaoAppFlavorContextProvider),
      throwsA(
        isA<ProviderException>().having(
          (e) => e.exception,
          'exception',
          isUnimplementedError,
        ),
      ),
    );
  });
}
```

## Common mistakes

* Overriding `festenaoFirebaseContextProvider` alone: use
  `festenaoFirebaseContextOverrides` so `festenaoFirebaseAppProvider` (and
  the projects manager reading it) point to the same app.
* Reading `festenaoSdbFactoryProvider` without a flavor override (its
  default sandbox path needs `festenaoAppFlavorContextProvider`).
* Treating `festenaoFirebaseUserProvider` in `loading` as signed out.
* Creating a `UserProjectsSdbManager` by hand next to the override (two
  managers on one factory); let the override own it.
