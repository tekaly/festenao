# festenao_riverpod_flutter

The Flutter values of the providers of
[`festenao_riverpod`](../../packages/festenao_riverpod): a file system in the
application support directory, an sdb database factory storing its
databases in that same directory, both sandboxed per app flavor, and the
one call that turns them into riverpod overrides.

## Getting started

Not on pub.dev, a git dependency:

```yaml
dependencies:
  festenao_riverpod_flutter:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_riverpod_flutter
```

```dart
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:festenao_riverpod_flutter/festenao_riverpod_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fs_shim/fs_shim.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

Future<void> main() async {
  // The support directory goes through a platform channel.
  WidgetsFlutterBinding.ensureInitialized();

  var appFlavorContext = FestenaoAppFlavorContext(
    packageName: 'com.example.app',
    appFlavorContext: FlavorContext.prod.toAppFlavorContext(appId: 'my_app'),
  );

  runApp(
    ProviderScope(
      overrides: await festenaoFlutterProviderOverrides(
        appFlavorContext: appFlavorContext,
      ),
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var fileSystem = ref.watch(festenaoFileSystemProvider);
    return MaterialApp(
      home: Scaffold(body: Text(fileSystem.unsandbox().path)),
    );
  }
}
```

Platforms: Android, iOS, web (IndexedDB), Linux, macOS, Windows (sqflite
through `sqflite_ffi`, which registers itself: no setup).

## What it gives

- `festenaoFlutterFileSystem` — a `FileSystem` rooted at the application
  support directory (`tekartik_app_flutter_fs`), sandboxed under the app
  flavor context's unique app name (`<appId>_<flavor>`: dev, prod and test
  data never mix).
- `festenaoFlutterSdbFactory` — the raw `SdbFactory` (`sdbFactoryWeb` on the
  web, `sdbFactorySqflite` otherwise), sandboxed in that same directory.
- `festenaoFlutterProviderOverrides` — the overrides of
  `festenaoAppFlavorContextProvider`, `festenaoFileSystemProvider`,
  `festenaoSdbFactoryProvider` and `festenaoUserProjectsSdbManagerProvider`
  in one call.
- `festenaoProviderOverrides` — the same overrides from a `FileSystem` and an
  `SdbFactory` already resolved by the two helpers above, for an app that
  needs them first (its own databases, a local firebase).

## What to know

- Await it once, in `main`, after `WidgetsFlutterBinding.ensureInitialized()`
  and before `runApp`.
- It does not override firebase: an app using the per user projects
  database adds `...festenaoFirebaseContextOverrides(firebaseContext)`
  (`festenao_riverpod`) to the same scope. The projects manager follows the
  user of `identityBloc` when given, else of the auth of that firebase app.
- Never pass already resolved values to `festenaoFlutterProviderOverrides`
  (`applicationFileSystem`, `rawSdbFactory`): they would be sandboxed twice
  and the databases land in a doubled path. Use `festenaoProviderOverrides`.
- Tests: `applicationFileSystem: fsMemory` (`tekartik_app_flutter_fs`) and
  `rawSdbFactory: sdbFactoryMemory` (`idb_shim`) keep everything in memory,
  no plugin (see `test/`).

The `festenao-riverpod-flutter-setup` skill (`skills/`) has more examples.
