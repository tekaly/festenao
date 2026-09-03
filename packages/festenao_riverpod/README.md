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
- `festenaoFirebaseContextProvider` — the `FirebaseContext` (auth, firestore)
  the app runs against, must be overridden (`festenaoFirebaseContextOverrides`
  binds it together with `festenaoFirebaseAppProvider`). Derived:
  `festenaoFirebaseAuthProvider`, `festenaoFirestoreProvider`,
  `festenaoFirebaseUserProvider`, `festenaoFirebaseUserIdProvider`.
- `festenaoUserProjectsSdbManagerOverride` — the override installing the per
  user `UserProjectsSdbManager` behind `festenaoUserProjectsSdbProvider`.
- The projects of an app with **no backend** (firestore rules only, see
  `festenao_dartff/festenao_firebase_no_api_context.dart`):
  `festenaoProjectsFsProvider`, `festenaoProjectsBootstrapProvider`,
  `festenaoUserProjectsProvider`, `festenaoUserProjectProvider(id)`,
  `festenaoProjectPublicAccessProvider(id)`, and the commands behind
  `festenaoNoApiProjectsProvider` (`createProject`, `renameProject`,
  `setUserAccess`, `setPublicAccess`, `deleteProject`, `refresh`).

Setup `pubspec.yaml`:

```yaml
  festenao_riverpod:
    git:
      url: https://github.com/tekaly/festenao
      path: packages/festenao_riverpod
    version: '>=1.0.0'
```
