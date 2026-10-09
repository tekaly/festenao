---
name: festenao-dashboard-base-app-screens
description: >-
  Use when mounting, navigating to or replacing the reusable screens of
  festenao_dashboard_base_app (screen.dart): DashboardHomePage,
  DashboardProjectHomeScreen, DashboardProjectContentHomeScreen, the access
  screens (DashboardProjectsAccessScreen, DashboardProjectAccessScreen,
  ProjectViewScreen, selectProject, goToProjectEditScreen,
  goToProjectSdbShareScreen, goToProjectSdbUsersScreen,
  goToProjectSdbInviteViewScreen), the content screens (ContentImagesScreen,
  ContentImageScreen, ContentImageEditScreen, ContentMediasScreen,
  ContentMediaScreen, ContentMediaEditScreen, goToContentXxxScreen), the
  project url widgets (DashboardProjectSlugScreen, DashboardProjectUrlTile,
  DashboardProjectSlugField), the debug screen (DashboardDebugScreen,
  dashboardDebugMenuContent), the demos (BlogDemoScreen, ContentDemoScreen)
  and the quizz screens (QuizzHomeScreen, QuizzQuestionEditScreen,
  QuizzControlScreen, QuizzTvScreen) and the shared views of any app
  (ProjectContentSyncButton, DataExportViewScreen,
  UnsavedChangesStateMixin). Not the route assembly nor the providers.
---

# festenao_dashboard_base_app screens

The screens of `screen.dart` are riverpod consumers that read everything
from the providers of the package and are mounted by its route modules. A
host app reuses them as they are, navigates to them with the helpers, drops
some into its own routes, or replaces one through a route override.

```dart
import 'package:festenao_dashboard_base_app/screen.dart';
import 'package:flutter/material.dart';

/// A debug screen of the app: the shared items plus its own.
class MyDebugScreen extends StatelessWidget {
  const MyDebugScreen({super.key});

  @override
  Widget build(BuildContext context) => const DashboardDebugScreen(
    packageName: 'com.example.myapp',
    title: 'My app debug',
  );
}
```

## Guidelines

* Dependency (git, not on pub.dev); imports
  `package:festenao_dashboard_base_app/screen.dart`, plus `router.dart` to
  navigate and `provider.dart` for the state. The screens need the root
  `ProviderScope` with the flavor, firebase and projects overrides set.
* Every screen exposes its `routeName` and `routeLocationPart` consts; they
  feed the `RoutePathDef`s of `router.dart`, which are what you navigate
  with (`context.pushPath(def, parameters:)`), never those strings.
* `DashboardHomePage`: the projects of the signed in user
  (`rpdUserProjectsProvider`), links to `projectsAccessPath` and
  `dashboardLogsPath`, a FAB to `goToAuthScreen`, and in debug mode a tile
  doing `context.pushNamed('debug')`: declare a route named `debug`.
* `DashboardProjectHomeScreen({projectId})` and
  `DashboardProjectContentHomeScreen({projectId, dataId})` read the ids from
  the route scope when null. The project home lists the project (from the
  local projects db, `ProjectHomeScreenBloc`) and the entries to the demos,
  quizz, images and medias.
* Access: `DashboardProjectsAccessScreen(selectMode:)` (the user's
  projects, a sync action, a FAB creating one through
  `goToProjectEditScreen(context, project: null)`, which writes the entity
  with `projectDb.createEntity`); `selectProject(context)` pops a
  `SelectProjectResult` (`projectId`); `DashboardProjectAccessScreen(projectId:)`
  is `ProjectViewScreen(entityId:)` with its share, leave and delete
  actions, on the scoped `currentEntityAccessProvider`. The helpers
  `goToProjectSdbShareScreen(context, projectId:, entityAccess:, projectsDb:)`,
  `goToProjectSdbUsersScreen(context, projectId:, entityAccess:)`,
  `goToProjectSdbInviteViewScreen(context, projectId:, inviteId:, ...)` and
  `goToProjectSdbUserEditScreen(context, param:, entityAccess:)` take the
  entity access for another entity type; `ProjectSdbInviteViewScreen.defaultInviteBaseUrl`
  is the invite link base.
* Content: `ContentImagesScreen(projectId:, dataId:)` (list, sync button
  calling `content.synchronize()`, delete = `deleteImage` +
  `mediaDb.deleteMediaFile`), `ContentImageScreen(projectId:, dataId:,
  imageId:)`, `ContentImageEditScreen(..., imageId: null)` to create,
  `ContentMediasScreen`, `ContentMediaScreen(..., mediaId:)`,
  `ContentMediaEditScreen(..., mediaId: null)`; each has a
  `goToContentXxxScreen(context, projectId:, dataId:, ...)` pushing its
  path with `context.pushPath`. `dataId` defaults to
  `SdbProjectContent.defaultDataId` where optional.
* Project url: `DashboardProjectSlugScreen(slug:, projectLocation:,
  fsDatabase:)` resolves `/p/<slug>` with `resolveProjectSlug` (an old slug
  is followed) then `context.go(projectLocation(projectId))`, shows
  "No project" when unknown; `dashboardProjectSlugLocation(slug)`;
  `DashboardProjectUrlTile(entityId:)` shows `<origin>/p/<slug>` with a
  copy button, nothing without a slug; `DashboardProjectSlugField(controller:,
  projectId:, currentSlug:, fsDatabase:, onStatusChanged:)` checks the
  availability in the registry as the user types, save only on
  `FestenaoSlugStatus.available` (or unchanged), then
  `globalFestenaoFirestoreDatabase.setProjectSlug(projectId, slug)`.
* Debug: `dashboardDebugMenuContent(packageName:)` inside a `muiBodyWidget`
  or `muiScreenWidget` adds the shared items (the file system explorer);
  `DashboardDebugScreen(packageName:, title:)` for an app with nothing else,
  `goToDashboardDebugScreen(context, packageName:)`.
* Quizz: `QuizzHomeScreen` (questions and quizzes tabs, project id from the
  scope), `QuizzQuestionEditScreen(questionId:)` (null creates),
  `QuizzControlScreen(quizId:)` (admin control, the QR code of the player
  url from `quizzUserPlayUriBuilderProvider`), `QuizzTvScreen(quizId:)`.
* Demos: `BlogDemoScreen` (ids from the scope, data id `blog`),
  `LegacyBlogDemoScreen(projectId:)`, `ContentDemoScreen(projectId:, dataId:)`
  with the artist, location, event and image tabs.
* Shared views for an app's own screens: `ProjectContentSyncButton(projectId:,
  dataId:)`, an app bar action showing the synchronization of a project
  content (`projectContentSyncStatusProvider`: spinner while it runs,
  `Icons.sync_problem` once it failed) and synchronizing on tap;
  `DataExportViewScreen(title:, content:, filename:)`, a monospace text
  export (wrap toggle, pinch zoom, download, `.jsonl` for a database
  export); `UnsavedChangesStateMixin` on an edit screen's `State`
  (`hasPendingChanges`, optional `saveAndLeave`, `wrapUnsavedChanges(child:)`)
  showing the festenao unsaved changes dialog, without its save button when
  `saveAndLeave` is null. See `test/shared_views_test.dart`.
* Modules: `DashboardProjectHomeScreen` shows the blog, content and quizz
  tiles of the modules on in the project (`dashboardModuleBlog`,
  `dashboardModuleContent`, `dashboardModuleQuizz`; all when the project has
  no list). An app reads `projectModulesProvider(projectId)` (null: every
  module) and writes with `dashboardSetProjectModules(ref, projectId,
  modules)`, which updates the local mirror too.
* Name clashes with festenao_admin_base_app: `ProjectViewScreen`,
  `ProjectViewResult`, `SelectProjectResult`, `selectProject`,
  `ProjectLeading`, `goToProjectEditScreen`, `goToProjectViewScreen` exist
  in both; the admin `screen_import.dart` does not export them, so only an
  explicit admin import clashes: prefix it or `hide` them.
* Widget tests: a memory firebase (`initFirebaseServicesMemory()` from
  `tkcms_common/tkcms_firebase.dart`) and `tester.runAsync` around the
  database work, then pump with real delays, as `test/project_slug_screen_test.dart`.

## Examples

### The url of a project in its form

```dart
import 'package:festenao_common/festenao_slug.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common_flutter/festenao_slug_flutter.dart';
import 'package:festenao_dashboard_base_app/screen.dart';
import 'package:flutter/material.dart';

class ProjectUrlForm extends StatefulWidget {
  final String projectId;
  final String? currentSlug;

  const ProjectUrlForm({super.key, required this.projectId, this.currentSlug});

  @override
  State<ProjectUrlForm> createState() => _ProjectUrlFormState();
}

class _ProjectUrlFormState extends State<ProjectUrlForm> {
  late final _slug = TextEditingController(text: widget.currentSlug);
  var _status = FestenaoSlugStatus.empty;

  @override
  void dispose() {
    _slug.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      DashboardProjectSlugField(
        controller: _slug,
        projectId: widget.projectId,
        currentSlug: widget.currentSlug,
        onStatusChanged: (status) => setState(() => _status = status),
      ),
      FilledButton(
        onPressed: _status == FestenaoSlugStatus.available
            ? () => globalFestenaoFirestoreDatabase.setProjectSlug(
                widget.projectId,
                _slug.text,
              )
            : null,
        child: const Text('Use this url'),
      ),
      // `<origin>/p/<slug>` with a copy button, once the project has one.
      DashboardProjectUrlTile(entityId: widget.projectId),
    ],
  );
}
```

### Navigating to the base screens from an app screen

```dart
import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:festenao_dashboard_base_app/screen.dart';
import 'package:flutter/material.dart';

class ProjectMenu extends StatelessWidget {
  final String projectId;

  const ProjectMenu({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      ListTile(
        title: const Text('Images'),
        onTap: () => goToContentImagesScreen(
          context,
          projectId: projectId,
          dataId: SdbProjectContent.defaultDataId,
        ),
      ),
      ListTile(
        title: const Text('Medias'),
        onTap: () => goToContentMediasScreen(
          context,
          projectId: projectId,
          dataId: SdbProjectContent.defaultDataId,
        ),
      ),
      ListTile(
        title: const Text('Share'),
        onTap: () => goToProjectSdbShareScreen(context, projectId: projectId),
      ),
      ListTile(
        title: const Text('Pick another project'),
        onTap: () async {
          var result = await selectProject(context);
          if (result != null && context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(result.projectId)));
          }
        },
      ),
    ],
  );
}
```

### A debug screen with the shared items and the app's own

```dart
import 'package:festenao_dashboard_base_app/screen.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';

class AppDebugScreen extends StatelessWidget {
  const AppDebugScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Debug')),
    body: muiBodyWidget(() {
      // The file system explorer, on the app's own directory.
      dashboardDebugMenuContent(packageName: 'com.example.myapp');
      muiItem('Say hi', () async {
        await muiSnack(muiBuildContext, 'hi');
      });
    }),
  );
}
```

### A slug route resolved on a memory firestore (widget test)

```dart
import 'package:festenao_common/festenao_slug.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_dashboard_base_app/router.dart';
import 'package:festenao_dashboard_base_app/screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

void main() {
  testWidgets('/p/<slug> opens the project', (tester) async {
    late FestenaoFirestoreDatabase db;
    late String projectId;
    await tester.runAsync(() async {
      db = FestenaoFirestoreDatabase(
        firebaseContext: (await initFirebaseServicesMemory()).initContext(),
        flavorContext: AppFlavorContext.test,
      );
      projectId = await db.projectDb.createEntity(
        userId: 'u1',
        entity: FsProject()..name.v = 'Blog',
      );
      await db.setProjectSlug(projectId, 'my-blog');
    });
    var router = GoRouter(
      initialLocation: '/p/my-blog',
      routes: [
        GoRoute(
          path: '/p/:slug',
          builder: (context, state) => DashboardProjectSlugScreen(
            slug: state.pathParameters['slug']!,
            fsDatabase: db,
            projectLocation: (id) => '/project/$id',
          ),
        ),
        GoRoute(
          path: '/project/:id',
          builder: (context, state) =>
              Text('project ${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('project $projectId'), findsOneWidget);
  });
}
```

## Common mistakes

* `Bad state: no provider found` or an empty home: a base screen pumped
  without the root `ProviderScope` overrides of `provider.dart`.
* Tapping "Debug" on the home page throws: no route named `debug`.
* Ambiguous `ProjectViewScreen`: an explicit import of the admin
  `project_view_screen.dart` next to `screen.dart`.
