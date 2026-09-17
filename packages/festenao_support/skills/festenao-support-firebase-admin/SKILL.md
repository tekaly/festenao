---
name: festenao-support-firebase-admin
description: >-
  Use when a festenao dev tool acts on a firebase project with admin
  credentials through festenao_support: festenaoInitFirebaseAdminSdk /
  festenaoInitFirebaseAdminSdkWithServiceAccount, FestenaoFbAppProject (its
  firebaseFolder, firebaseProjectId, serviceAccountMap and context factories)
  and its three levels — the auth users (listUsers, findUserByEmail,
  createUserWithEmailAndPassword), the app (grantAppAdmin,
  grantAppSuperAdmin, appUserAccessList, apps, appDocuments) and an app
  project (projects, projectUserAccessList, setProjectUserAccess,
  revokeProjectUserAccess, FestenaoUserAccessGrant).
---

# festenao_support firebase admin

A support tool is the other side of the firestore rules: it runs as the
project, not as a user, so it reads and creates the auth users and writes the
access documents the rules never let a client write. `festenao_support` wraps
that in `FestenaoFbAppProject`, a firebase project plus the festenao app
(`app/<appId>`) and project (`app/<appId>/project/<projectId>`) selected
inside it, with a firebase context built lazily on first use.

This belongs in a `tool/` or `bin/` program of a support package, never in an
app: nothing here is subject to the rules.

## Guidelines

* Imports: `package:festenao_support/festenao_firebase_menu.dart`
  (`FestenaoFbAppProject`, `FestenaoUserAccessGrant`, `firebaseFolderProjectId`
  and the menus) and `package:festenao_support/festenao_firebase_admin_sdk.dart`
  (the two init functions). Never import `src/`.
* Credentials, by how the tool is run:
  * `FestenaoFbAppProject.firebaseFolder(path:)` — the `default` project of
    the `.firebaserc` next to a `firebase.json`, with the ambient credentials
    (`gcloud auth application-default login`). It throws when the folder is
    not a firebase folder or has no default project: running an admin tool
    against the wrong project is worse than not running it.
  * `FestenaoFbAppProject.firebaseProjectId(firebaseProjectId:)` — same
    credentials, project named explicitly.
  * `FestenaoFbAppProject.serviceAccountMap(serviceAccountMap:)` — the parsed
    service account json of a private repository, what a standalone tool uses
    (it needs no firebase folder and no gcloud login).
  * `FestenaoFbAppProject.context(context:)` — on top of a context already
    built, which must be admin sdk backed to manage users.
  * `festenaoInitFirebaseAdminSdk(projectId:, storageBucket:)` and
    `festenaoInitFirebaseAdminSdkWithServiceAccount(serviceAccountMap:,
    options:)` return the `FirebaseContext` directly, for a tool that only
    needs firestore, auth or storage.
* `appId` selects the festenao app and can be set at any time; every app or
  project level call goes through `requireAppId`, which throws a `StateError`
  naming what to do (`select app` first) when none is set. `firebaseProjectId`
  is informative — the credentials decide what is really reached.
* Global level (the firebase project): `listUsers(maxResults:, pageToken:)`,
  `findUserByEmail(email)`, `findUser(userId)`,
  `createUserWithEmailAndPassword(email:, password:, displayName:)`. They need
  a `FirebaseAuthAdmin`, i.e. the admin sdk; anything else throws.
* App level (`app/<appId>/user_access/<userId>`, an admin of the whole app):
  `getAppUserAccess`, `appUserAccessList`, `setAppUserAccess`,
  `grantAppAdmin(userId, name:)`, `grantAppSuperAdmin`, `revokeAppAccess`.
  `name` is informative, for whoever reads the document later — the email.
* `apps()` lists the documents of the `app` collection; `appDocuments()` lists
  every id, the documents that do not exist included — firestore keeps an id
  alive as soon as something hangs below it, so `app/<appId>` routinely has
  projects and access rows while the document itself was never written (the
  console shows those in italics). `appDocuments()` needs the admin sdk
  firestore.
* App project level: `projects()`, `projectCollectionIds(projectId)`,
  `projectDb` (the `TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>`),
  `getProjectUserAccess`, `projectUserAccessList`, `setProjectUserAccess`
  (writes both sides: the project's user list and the user's project list, so
  the project shows up in the app) and `revokeProjectUserAccess`.
* `FestenaoUserAccessGrant.read` / `.write` / `.admin` / `.superAdmin` is what
  a tool offers; `toUserAccess()` builds the matching `TkCmsFsUserAccess`
  (already `fixAccess()`ed).
* Everything is async and the context is built on first use, so declaring a
  menu or a command costs no network call. Build one `FestenaoFbAppProject`
  per run and pass it around.

## Examples

### Granting a user access to a project

```dart
import 'package:festenao_support/festenao_firebase_menu.dart';

/// Grants [email] write access on [projectId] of [appId], creating the user
/// when it does not exist yet.
Future<void> grantWriteAccess({
  required String appId,
  required String projectId,
  required String email,
  required String password,
}) async {
  var appProject = FestenaoFbAppProject.firebaseFolder(appId: appId);
  var user =
      await appProject.findUserByEmail(email) ??
      await appProject.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
  await appProject.setProjectUserAccess(
    projectId: projectId,
    userId: user.uid,
    userAccess: FestenaoUserAccessGrant.write.toUserAccess(),
  );
  // The app wide admin right is another document, at another level.
  // await appProject.grantAppAdmin(user.uid, name: email);
}
```

### A standalone tool on a service account

```dart
import 'package:festenao_support/festenao_firebase_menu.dart';
import 'package:my_app_common/service_account.dart';

Future<void> main() async {
  var appProject = FestenaoFbAppProject.serviceAccountMap(
    serviceAccountMap: myAppDevServiceAccountMap,
    appId: 'my_app_dev',
  );
  for (var document in await appProject.appDocuments()) {
    // `my_app_dev (no document) [project, access]` for an id that only
    // exists because something hangs below it.
    print(document);
  }
  for (var project in await appProject.projects()) {
    print('${project.id}: ${project.name.v}');
    for (var access in await appProject.projectUserAccessList(project.id)) {
      print('  ${access.id}: $access');
    }
  }
}
```

### The firebase context alone

```dart
import 'package:festenao_support/festenao_firebase_admin_sdk.dart';

Future<void> main() async {
  var context = await festenaoInitFirebaseAdminSdk(
    projectId: 'my-app-dev',
    storageBucket: 'my-app-dev.firebasestorage.app',
  );
  // Full privileges: the rules do not apply here.
  var doc = await context.firestore.doc('app/my_app_dev').get();
  print(doc.data);
}
```

## Common mistakes

* Using these tools from an app: they bypass the rules and need credentials
  an app must never hold. A client grants access through the api
  (`festenao-common-entity-api`).
* Reading `apps()` and concluding an app id is free: a query skips the
  documents that do not exist while their sub collections are still there.
  `appDocuments()` is what shows them.
* Writing only one side of a project access: `setProjectUserAccess` writes
  the entity side and the user side, and the app lists a user's projects from
  the second one.
* Building the context with anything but the admin sdk and then asking for
  the users: `auth` throws, it needs a `FirebaseAuthAdmin`.
* Assuming `firebaseProjectId` selects the project: the credentials do. It is
  what the tool reports, so pass the one the credentials belong to.
