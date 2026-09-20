---
name: festenao-riverpod-no-api-projects
description: >-
  Use when a festenao app has no backend (no cloud function, firestore rules
  only, the festenao_firebase_no_api_context rules) and manages its projects
  through festenao_riverpod: festenaoProjectsFsProvider,
  festenaoProjectsSdbProvider, festenaoProjectsSynchronizerProvider,
  festenaoProjectsBootstrapProvider, festenaoUserProjectsProvider,
  festenaoUserProjectProvider(id), festenaoProjectPublicAccessProvider(id),
  the FestenaoNoApiProjects commands behind festenaoNoApiProjectsProvider
  (createProject, renameProject, setUserAccess, setPublicAccess,
  deleteProject, refresh, syncOne) and the FestenaoUserProjectAccessExt
  getters on SdbUserProject (canRead, canWrite, isProjectAdmin, accessLabel).
---

# No-backend projects (festenao_riverpod)

A festenao app with **no backend** talks to firestore directly: creating a
project, sharing it, opening it to the public are plain document writes that
the no-api security rules (`festenao_dartff/festenao_firebase_no_api_context.dart/firestore.rules`)
allow or refuse. `festenao_riverpod` wraps that flow in providers: the
firestore side, the per user local project list kept in sync, and the
commands.

## Guidelines

* Import `package:festenao_riverpod/festenao_riverpod.dart` (same git
  dependency as the `festenao-riverpod-providers` skill). Needs
  `festenaoFirebaseContextProvider` (`festenaoFirebaseContextOverrides`),
  `festenaoAppFlavorContextProvider` and
  `festenaoUserProjectsSdbManagerProvider`
  (`festenaoUserProjectsSdbManagerOverride`) overridden at the root.
* How it works with no server: creating a project writes
  `app/<appId>/project/<id>` naming the signed in user as `creatorUserId`,
  then the user's own admin access documents, which the rules allow
  *because* of that field. The user's project list is read from its access
  documents (`UserProjectsSdbSynchronizer`) into a local database that is
  itself synced to `app/<appId>/user_prv/<userId>/data/projects`, so it
  follows the user across devices. Sharing writes another user's access
  documents (admin only); public read opens the project `data`
  sub collections to anyone with the public access document.
* `festenaoProjectsFsProvider`: the
  `TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>` of
  `app/<appId>/project`, every firestore access goes through it
  (`fsEntityRef(id)`, `fsUserEntityAccessRef(userId, id)`,
  `fsEntityPublicAccessRef(id)`, `firestore`).
* `festenaoProjectsSdbProvider` (`UserProjectsSdb?`, null until the manager
  has one), `festenaoProjectsSynchronizerProvider`
  (`UserProjectsSdbSynchronizer?`, disposed with the provider) and
  `festenaoProjectsBootstrapProvider` (`FutureProvider<void>`, runs
  `syncUserProjects(userId:)` once per signed in user; it marks the local
  list ready, without which nothing streams). Errors stay on the bootstrap
  provider: show them there and `invalidate` it to retry.
* `festenaoUserProjectsProvider` (`StreamProvider<List<SdbUserProject>>`,
  empty while signed out) and `festenaoUserProjectProvider(projectId)`
  (`StreamProvider<SdbUserProject?>`, null without access) start the
  bootstrap themselves (`ref.listen` on it) and wait for the list to be
  ready: a list is never shown empty because it was not read yet.
* `festenaoProjectPublicAccessProvider(projectId)`
  (`StreamProvider<TkCmsFsPublicAccess>`): readable signed out, `exists`
  false and `read.v` null while private. On a firestore without change
  tracking (rest services) it is polled slowly and re-read by
  `setPublicAccess` and `refresh`.
* `FestenaoUserProjectAccessExt` on `SdbUserProject`: `canRead`,
  `canWrite`, `isProjectAdmin` (nested: admin implies write implies read)
  and `accessLabel` (`admin`, `write`, `read`, `none`). `fsId` is the
  firestore project id, `name.v` its name.
* Commands: `ref.read(festenaoNoApiProjectsProvider)` is a
  `FestenaoNoApiProjects`: `createProject(name:, projectId:)` returns the
  id and mirrors it locally right away; `renameProject(id, name)` (admin);
  `setUserAccess(projectId:, userId:, access:)` grants a
  `TkCmsFsUserAccess` (`..read.v = true..fixAccess()`) or revokes with null
  (admin, the other user sees it on its next refresh);
  `setPublicAccess(projectId:, read:)` (admin); `deleteProject(id)` (admin:
  public access removed, then flagged deleted and purged, local list
  updated); `refresh()` re-syncs the whole list, `syncOne(id)` one project.
  All run as the signed in user (`StateError('Not signed in')` otherwise)
  and the rules refuse what the user may not do with a permission error,
  nothing is hidden client side.
* Tests: the local firebase (`initFirebaseServicesLocalSdb`) does not
  enforce rules; unit test the shape of what is written and read back, and
  run the rules project (`festenao_firebase_no_api_context.dart`, `dart
  test`, needs the firebase emulator) for the permissions.

## Examples

### Container of a no-backend app (or test)

```dart
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:idb_shim/sdb.dart';
import 'package:riverpod/riverpod.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

Future<ProviderContainer> buildNoApiContainer({
  required FirebaseContext firebaseContext,
  required SdbFactory sdbFactory,
}) async {
  var appFlavorContext = FestenaoAppFlavorContext(
    packageName: 'com.example.myapp',
    appFlavorContext: FlavorContext.dev.toAppFlavorContext(baseAppId: 'myapp'),
  );
  return ProviderContainer(
    overrides: [
      festenaoAppFlavorContextProvider.overrideWithValue(appFlavorContext),
      festenaoSdbFactoryProvider.overrideWithValue(sdbFactory),
      festenaoUserProjectsSdbManagerOverride(
        factory: sdbFactory,
        app: appFlavorContext.appId,
      ),
      ...festenaoFirebaseContextOverrides(firebaseContext),
    ],
  );
}
```

### The project commands

```dart
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:riverpod/riverpod.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Create, share, publish and delete a project as the signed in user.
Future<void> projectLifecycle(
  ProviderContainer container, {
  required String guestUserId,
}) async {
  var commands = container.read(festenaoNoApiProjectsProvider);

  var projectId = await commands.createProject(name: 'Summer festival');
  await commands.renameProject(projectId, 'Summer festival 2026');

  // Read only access for another user (revoke with access: null).
  await commands.setUserAccess(
    projectId: projectId,
    userId: guestUserId,
    access: TkCmsFsUserAccess()
      ..read.v = true
      ..fixAccess(),
  );

  // Anyone may now read the project data (shared by url).
  await commands.setPublicAccess(projectId: projectId, read: true);

  await commands.refresh(); // re-sync the local list from firestore
  await commands.deleteProject(projectId);
}
```

### Providers for the screens

```dart
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:riverpod/riverpod.dart';

/// One label per project of the signed in user, empty while signed out or
/// not ready.
final projectLabelsProvider = Provider<List<String>>((ref) {
  var projects =
      ref.watch(festenaoUserProjectsProvider).value ?? const <SdbUserProject>[];
  return [
    for (var project in projects)
      '${project.name.v} (${project.accessLabel})',
  ];
});

/// Whether the current user may edit the data of a project.
final canEditProjectProvider = Provider.family<bool, String>(
  (ref, projectId) =>
      ref.watch(festenaoUserProjectProvider(projectId)).value?.canWrite ??
      false,
);

/// Whether a project is public (readable signed out).
final isProjectPublicProvider = Provider.family<bool, String>(
  (ref, projectId) =>
      ref.watch(festenaoProjectPublicAccessProvider(projectId)).value?.read.v ??
      false,
);
```

### Showing and retrying the bootstrap

```dart
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:riverpod/riverpod.dart';

/// The error message of the project list bootstrap, null when fine.
final projectsErrorProvider = Provider<String?>((ref) {
  var bootstrap = ref.watch(festenaoProjectsBootstrapProvider);
  return bootstrap.hasError ? bootstrap.error.toString() : null;
});

Future<void> retryProjectsBootstrap(ProviderContainer container) async {
  container.invalidate(festenaoProjectsBootstrapProvider);
  await container.read(festenaoProjectsBootstrapProvider.future);
}
```

### Reading the list once, refreshed (test helper)

```dart
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:riverpod/riverpod.dart';

Future<List<SdbUserProject>> refreshedProjects(
  ProviderContainer container,
) async {
  await container.read(festenaoNoApiProjectsProvider).refresh();
  var projectsSdb = container.read(festenaoProjectsSdbProvider)!;
  return projectsSdb.getProjects(userId: projectsSdb.userId!);
}
```

## Common mistakes

* Watching `festenaoProjectsSdbProvider` streams directly and waiting
  forever: the local database only streams once the bootstrap marked the
  user ready; go through `festenaoUserProjectsProvider`.
* Calling a command signed out (`StateError('Not signed in')`).
* Expecting `setUserAccess` to show up in the other user's list without a
  `refresh()` on that side.
* Deleting a project without admin access, or before removing its public
  access by hand: `deleteProject` already does it in the right order.
