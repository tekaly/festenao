## festenao_riverpod_flutter

Flutter overrides for [`festenao_riverpod`](../../packages/festenao_riverpod):

- `festenaoFlutterFileSystem` — a `FileSystem` rooted at the application
  support directory (`tekartik_app_flutter_fs`), sandboxed under the app
  flavor context's unique app name.
- `festenaoFlutterSdbFactory` — the raw `SdbFactory` (`sdbFactoryWeb` on the
  web, `sdbFactorySqflite` otherwise), sandboxed in that same directory.
- `festenaoFlutterProviderOverrides` — builds the riverpod `Override`s for
  `festenaoAppFlavorContextProvider`, `festenaoFileSystemProvider` and
  `festenaoSdbFactoryProvider` in one call.

Usage:

```dart
void main() async {
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
```

Setup `pubspec.yaml`:

```yaml
  festenao_riverpod_flutter:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_riverpod_flutter
    version: '>=1.0.0'
```
