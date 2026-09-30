---
name: festenao-admin-base-app-auth-data
description: >-
  Use when a screen or tool of an app built on festenao_admin_base_app needs
  the signed in identity or the data of a project: the identity
  (globalTkCmsFbIdentityBloc, TkCmsFbIdentity, AppAuthBloc /
  globalFestenaoAppAuthBloc, goToAuthScreen, globalAuthFlutterUiService), the
  firebase globals (globalFestenaoAdminAppFirebaseContext,
  globalFestenaoAppFirebaseContext, globalFestenaoFirestoreDatabase projectDb
  / appDb), the local projects db (globalProjectsDb, ProjectsDb, DbProject,
  ProjectsDbSynchronizer), the content db of a project (globalProjectsDbBloc,
  MultiProjectsDbBloc grabContentDb / releaseContentDb,
  EnforcedSingleProjectDbBloc, SingleCompatProjectDbBloc,
  FestenaoAdminAppProjectContext, ByProjectIdAdminAppProjectContext,
  AdminAppProjectContextDbBloc, AdminAppProjectScreenBlocBase,
  AdminScreenBlocMixin projectDb), the sembast stores dbArtistStoreRef /
  dbEventStoreRef / dbInfoStoreRef / dbImageStoreRef, synchronize and
  globalFs. Not the app startup nor the widgets.
---

# festenao_admin_base_app auth and data

After `festenaoAdminAppInit` the admin app works on globals: the identity
bloc of tkcms, the firebase context and root paths, a local sembast
`ProjectsDb` mirroring the projects the identity can reach, and one
synced content database per project (`ContentDb` + `FestenaoSyncedDb`),
grabbed and released by the screens through a `FestenaoAdminAppProjectContext`.

```dart
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';

class ArtistCountBloc extends AdminAppProjectScreenBlocBase<int> {
  ArtistCountBloc({required super.projectContext}) {
    () async {
      // The content db of the project, released when the bloc is disposed.
      var db = await projectDb;
      audiAddStreamSubscription(
        dbArtistStoreRef.query().onRecords(db).listen((artists) {
          add(artists.length);
        }),
      );
    }();
  }
}
```

## Guidelines

### Identity

* `globalTkCmsFbIdentityBloc.state` (`festenao_common/auth/festenao_auth.dart`,
  which exports `tkcms_common/tkcms_auth.dart`) is a `ValueStream` whose
  `.identity` is null (signed out), a `TkCmsFbIdentityUser` (`userId`,
  `user`) or a `TkCmsFbIdentityServiceAccount` (local and service account
  contexts, `firebaseApp.hasAdminCredentials`). Key the local databases by
  `identity.userOrAccountId` (`userLocalId`), never by `userId`, which is
  null for a service account.
* `AppAuthBloc(appRef)` (created by init as `globalFestenaoAppAuthBlocOrNull`
  unless `options` were given) streams `AppAuthBlocState`: `identity` and
  `userAccess`, the `TkCmsEditedFsUserAccess` of the user for the app
  (super admin for a service account, else the `user_access` document of
  the app, null when unreadable).
* `goToAuthScreen(context)` pushes `globalAuthFlutterUiService.authScreen()`
  (`auth/auth.dart`): the service is set by
  `initFestenaoAdminFirebaseContextLocalSdb` (`FirebaseUiAuthServiceBasic`)
  and `initFestenaoAdminFirebaseFlutter` (`FirebaseUiAuthServiceFlutter`),
  otherwise null. `globalAuthBloc` (`auth/auth_bloc.dart`) only streams the
  `FirebaseUser?`.

### Firebase globals

* `globalFestenaoAdminAppFirebaseContext` (`firebase/firebase.dart`): the
  `FirebaseContext` of init (`firebaseApp`, `firestore`, `auth`,
  `storage`, `projectId`).
* `globalFestenaoAppFirebaseContext` (`FestenaoAppFirebaseOptions`):
  `firestoreRootPath` and `storageRootPath` (`app/<appId>` by default),
  `storageBucket`; `getImageDirStoragePath(name)`.
* `globalFestenaoFirestoreDatabase` (`firebase/firestore_database.dart`,
  re-exporting `festenao_common`): `projectDb`
  (`TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>`: `fsEntityRef`,
  `fsUserEntityAccessRef(userId, entityId)`, `createEntity`...), `appDb`,
  `userPrvDb`, `appId`, `firestore`, `resolveProjectSlug` /
  `setProjectSlug`. `gFsDatabaseService` (tkcms admin app) is the same
  object. Writes to an entity or an access document from the client are
  refused by the rules: the api does them.

### Projects db

* `globalProjectsDb` (`sembast/projects_db.dart`, a `ProjectsDb` on
  `<firebaseProjectId>-projects.db`): `onProjects(userId:)` and
  `onProject(projectId, userId:)` stream `DbProject`s (`uid` the firestore
  id, `fsId`, `name`, `isAdmin` / `isWrite` / `isRead`), `getProject`,
  `addProject`, `deleteProject`, `clear()`, `ready`, `db`.
* It is a mirror: `ProjectsScreenBloc` rebuilds it from the firestore
  access list while the projects screen is shown, `ProjectRootScreenBloc`
  syncs one missing project once, and
  `ProjectsDbSynchronizer(projectsDb:, fsProjects:).syncOne(projectId:,
  userId:)` (`festenao_common/sembast/projects_db_synchronizer.dart`) does
  it on demand. A project absent from the mirror has no content db.

### Content db of a project

* `globalProjectsDbBloc` (`sembast/projects_db_bloc.dart`): a
  `MultiProjectsDbBloc` by default, `grabContentDb(userId:, projectId:)`
  returns a ref counted `GrabbedContentDb` (`contentDb`: the tkcms
  `ContentDb`, `syncedDb`, `synchronize()`; `festenaoSyncedDb`: the media
  aware `FestenaoSyncedDb`), `grabContentDbOrNull` returns null and
  `grabContentDb` throws `StateError` when the project is not in
  `globalProjectsDb` for that user; `releaseContentDb` closes it at zero.
  Files live in `globalFs` under `project/<base64url(projectId)>/`
  (`content.db`, the medias), firestore under
  `projectDb.fsEntityRef(projectId)`. `EnforcedSingleProjectDbBloc`
  (`enforcedProjectId`) is a multi bloc with one project;
  `SingleCompatProjectDbBloc` (`syncedDb`, `festenaoSyncedDb`) is the
  legacy single database.
* Screens hold a `FestenaoAdminAppProjectContext`
  (`admin_app/admin_app_project_context.dart`):
  `ByProjectIdAdminAppProjectContext(projectId:)` in multi project mode
  (`firestore`, `storage`, `firestorePath`, `storagePath`, `storageBucket`,
  `firestoreDatabaseContext`), `SingleFestenaoAdminAppProjectContext` in
  compat mode (`ByProjectIdAdminAppProjectContext.mainProjectId`).
* `AdminAppProjectContextDbBloc(projectContext:)` is the short lived handle
  of a screen: `grabDatabase()` (the sembast `Database`), `grabSyncedDb()`,
  `grabFestenaoSyncedDb()` (awaits `ready`); it grabs once and releases in
  `selfDispose`, so own it through `audiAddDisposable`. Simplest: extend
  `AdminAppProjectScreenBlocBase<State>` (`screen/screen_bloc_import.dart`),
  which mixes `AdminScreenBlocMixin` in: `dbBloc` and `projectDb`
  (`Future<Database>`).
* Stores (`festenao_common/data/festenao_db.dart`, exported by
  `screen_bloc_import.dart`): `dbArtistStoreRef`, `dbEventStoreRef`,
  `dbInfoStoreRef`, `dbImageStoreRef`, typed `CvStoreRef<String, T>`:
  `query().onRecords(db)`, `find(db)`, `record(id).get / put / delete(db)`;
  `DbArtist` / `DbEvent` / `DbInfo` share the `DbArticle` fields (`name`,
  `subtitle`, `content`, `tags`, `attributes`, `hidden` from the
  `articleTagHidden` tag). A write goes to the synced db; `synchronize()`
  on the `ContentDb` (what `ProjectRootScreenBloc.sync()` does) pushes it
  to firestore. Images and medias go through the `FestenaoSyncedDb`
  (`AdminArticleEditScreenBlocMixin.save` handles the image data).

### Files and local factories

* `globalFs` (`data/file_system.dart`, fs_shim): the app documents
  directory sandboxed under `uniqueAppName`; `globalSembastDatabaseFactory`
  / `globalSembastDatabasesContext` (`sembast/sembast.dart`) back the
  content dbs; `encodeForPath(projectId)` is the base64url folder name.
  `initFestenaoLocalSembastFactory` runs once.

## Examples

### Listing and hiding artists from a screen bloc

```dart
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';

class ArtistsBlocState {
  final List<DbArtist> artists;

  ArtistsBlocState(this.artists);
}

class ArtistsBloc extends AdminAppProjectScreenBlocBase<ArtistsBlocState> {
  ArtistsBloc({required super.projectContext}) {
    () async {
      var db = await projectDb;
      audiAddStreamSubscription(
        dbArtistStoreRef.query().onRecords(db).listen((records) {
          add(ArtistsBlocState(records.where((a) => !a.hidden).toList()));
        }),
      );
    }();
  }

  /// Hidden is a tag: the user app skips the article.
  Future<void> hide(String artistId) async {
    var db = await projectDb;
    var artist = await dbArtistStoreRef.record(artistId).get(db);
    if (artist != null) {
      artist.tags.v = [...?artist.tags.v, articleTagHidden];
      await dbArtistStoreRef.record(artistId).put(db, artist);
    }
  }
}
```

### A tool grabbing the content db of a project

```dart
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/sembast/projects_db_bloc.dart';
import 'package:festenao_common/auth/festenao_auth.dart';

/// Pulls firestore then counts the events; the db is released whatever
/// happens.
Future<int> syncAndCountEvents(String projectId) async {
  var identity = globalTkCmsFbIdentityBloc.state.value.identity;
  var userId = identity?.userOrAccountId;
  if (userId == null) {
    throw StateError('not signed in');
  }
  var bloc = globalProjectsDbBloc as MultiProjectsDbBloc;
  var grabbed = await bloc.grabContentDb(userId: userId, projectId: projectId);
  try {
    await grabbed.contentDb.synchronize();
    var db = await grabbed.contentDb.syncedDb.database;
    return (await dbEventStoreRef.find(db)).length;
  } finally {
    await bloc.releaseContentDb(grabbed);
  }
}
```

### Identity and app level access in a widget

```dart
import 'package:festenao_admin_base_app/auth/app_auth_bloc.dart';
import 'package:festenao_admin_base_app/auth/auth.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
// isAdmin / isWrite / isRead are extensions on the access documents.
import 'package:tkcms_common/tkcms_firestore.dart';

class AccessBadge extends StatelessWidget {
  const AccessBadge({super.key});

  @override
  Widget build(BuildContext context) => ValueStreamBuilder(
    stream: globalFestenaoAppAuthBloc.state,
    builder: (context, snapshot) {
      var state = snapshot.data;
      var identity = state?.identity;
      if (identity == null) {
        return TextButton(
          onPressed: () => goToAuthScreen(context),
          child: const Text('Sign in'),
        );
      }
      var isAdmin = state!.userAccess?.isAdmin ?? false;
      return Text('${identity.userOrAccountId}: ${isAdmin ? 'admin' : 'user'}');
    },
  );
}
```

### The access of a user to a project, from firestore

```dart
import 'package:festenao_admin_base_app/firebase/firestore_database.dart';

Future<bool> isProjectAdmin(String projectId, String userId) async {
  var projectDb = globalFestenaoFirestoreDatabase.projectDb;
  var access = await projectDb
      .fsUserEntityAccessRef(userId, projectId)
      .get(projectDb.firestore);
  return access.exists && (access.admin.v ?? false);
}
```

## Common mistakes

* `StateError: ContentDb not found for <id>`: the project is not in the
  local mirror for that identity; sync it first (open the projects screen
  or `ProjectsDbSynchronizer.syncOne`).
* A content db that is never closed: an `AdminAppProjectContextDbBloc`
  created by hand and not disposed; extend `AdminAppProjectScreenBlocBase`.
* Reading `identity.userId` for a service account: null; use
  `userOrAccountId`.
* Edits that never reach firestore: the synced db is local until
  `synchronize()` runs (the project root screen's Sync entry).
