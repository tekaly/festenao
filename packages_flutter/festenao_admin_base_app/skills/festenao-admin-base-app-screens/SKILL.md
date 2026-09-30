---
name: festenao-admin-base-app-screens
description: >-
  Use when adding or customizing a screen of an app built on
  festenao_admin_base_app: the facades screen/screen_import.dart and
  screen/screen_bloc_import.dart, the layout (FestenaoAdminAppScaffold,
  AdminScreenLayout, ListDrawer, AdminScreenMixin.snack), the navigation
  helpers (goToProjectRootScreen, popAndGoToProjectSubScreen,
  goToProjectsScreen / selectProject, goToAdminArtistsScreen / selectArtist,
  goToAdminArtistEditScreen, goToAdminInfosScreen, goToAdminEventsScreen,
  goToAdminImagesScreen, goToAdminExportsScreen, goToFsAppUsersScreen,
  festenaoPushScreen), the tiles (AppTextFieldTile, InfoTile, EntryTile,
  EditInfoTile, LinearWait, TilePadding, IdentityInfoTile,
  AdminArticleThumbnail, ImagePreview, showUnsavedChangesDialog, MenuItem
  popupMenu, GoToTile / SectionTile), the article edit mixins
  (AdminArticleEditScreenMixin, AdminArticleEditScreenBlocMixin,
  AdminArticleEditData), the validators, pickImageFile, appDownloadImage and
  festenaoAdminAppIntl. Not the startup nor the data access.
---

# festenao_admin_base_app screens

An admin screen is a `StatefulWidget` fed by a bloc through `BlocProvider`
and rebuilt with `ValueStreamBuilder(stream: bloc.state)`; a project screen
holds a `FestenaoAdminAppProjectContext` and reaches the content db through
`AdminAppProjectScreenBlocBase`. The package ships the scaffold, the layout,
the tiles and the `goToXxxScreen` helpers to compose more of them.

```dart
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/info_tile.dart';

class HelloScreen extends StatelessWidget {
  const HelloScreen({super.key});

  @override
  Widget build(BuildContext context) => FestenaoAdminAppScaffold(
    appBar: AppBar(title: const Text('Hello')),
    body: ListView(
      children: const [InfoTile(label: 'Status', value: 'ok')],
    ),
  );
}
```

## Guidelines

### Structure

* Dependency (git, not on pub.dev). Import
  `package:festenao_admin_base_app/screen/screen_import.dart` in a screen
  file: material, `BlocProvider`, `ValueStreamBuilder` and the rx utils,
  the common utils, `FestenaoAdminAppScaffold`, `festenaoPushScreen`,
  `AdminScreenMixin`, `FestenaoAdminAppProjectContext`,
  `AdminAppProjectContextDbBloc`. Import `screen/screen_bloc_import.dart`
  in the bloc file: the same contexts, `AdminAppProjectScreenBlocBase`,
  `AdminScreenBlocMixin`, the `festenao_db` stores and models, and the audi
  helpers (`audiAddStreamSubscription`, `audiAddDisposable`).
* The shipped pattern is one `xxx_screen.dart` and one
  `xxx_screen_bloc.dart`, the screen reading
  `BlocProvider.of<XxxBloc>(context)`, a `goToXxxScreen(context, ...)`
  function pushing `BlocProvider(blocBuilder: () => XxxBloc(...), child:
  const XxxScreen())`, and for a project screen a `ContentPageDef` in the
  navigator so the url `project/<id>/xxx` builds it
  (`route/navigator_def.dart`).
* `FestenaoAdminAppScaffold(appBar:, body:, drawer:, floatingActionButton:,
  footer:)`: a `Scaffold` which, off the web, stacks a `DebugAppBar` above
  the app bar (the current route name, a history picker, an edit box to
  jump to a path), in release too. `AdminScreenLayout(appBar:, body:,
  floatingActionButton:, useDrawer:)` adds the project `ListDrawer`: as a
  permanent left column on desktop (`isDisplayDesktop`, width over 700 in
  portrait or 1000 in landscape, `layout/adaptive.dart`), as a drawer on
  mobile when `useDrawer`. The drawer finds the project in the route name
  (`AdminAppRootProjectContextPath`).
* `AdminScreenMixin.snack(context, text)` on a state; `muiSnack` and the
  mini ui are available too.

### Navigation

* Project sub screens: `goToAdminArtistsScreen(context, projectContext:,
  transitionDelegate:)`, `goToAdminEventsScreen`, `goToAdminInfosScreen`,
  `goToAdminImagesScreen`, `goToAdminMediasScreen`, `goToAdminMetasScreen`,
  `goToAdminExportsScreen`, `goToAdminProjectUsersScreen` navigate by
  content path through `popAndGoToProjectSubScreen(context,
  projectContext:, contentPath:)` (a no-op when already there) while
  `festenaoUseContentPathNavigation` is true, else push a
  `MaterialPageRoute`. `goToProjectRootScreen(context, projectId:)`,
  `popAndGoToProjectRootScreen`.
* Edit screens push a route and return a result:
  `goToAdminArtistEditScreen(context, projectContext:, artistId:)` (null
  creates) gives `AdminArtistEditScreenResult?` (`deleted`), the same for
  `goToAdminEventEditScreen`, `goToAdminInfoEditScreen`,
  `goToAdminImageEditScreen`, `goToAdminMediaEditScreen`.
* Pickers: `selectArtist(context, projectContext:)` returns
  `AdminArtistScreenResult?` (`artist`), `selectInfo(context,
  projectContext:, infoType:)`, `selectProject(context)`
  (`SelectProjectResult.projectId`), `selectFsApp(context)` (`appId`),
  `selectFsAppProject`, `selectFsAppUser`.
* App level: `goToProjectsScreen`, `goToFsAppUsersScreen(context, appId:,
  projectId:)`, `goToFsAppsScreen`, `goToFsAppProjectsScreen(context,
  appId:)`, `goToFsAppViewScreen(context, appId:)`,
  `goToAdminFormQuestionsScreen(context, entityAccess:
  fbFsDocFormQuestionAccess(projectContext.firestoreDatabaseContext))`.
* `festenaoPushScreen<T>(context, builder:)` pushes any widget and returns
  the result when it is a `T`, null otherwise.

### Tiles and forms

* `AppTextFieldTile(labelText:, controller:, hintText:, maxLines:,
  emptyAllowed:, validator:, readOnly:, onChanged:)` is an outlined
  `TextFormField`, non empty by default; put it in a `Form(key:)` and
  `validate()` before saving. Validators (`utils/text_validator.dart`):
  `fieldIdValidator` (`a-z0-9_`), `fieldNonEmptyValidator`, `intValidator`.
* Read only tiles: `InfoTile(label:, value:, showIfValueEmpty:, onTap:)`,
  `EntryTile(label:, value:, onTap:, onLongPress:)`, `EditInfoTile(labelText:,
  valueText:, onTap:, set:, trailing:)`, `ActionTile(label:, value:,
  onTap:)`, `ButtonTile(child:)`, `IdentityInfoTile(onTap:)` (who is signed
  in), `ProjectLeading(project:)`, `TilePadding(child:)` (16 px sides);
  from `import/import_flutter.dart`: `GoToTile(titleLabel:, subtitleLabel:,
  onTap:)`, `SectionTile(titleLabel:)`, `DelayedDisplay`.
* Progress and dialogs: `LinearWait(showNotifier: saving)` with a
  `ValueNotifier<bool>`, `showUnsavedChangesDialog(context)` returning
  `UnsavedChangesDialogResult.save / discard / cancel` (needs the tkcms
  admin localizations, in the shipped delegates).
* Images: `AdminArticleThumbnail(article:, dbBloc:)`, `ImagePreview(imageId:,
  dbBloc:, maxHeight:)`, `DbImagePreview(image:, projectContext:)`;
  `pickImageFile()` / `pickAnyFile()` (`file_picker/file_picker.dart`,
  `TekalyPickedFile`), `appDownloadImage(DownloadImageInfo)`
  (`download/download_image.dart`).
* Menus: `MenuItem(title:, onPressed:)`, `SubMenuItem(title:, items:)`,
  `MainMenuItem`, then `<MenuItemBase>[...].popupMenu(context)` or
  `PopupSubMenuItem` inside a `PopupMenuButton` (`view/menu.dart`).
  `AttributesTile` / `AdminAttributeTile` edit the cv attributes of an
  article, `CalendarEditTile` / `CalendarFormFieldTile` a date.
* Article edit screens: mix `AdminArticleEditScreenMixin` into the state
  (needs `dbBloc`, `info` with the `articleKind`, `mounted`): `formKey`,
  `saving`, the controllers (`idController`, `nameController`...),
  `getCommonWidgets(article)`, `getBottomCommonWidgets`,
  `getImagesWidget(article, db:)`, `getAttributesTile`, the thumbnail and
  image name / selector / preview tiles, `articleFromForm(article)`,
  `articleMixinDispose()`. Bloc side, `AdminAppProjectScreenBlocBase<State>
  with AdminArticleEditScreenBlocMixin<T>`: `articleStore` and
  `save(AdminArticleEditData(article:, imageData:, thumbailData:))`.
  `AdminArticleScreenMixin` builds the view tiles (`getMarkdownContentTile`,
  `getImagesPreview`, `imagesPopupMenu`). `screen/admin_artist_edit_screen.dart`
  is the template to copy.
* l10n: `festenaoAdminAppIntl(context)` (`l10n/app_intl.dart`),
  `accessText(intl, access)` / `accessString` for a user access
  (`utils/project_ui_utils.dart`).

## Examples

### A project sub screen with its bloc, page def and helper

```dart
import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/route/navigator_def.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/project_root_screen.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';

/// `project/<id>/notes`
class ProjectNotesContentPath extends RootSyncedProjectContentPath {
  final _part = ContentPathPart('notes');

  @override
  List<ContentPathField> get fields => [...super.fields, _part];
}

class NotesBlocState {
  final int infoCount;

  NotesBlocState(this.infoCount);
}

class NotesBloc extends AdminAppProjectScreenBlocBase<NotesBlocState> {
  NotesBloc({required super.projectContext}) {
    () async {
      var db = await projectDb;
      audiAddStreamSubscription(
        dbInfoStoreRef.query().onRecords(db).listen((infos) {
          add(NotesBlocState(infos.length));
        }),
      );
    }();
  }
}

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<NotesBloc>(context);
    return AdminScreenLayout(
      appBar: AppBar(title: const Text('Notes')),
      body: ValueStreamBuilder(
        stream: bloc.state,
        builder: (context, snapshot) =>
            Center(child: Text('${snapshot.data?.infoCount ?? '...'} infos')),
      ),
    );
  }
}

/// Add it to the app's ContentNavigatorDef next to festenaoAdminAppPages.
final projectNotesPageDef = ContentPageDef(
  path: ProjectNotesContentPath(),
  screenBuilder: (crps) {
    var cp = ProjectNotesContentPath()..fromPath(crps.path);
    return BlocProvider(
      blocBuilder: () => NotesBloc(
        projectContext: ByProjectIdAdminAppProjectContext(
          projectId: cp.project.value!,
        ),
      ),
      child: const NotesScreen(),
    );
  },
);

Future<void> goToProjectNotesScreen(
  BuildContext context, {
  required FestenaoAdminAppProjectContext projectContext,
}) => popAndGoToProjectSubScreen(
  context,
  projectContext: projectContext,
  contentPath: ProjectNotesContentPath(),
);
```

### An edit form: fields, validators, progress, unsaved changes

```dart
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/utils/text_validator.dart';
import 'package:festenao_admin_base_app/view/linear_wait.dart';
import 'package:festenao_admin_base_app/view/text_field.dart';
import 'package:festenao_admin_base_app/view/unsaved_changes_dialog.dart';

class NoteEditScreen extends StatefulWidget {
  const NoteEditScreen({super.key});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> with AdminScreenMixin {
  final formKey = GlobalKey<FormState>();
  final saving = ValueNotifier<bool>(false);
  final idController = TextEditingController();
  final titleController = TextEditingController();
  var dirty = false;

  @override
  void dispose() {
    saving.dispose();
    idController.dispose();
    titleController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    var leave =
        !dirty ||
        await showUnsavedChangesDialog(context) ==
            UnsavedChangesDialogResult.discard;
    if (leave && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) {
      return;
    }
    saving.value = true;
    try {
      // Write the record to the project db here.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      dirty = false;
      if (mounted) {
        snack(context, 'Saved');
        Navigator.of(context).pop();
      }
    } finally {
      saving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) => FestenaoAdminAppScaffold(
    appBar: AppBar(
      title: const Text('Note'),
      leading: IconButton(icon: const Icon(Icons.close), onPressed: _close),
    ),
    body: Stack(
      children: [
        Form(
          key: formKey,
          onChanged: () => dirty = true,
          child: ListView(
            children: [
              AppTextFieldTile(
                labelText: 'Id',
                controller: idController,
                validator: fieldIdValidator,
              ),
              AppTextFieldTile(labelText: 'Title', controller: titleController),
              const AppTextFieldTile(
                labelText: 'Content',
                maxLines: 8,
                emptyAllowed: true,
              ),
            ],
          ),
        ),
        LinearWait(showNotifier: saving),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _save,
      child: const Icon(Icons.save),
    ),
  );
}
```

### A tools screen using the shipped tiles and pickers

```dart
import 'package:festenao_admin_base_app/import/import_flutter.dart';
import 'package:festenao_admin_base_app/screen/admin_artists_screen.dart';
import 'package:festenao_admin_base_app/screen/fs_app_users_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_screen.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/identity_info_tile.dart';
import 'package:festenao_admin_base_app/view/info_tile.dart';
// The record models and their `id` extension.
import 'package:festenao_common/data/festenao_db.dart';

class ToolsScreen extends StatelessWidget {
  final String projectId;

  const ToolsScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    var projectContext = ByProjectIdAdminAppProjectContext(
      projectId: projectId,
    );
    return FestenaoAdminAppScaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: ListView(
        children: [
          const IdentityInfoTile(),
          const SectionTile(titleLabel: 'Project'),
          InfoTile(label: 'Project id', value: projectId),
          GoToTile(
            titleLabel: 'Open the project',
            onTap: () => goToProjectRootScreen(context, projectId: projectId),
          ),
          GoToTile(
            titleLabel: 'Pick an artist',
            onTap: () async {
              var result = await selectArtist(
                context,
                projectContext: projectContext,
              );
              var artist = result?.artist;
              if (artist != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(artist.name.v ?? artist.id)),
                );
              }
            },
          ),
          const SectionTile(titleLabel: 'App'),
          GoToTile(
            titleLabel: 'Users of the app',
            onTap: () => goToFsAppUsersScreen(context),
          ),
        ],
      ),
    );
  }
}
```

### A popup menu with a sub menu

```dart
import 'package:festenao_admin_base_app/view/menu.dart';
import 'package:flutter/material.dart';

Widget imageMenu(BuildContext context, {required VoidCallback onDelete}) =>
    <MenuItemBase>[
      MenuItem(title: 'Delete', onPressed: onDelete),
      SubMenuItem(
        title: 'Resize',
        items: [
          MenuItem(title: '320', onPressed: () {}),
          MenuItem(title: '800', onPressed: () {}),
        ],
      ),
    ].popupMenu(context);
```

## Common mistakes

* A project screen reached by url shows nothing: no `ContentPageDef` for
  its content path in the navigator def, only a `goTo` function.
* `showUnsavedChangesDialog` throws on the localizations: the tkcms admin
  delegate is missing from a custom `localizationsDelegates` list.
* A `SwitchListTile` in a `PopupMenuButton` that does not repaint: wrap it
  in a `StatefulBuilder`, as the artists screen does for "Show hidden".
