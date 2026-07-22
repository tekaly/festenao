## festenao_riverpod

Generic, dart-only riverpod providers shared across Festenao apps:

- `festenaoFileSystemProvider` — app `FileSystem` (fs_shim), defaults to
  `fileSystemDefault`.
- `festenaoSdbFactoryProvider` — app `SdbFactory` (idb_shim), defaults to
  `sdbFactoryWeb` on the web and `sdbFactorySqflite` otherwise.
- `festenaoAppFlavorContextProvider` — app `FestenaoAppFlavorContext`, must be
  overridden by the app.
- `festenaoFirebaseAppProvider` — current `FirebaseApp`, defaults to
  `FirebaseApp.instance`.

Setup `pubspec.yaml`:

```yaml
  festenao_riverpod:
    git:
      url: https://github.com/tekaly/festenao
      path: packages/festenao_riverpod
    version: '>=1.0.0'
```
