**Location:** `festenao_common_flutter`
(`lib/admin_explorer_flutter.dart`, implementation in `lib/src/admin/`), with
the linux entry point in `festenaoprv_dashboard_app/lib/main_admin_sdk.dart`.

**Goal**

An admin build: everything the explorers reach — firestore, the file system,
sembast and sdb — behind credentials the app itself holds, nothing bundled.

---

### 1. What it is

Nothing is initialised from a flavor or a bundled configuration, which is what
makes it an admin build: it reaches whatever the credentials it is given reach,
and the whole file system.

`AdminExplorerScreen` is the whole of it in one list:

| Item | What it opens |
|---|---|
| Credentials | the service accounts the app holds |
| Firestore explorer | [the firestore explorer](firestore_explorer.md), as the selected credentials |
| File system explorer | [the file system explorer](file_system_explorer.md), rooted anywhere |
| Sembast explorer | a sembast database, by its path |
| Sdb explorer | an sdb database, by its path |
| Any database | either, told apart by what the file holds |

An app shows it behind one item of its start page:

```dart
var credentialsDb = await AdminCredentialsDb.open(sdbFactory);
await goToAdminExplorerScreen(
  context,
  credentialsDb: credentialsDb,
  homePath: Platform.environment['HOME'],
);
```

---

### 2. The credentials

A service account is **pasted into the app**, not bundled with it.
`AdminCredentialsDb` keeps the list in an sdb database of its own, declared
with the `cv` sdb helpers:

```dart
class AdminCredentials extends ScvStringRecordBase {
  final label = CvField<String>('label');
  final projectId = CvField<String>('projectId');
  final serviceAccount = CvField<String>('serviceAccount');
  final updatedAt = CvField<SdbTimestamp>('updatedAt');
}
```

The user manages them from `AdminCredentialsScreen`: paste one, label it,
delete it, tap the one to use. The project id is read out of the service
account, and `adminServiceAccountError` says what is wrong with a paste — no
`client_email`, no `private_key`, not json at all — when it is saved rather
than on the first request.

The service account is kept as the json text it was pasted as, so nothing of it
is lost to a round trip through a model. Being a plain sdb database, the
explorer opens it like any other when something looks wrong.

The firestore explorer then runs on
`festenaoInitFirebaseWithServiceAccount`, which is the rest firestore: no admin
sdk binary needed, which is what makes this work as a plain linux flutter app.

---

### 3. Reaching everything

`adminFileSystemRoots` adds the whole file system and the home directory to the
roots an app has, so nothing is out of reach. `homePath` comes from the caller
rather than from `dart:io`, so the library still imports on the web; a linux
entry point passes `Platform.environment['HOME']`.

A database is opened by its path, absolute or not: the admin screen keeps an
explorer rooted at the root of the file system and makes the path relative to
it.

---

### 4. The linux entry point

```sh
flutter run -d linux -t lib/main_admin_sdk.dart
```

`festenaoprv_dashboard_app/lib/main_admin_sdk.dart` opens the credentials
database, runs a small app of its own, and puts the `Admin` item on its start
page. It initialises no firebase at startup — there is nothing to initialise
until a service account is picked.
