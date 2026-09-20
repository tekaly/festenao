---
name: festenao-riverpod-flutter-setup
description: >-
  Use when bootstrapping a Flutter festenao app's riverpod root scope: await
  festenaoFlutterProviderOverrides(appFlavorContext:, applicationFileSystem:,
  rawSdbFactory:) before runApp and pass it to ProviderScope(overrides:), which
  binds festenaoAppFlavorContextProvider, festenaoFileSystemProvider,
  festenaoSdbFactoryProvider and festenaoUserProjectsSdbManagerProvider; also
  the individual helpers festenaoFlutterFileSystem (application support
  directory FileSystem sandboxed under uniqueAppName) and
  festenaoFlutterSdbFactory (sdbFactoryWeb / sdbFactorySqflite sandboxed on the
  real disk path), and the fsMemory / sdbFactoryMemory overrides used in tests,
  from package:festenao_riverpod_flutter/festenao_riverpod_flutter.dart.
---

# Flutter riverpod overrides (festenao_riverpod_flutter)

`festenao_riverpod` declares the shared providers of a festenao app but leaves
the platform ones abstract. This package supplies the Flutter values: a
`FileSystem` rooted at the application support directory and an `SdbFactory`
(sqflite/indexeddb) storing its databases in that same directory, both
sandboxed per app flavor, plus the one call that turns them into riverpod
`Override`s.

## Guidelines

* Dependency (not on pub.dev, git only):

  ```yaml
  dependencies:
    festenao_riverpod_flutter:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_riverpod_flutter
      version: '>=1.0.0'
  ```

  It brings `flutter_riverpod`, `fs_shim`, `idb_shim`, `idb_sqflite`,
  `sqflite_ffi`, `tekartik_app_flutter_fs` and `festenao_riverpod` with it.

* Imports: `package:festenao_riverpod_flutter/festenao_riverpod_flutter.dart`
  for the three helpers (it only re-exports `festenaoUserProjectsSdbManagerOverride`
  from `festenao_riverpod`, nothing else), plus
  `package:festenao_riverpod/festenao_riverpod.dart` for the providers and
  `FestenaoAppFlavorContext`, `package:flutter_riverpod/flutter_riverpod.dart`
  for `ProviderScope`/`ProviderContainer`, `package:riverpod/misc.dart` for
  `Override`. Never import `package:festenao_riverpod_flutter/src/...`.
* Startup shape, in this order: `WidgetsFlutterBinding.ensureInitialized()`
  (the support directory goes through a platform channel), build the
  `FestenaoAppFlavorContext`, `await festenaoFlutterProviderOverrides(...)`,
  then `runApp(ProviderScope(overrides: overrides, child: ...))`. Do it once,
  in `main`, never per screen or per route.
* `Future<List<Override>> festenaoFlutterProviderOverrides({required
  FestenaoAppFlavorContext appFlavorContext, FileSystem?
  applicationFileSystem, SdbFactory? rawSdbFactory, TkCmsFbIdentityBloc?
  identityBloc})` returns overrides for `festenaoAppFlavorContextProvider`,
  `festenaoFileSystemProvider`, `festenaoSdbFactoryProvider` and
  `festenaoUserProjectsSdbManagerProvider` (through
  `festenaoUserProjectsSdbManagerOverride(factory:, app: appFlavorContext.appId)`).
  `identityBloc` is accepted but **not forwarded** by the current
  implementation, so passing it changes nothing today.
* It does **not** override firebase. The projects manager override reads
  `festenaoFirebaseAppProvider`, so an app that uses the per user projects
  database must add `...festenaoFirebaseContextOverrides(firebaseContext)`
  (from `festenao_riverpod`) to the same root scope, after firebase is
  initialized.
* Sandboxing, which is the whole point of the package:
  * `Future<FileSystem> festenaoFlutterFileSystem(FestenaoAppFlavorContext
    appFlavorContext, {FileSystem? fileSystem})` takes
    `tekartik_app_flutter_fs`'s `fs`, resolves
    `getApplicationSupportDirectory()`, `.sandbox()`es it and sandboxes again
    under `appFlavorContext.appFlavorContext.uniqueAppName`. Paths seen by app
    code are therefore relative to that directory; `fileSystem.unsandbox()`
    gives the real one.
  * `SdbFactory festenaoFlutterSdbFactory(FileSystem fileSystem, {SdbFactory?
    factory})` picks `sdbFactoryWeb` when `kIsWeb` and `sdbFactorySqflite`
    otherwise, then `.sandbox(path: fileSystem.unsandbox().path)` — the
    databases land next to the files, in the **real** (unsandboxed) directory.
    Pass the file system returned by `festenaoFlutterFileSystem`, never a
    freshly sandboxed one, or the two diverge.
  * `uniqueAppName` is `<appId>_<flavor>` (`_local` for a local context), so
    dev/prod/test data never mix and changing the flavor or the app id starts
    from an empty directory.
* Desktop needs no extra work: the package depends on `sqflite_ffi`, a
  self-registering plugin that installs the FFI `databaseFactory` on
  Linux/macOS/Windows. Do not call `sqfliteFfiInit()` yourself, and do not
  replace `festenaoSdbFactoryProvider` with a hand built sqflite factory.
* Anti-patterns: using `tekartik_app_flutter_fs`'s `fs` or
  `sdbFactorySqflite` directly instead of reading
  `festenaoFileSystemProvider` / `festenaoSdbFactoryProvider`; overriding
  those two providers by hand next to `festenaoFlutterProviderOverrides` (the
  later override in the list wins and the sandboxes stop matching); forgetting
  the `await` (the function is async because the support directory is);
  calling it before `WidgetsFlutterBinding.ensureInitialized()`.
* Testing: this is a `flutter_test` package (platform channels), so use
  `TestWidgetsFlutterBinding.ensureInitialized()`, then pass
  `applicationFileSystem: fsMemory` (from
  `package:tekartik_app_flutter_fs/fs.dart`) and `rawSdbFactory:
  sdbFactoryMemory` (from `package:idb_shim/sdb.dart`) — everything stays in
  memory and no plugin is involved. Read the result from a
  `ProviderContainer(overrides: overrides)` and `addTearDown(container.dispose)`.
  Assert on `fileSystem.unsandbox().path` / `sdbFactory.getDatabaseFullPath(...)`
  containing `uniqueAppName`.

See also the `festenao-riverpod-providers` skill of `festenao_riverpod` for
what the overridden providers give access to.

## Examples

### App startup

```dart
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:festenao_riverpod_flutter/festenao_riverpod_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fs_shim/fs_shim.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

Future<void> main() async {
  // The application support directory goes through a platform channel.
  WidgetsFlutterBinding.ensureInitialized();

  var appFlavorContext = FestenaoAppFlavorContext(
    packageName: 'com.example.app',
    appFlavorContext: FlavorContext.prod.toAppFlavorContext(appId: 'my_app'),
  );

  // Resolves the support directory, so it must be awaited before runApp.
  var overrides = await festenaoFlutterProviderOverrides(
    appFlavorContext: appFlavorContext,
  );

  runApp(ProviderScope(overrides: overrides, child: const MyApp()));
}

/// Anything below reads the services from the providers.
class MyApp extends ConsumerWidget {
  /// Constructor.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var fileSystem = ref.watch(festenaoFileSystemProvider);
    var flavor = ref.watch(festenaoAppFlavorContextProvider);
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            '${flavor.appFlavorContext.uniqueAppName}\n'
            '${fileSystem.unsandbox().path}',
          ),
        ),
      ),
    );
  }
}
```

### Using the two helpers on their own

```dart
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:festenao_riverpod_flutter/festenao_riverpod_flutter.dart';
import 'package:fs_shim/fs_shim.dart';
import 'package:idb_shim/sdb.dart';

/// The platform services of the app, for code that is not riverpod aware
/// (a bloc, a background isolate helper, a migration script).
class AppStorage {
  /// Sandboxed application support file system.
  final FileSystem fileSystem;

  /// Sdb factory storing its databases in the same real directory.
  final SdbFactory sdbFactory;

  AppStorage._({required this.fileSystem, required this.sdbFactory});

  /// Resolve both for [appFlavorContext].
  static Future<AppStorage> open(
    FestenaoAppFlavorContext appFlavorContext,
  ) async {
    var fileSystem = await festenaoFlutterFileSystem(appFlavorContext);
    // Must be built from that very file system: it sandboxes the factory on
    // its real (unsandboxed) path.
    var sdbFactory = festenaoFlutterSdbFactory(fileSystem);
    return AppStorage._(fileSystem: fileSystem, sdbFactory: sdbFactory);
  }

  /// Where a database file really lands.
  Future<String> databasePath(String name) =>
      sdbFactory.getDatabaseFullPath(name);
}
```

### Test with a memory file system and a memory sdb

```dart
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:festenao_riverpod_flutter/festenao_riverpod_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/sdb.dart';
import 'package:tekartik_app_flutter_fs/fs.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var appFlavorContext = FestenaoAppFlavorContext(
    packageName: 'com.example.test',
    appFlavorContext: AppFlavorContext.test,
  );

  test('overrides are sandboxed under the unique app name', () async {
    // No platform plugin is used with these two overrides.
    var overrides = await festenaoFlutterProviderOverrides(
      appFlavorContext: appFlavorContext,
      applicationFileSystem: fsMemory,
      rawSdbFactory: sdbFactoryMemory,
    );
    var container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);

    var uniqueAppName = appFlavorContext.appFlavorContext.uniqueAppName;
    expect(
      container.read(festenaoFileSystemProvider).unsandbox().path,
      contains(uniqueAppName),
    );
    expect(
      await container.read(festenaoSdbFactoryProvider).getDatabaseFullPath(
        'mydb',
      ),
      contains(uniqueAppName),
    );
  });

  test('the file system is writable and rooted in the support directory',
      () async {
    var fileSystem = await festenaoFlutterFileSystem(
      appFlavorContext,
      fileSystem: fsMemory,
    );
    await fileSystem.currentDirectory.create(recursive: true);
    var file = fileSystem.file('data.txt');
    await file.writeAsString('hello');

    expect(await file.readAsString(), 'hello');
    expect(file.unsandbox().path, contains('support'));
  });
}
```
