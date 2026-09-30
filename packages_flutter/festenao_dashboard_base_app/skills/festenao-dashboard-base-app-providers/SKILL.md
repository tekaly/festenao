---
name: festenao-dashboard-base-app-providers
description: >-
  Use when reading or wiring the riverpod providers of a festenao dashboard
  app with festenao_dashboard_base_app (provider.dart): the root ProviderScope
  overrides (festenaoAppFlavorContextProvider, festenaoFirebaseContextOverrides,
  festenaoUserProjectsSdbManagerOverride, sdbFactoryProvider), firebase and
  identity (rpdFirestoreProvider, rpdFirebaseAuthProvider, authProvider,
  rpdIdentityProvider), the user projects (rpdUserProjectsDbProvider),
  project access (rpdProjectsAccessProvider, rpdProjectAccessProvider,
  currentEntityAccessProvider, currentProjectsMirrorDbProvider), the synced
  content sdb of a project (projectContentProvider, contentSdbProvider,
  artistEntriesProvider, eventEntriesProvider, imageEntriesProvider,
  mediaEntriesProvider, locationEntriesProvider, SdbProjectContent,
  SdfContentSdb, the Sdf* records), the blog demo (blogEntriesProvider,
  DbBlog), the quizz providers (quizzDatabaseProvider,
  quizzApiServiceProvider) and dashboardEntitySlugProvider. Not the routes
  nor the screens.
---

# festenao_dashboard_base_app providers

`provider.dart` re-exports `festenao_riverpod` (the shared festenao
providers) and adds the dashboard ones: firebase instances, the identity, the
per user projects database, the access to one project and, per project and
data id, a synced sdb (`app/<app>/project/<uid>/data/<dataId>`) whose stores
(artists, events, images, locations, medias) the screens stream.

```dart
import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ArtistCount extends ConsumerWidget {
  final String projectId;

  const ArtistCount({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var artists = ref.watch(
      artistEntriesProvider(projectId, SdbProjectContent.defaultDataId),
    );
    return Text('${artists.value?.length ?? 0} artists');
  }
}
```

## Guidelines

### Root scope

* Dependency (git, not on pub.dev); imports
  `package:festenao_dashboard_base_app/provider.dart` and
  `package:flutter_riverpod/flutter_riverpod.dart`. Never import `src/`.
* Overrides the root `ProviderScope` needs, once, before any screen:
  `festenaoAppFlavorContextProvider` (`FestenaoAppFlavorContext(packageName:,
  appFlavorContext:)` or `.base(basePackageName:, appFlavorContext:)`),
  `...festenaoFirebaseContextOverrides(firebaseContext)` and
  `festenaoUserProjectsSdbManagerOverride(factory:, app:)`; in a Flutter
  app `await festenaoFlutterProviderOverrides(appFlavorContext:)`
  (`festenao_riverpod_flutter`) builds the flavor, file system, sdb factory
  and projects manager overrides in one call. Reading an unset one throws.
* `sdbFactoryProvider` (this package) derives an `SdbFactory` from
  `fsProvider` (sqflite, or indexeddb on the web, sandboxed at the real path
  of `festenaoFileSystemProvider`), memory when the file system fails;
  `fsProvider` prints the path once. Both exist for the apps built before
  `festenao_riverpod_flutter`; new apps use its overrides.
* Several providers and screens fall back on
  `globalFestenaoFirestoreDatabase` (`currentEntityAccessProvider`, the
  access mirror, the slug screen, `accessPublicProject`): set
  `globalFestenaoFirestoreDatabaseOrNull` at startup (the projects manager
  override does it when it is built; setting it yourself is safer).

### Firebase and identity

* `rpdFirebaseAppProvider`, `rpdFirestoreProvider`, `rpdFirebaseAuthProvider`,
  `rpdFirebaseStorageProvider` return the `.instance` globals, not the
  `festenaoFirebaseContextProvider` value: initialize firebase before the
  first read, and only once.
* `authProvider` streams `FirebaseAuth.instance.onCurrentUser` (`User?`);
  `rpdTkCmsFbIdentityBlocStateProvider` (keepAlive) streams
  `globalTkCmsFbIdentityBloc.state`, `rpdIdentityProvider` its
  `TkCmsFbIdentity?`: a user (`userId`) or a service account (`userId`
  null, `userOrAccountId` always set), null when signed out or unknown.
  `rpdHasAuthProvider` is false by default. `auth_screen.dart` re-exports
  `goToAuthScreen` / `globalAuthFlutterUiService` and `tekartik_firebase_ui_auth`.

### User projects and access

* `rpdUserProjectsDbProvider` (keepAlive) is
  `festenaoUserProjectsSdbProvider.value ?? globalProjectsSdbOrNull ??
  UserProjectsSdb.inMemory()`: without the manager override the projects
  silently live in memory. `rpdUserProjectsProvider(userId)` streams the
  `SdbUserProject`s (`uid` the firestore id, `fsId`, `name`, `isAdmin` /
  `isWrite` / `isRead`). `initFestenaoUserProjectsSdbManager(factory:,
  firestore:, app:)` is the non riverpod way to install the manager,
  following `globalTkCmsFbIdentityBloc`.
* `rpdProjectsAccessProvider` (`ProjectsAccessState`: `identity`,
  `projects`) mirrors the firestore access list of the user into the local
  database **while watched**, then streams that database;
  `ref.read(rpdProjectsAccessProvider.notifier).syncUserProjects()` rebuilds
  it once (no-op signed out or for a service account).
* `rpdProjectAccessProvider(entityId)` (`ProjectAccessState`: `project` from
  the mirror, `fsProject` and `fsUserAccess` from firestore when the mirror
  has none, `dbProjectReady` to tell loading from missing) with
  `deleteEntity()` (admin) and `leaveEntity()`. Which entity: the scoped
  `currentEntityAccessProvider` (default `globalFestenaoFirestoreDatabase.projectDb`)
  and `currentProjectsMirrorDbProvider` (default `rpdUserProjectsDbProvider`,
  **null** for an entity with no local mirror, read from firestore only),
  overridden in a `ProviderScope` around the access screens of another
  entity type (a playlist, a songbook).

### Project content sdb

* `contentCacheProvider` (keepAlive, needs the flavor, firestore and
  projects db) keeps an LRU of 4 `SdbProjectContent`;
  `projectContentProvider(projectId, dataId)` (Future) opens one: the
  `FestenaoSyncedSdb` `<dataId>_<app>_<uid>_synced.db` in the fs sandbox
  `<projectId>/<dataId>`, firestore root `app/<app>/project/<uid>/data/<dataId>`.
  It waits for the project to appear in the local projects db: a project
  the user has no access to never resolves.
* `contentSdbProvider(projectId, dataId)` streams the `SdfContentSdb?`, the
  entries providers stream its stores and yield `[]` (or null) while
  loading or on error, never an error state: `artistEntriesProvider`,
  `eventEntriesProvider`, `imageEntriesProvider`, `locationEntriesProvider`,
  `mediaEntriesProvider`, `imageEntryProvider(projectId, dataId, imageId)`,
  `mediaEntryProvider`, `mediaStatusFileEntryProvider`.
* `SdfContentSdb` (extension `SdbContextSdbExt`): `onArtists` / `addArtist`
  / `deleteArtist`, the same for events and locations, `onImages` /
  `onImage` / `addImage` / `putImage` / `getImage` / `deleteImage`, and
  `mediaDb` (`FestenaoMediaSdb`: `onMediaFiles`, `onMediaFile`,
  `onMediaStatusFile`, `deleteMediaFile`). Records are cv sdb models
  (`SdfArtist`, `SdfEvent`, `SdfImage`, `SdfLocation`, `name.v`...) with
  `id`; `initSdfConstructors()` registers them (done when a content opens).
* `SdbProjectContent`: `contentSdb`, `syncedSdb`, `mediaSource`,
  `synchronize()` (returns `SyncedSyncStat`), `dispose`; the schema is
  `sdfContentOpenOptions` (version 2, the four stores plus the media
  stores); `SdbProjectContent.addContentOptions(SdbProjectContentOptions(dataId:,
  openDatabaseOptions:))` gives another data id its own schema.
  `openProjectFestenaoSyncedSdb(...)` is the low level opener.

### Blog demo, quizz, slug

* `blogEntriesProvider(projectId, dataId)` (`DbBlog`: `title`, `content`,
  `timestamp`), `blogSdbProvider` (`BlogSdb.addBlog` / `deleteBlog` /
  `onBlogs`), `blogContentProvider`, `blogCacheProvider`; the blog cache
  works as user `''` (public access, `accessPublicProject`,
  `publicUserProjectsProvider`) and reads
  `festenaoUserProjectsSdbProvider.requireValue`: it throws until the
  manager delivered a database. `openProjectSyncedSdb(...)` opens a plain
  `AutoSynchronizedFirestoreSyncedSdb` for any schema.
* Quizz: `quizzApiServiceProvider` (override with the app's
  `TkCmsApiServiceBaseV2`, null keeps the admin side working and players
  unable to send results), `quizzAppIdProvider`, `quizzDatabaseProvider(projectId)`,
  `quizzQuestionsProvider(projectId)`, `quizzQuizzesProvider`,
  `quizzQuizStatusProvider((projectId:, quizId:))`,
  `quizzAdminControllerProvider` / `quizzUserControllerProvider` (auto
  disposed with the screens), `quizzUserPlayUriBuilderProvider` (override
  when the player app is hosted apart).
* `dashboardEntitySlugProvider(entityId)` streams the `slug` of a project
  document, null for another entity type.

### Tests

* `ProviderContainer(overrides: [rpdIdentityProvider.overrideWithValue(null)])`
  keeps firebase out; `addTearDown(container.listen(provider, (p, n) {}).close)`
  keeps an auto disposed provider alive; `container.read(provider.future)`.

## Examples

### The root scope of a Flutter dashboard app

```dart
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:festenao_riverpod_flutter/festenao_riverpod_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

/// [firebaseContext] comes from the app's firebase init (flutter, rest, local).
Future<void> runDashboard({
  required FirebaseContext firebaseContext,
  required FlavorContext flavorContext,
  required Widget app,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  var appFlavorContext = FestenaoAppFlavorContext.base(
    basePackageName: 'com.example.dashboard',
    appFlavorContext: flavorContext.toAppFlavorContext(baseAppId: 'myapp'),
  );
  globalFestenaoFirestoreDatabaseOrNull = FestenaoFirestoreDatabase(
    firebaseContext: firebaseContext,
    flavorContext: appFlavorContext.appFlavorContext,
  );
  var overrides = await festenaoFlutterProviderOverrides(
    appFlavorContext: appFlavorContext,
  );
  runApp(
    ProviderScope(
      overrides: [
        ...overrides,
        ...festenaoFirebaseContextOverrides(firebaseContext),
      ],
      child: app,
    ),
  );
}
```

### Streaming and editing the artists of the scoped project

```dart
// The sdb record base and its `id` extension.
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ArtistsScreen extends ConsumerWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var projectId = ref.watch<String>(currentProjectIdProvider);
    var dataId = ref.watch<String>(currentDataIdProvider);
    var artists = ref.watch(artistEntriesProvider(projectId, dataId));
    var content = ref.watch(projectContentProvider(projectId, dataId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Artists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: content.hasValue
                ? () => content.value!.synchronize()
                : null,
          ),
        ],
      ),
      body: artists.when(
        // [] while the content opens: no separate loading state.
        data: (list) => ListView(
          children: [
            for (var artist in list)
              ListTile(
                title: Text(artist.name.v ?? artist.id),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    var sdb = ref
                        .read(contentSdbProvider(projectId, dataId))
                        .value;
                    await sdb?.deleteArtist(artist.id);
                  },
                ),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          var sdb = ref.read(contentSdbProvider(projectId, dataId)).value;
          await sdb?.addArtist(SdfArtist()..name.v = 'New artist');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### The access screen of another entity type

```dart
import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:festenao_dashboard_base_app/router.dart';
import 'package:festenao_dashboard_base_app/screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// `/playlist/:playlist_id/access` on an entity that has no local mirror.
RouteBase playlistAccessRoute(
  TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity> playlistDb,
) =>
    RoutePathDef.parse(
      '/playlist/:playlist_id/access',
      name: 'playlist_access',
    ).goRoute(
      builder: (context, state) => ProviderScope(
        overrides: [
          currentEntityAccessProvider.overrideWithValue(playlistDb),
          // Null: the entity and our access are read from firestore directly.
          currentProjectsMirrorDbProvider.overrideWithValue(null),
        ],
        child: DashboardProjectAccessScreen(
          projectId: state.pathParameter('playlist_id'),
        ),
      ),
    );
```

### A signed out container in a test

```dart
import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed out, no projects', () async {
    var container = ProviderContainer(
      overrides: [rpdIdentityProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);
    // Kept alive the way a screen would, or it disposes before emitting.
    addTearDown(
      container.listen(rpdProjectsAccessProvider, (previous, next) {}).close,
    );
    var state = await container.read(rpdProjectsAccessProvider.future);
    expect(state.identity, isNull);
    expect(state.projects, isEmpty);
  });
}
```

## Common mistakes

* Projects that vanish on restart: no projects manager override, the
  default database is in memory.
* `projectContentProvider` that never completes: the project is not in the
  local projects db yet (open the access screen or `syncUserProjects()`).
* Watching `rpdProjectAccessProvider` for a playlist without overriding
  `currentProjectsMirrorDbProvider` with null: it looks the playlist up in
  the projects mirror and reports it missing.
