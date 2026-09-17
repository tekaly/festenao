---
name: festenao-support-dev-menu
description: >-
  Use when building the console dev menu of a festenao support tool with
  festenao_support: mainMenuConsole, menu/item/enter/write/showMenu/popMenu,
  the remembered variables (kvFromVar, keyValuesMenu, kvFestenaoProject),
  menuFestenaoFbAppProjectContent (the three level menu over a
  FestenaoFbAppProject) and firebaseFestenaoMenu / firebaseEntityMenu, the
  generic entity menu another tkcms entity database plugs into.
---

# festenao_support dev menu

A festenao support tool is a console menu: a tree of named items run from the
terminal, with the selection (app, project, user) remembered between runs in
variables. `festenao_support` ships the festenao branches of that tree, over
a `FestenaoFbAppProject` (`festenao-support-firebase-admin`), so a tool is a
`main` that builds the project and declares the menu.

## Guidelines

* Imports: `package:festenao_support/festenao_firebase_menu.dart` — it
  re-exports `package:tekartik_app_dev_menu/dev_menu.dart`, so
  `mainMenuConsole`, `menu`, `item`, `enter`, `write`, `writeln`, `showMenu`,
  `popMenu`, `keyValuesMenu` and `kvFromVar` come with it. Never import
  `src/`.
* `mainMenuConsole(args, () { ... })` is the entry point; inside, `menu(name,
  body)` opens a sub menu and `item(name, action)` runs one action. `enter(()
  async { ... })` runs when a menu is entered — print what is selected there.
  `showMenu(() { ... })` pushes a menu built on the fly (a list of entities to
  pick from) and `popMenu()` leaves it once the choice is made.
* A remembered variable is `'fao_app_id'.kvFromVar()`: `.value` reads it,
  `.set(value)` writes it, and `keyValuesMenu('vars', [kv1, kv2])` adds the
  menu that shows and edits them. `kvFestenaoProject` (`fao_project`) is the
  shared one for the selected festenao project.
* `menuFestenaoFbAppProjectContent(appProject:, projectId:,
  onAppIdSelected:, onProjectIdSelected:)` is the whole three level menu:
  the auth users of the firebase project (find by email, create, select), the
  app (`app/<appId>`: its user access rows, granting an app admin) and an app
  project (its entity, its per user access, granting and revoking). Pass the
  two callbacks to persist what was picked, as the festenaoprv admin menu
  does.
* `firebaseFestenaoMenu(appFlavorContext, firebaseContext, fsDatabase:)`
  lists what an already initialised context reaches: the app users, the auth
  users and the projects of the app.
* `firebaseEntityMenu<T>(firebaseContext:, entityDb:, entityName:, appDb:,
  appId:, kvEntityId:, limit:, entityMenu:)` is its generic form for any
  tkcms entity type — calendelio plugs its calendars in with `entityName:
  'calendar'`. It adds `list users`, `list auth users`, `list <entity>s`,
  `current <entity>` (its users, its sub collections, plus what `entityMenu`
  adds), `select <entity>` and `vars`.
* The context is built on first use, so a menu declaration costs no network
  call: build the `FestenaoFbAppProject` (or the firebase context) before
  `mainMenuConsole` and let the first item touch it.
* A tool that needs no firebase folder and no gcloud login builds the project
  from a service account map and can be globally activated
  (`dart pub global activate --source path .`).

## Examples

### A standalone admin menu

```dart
/// The festenao admin menu, the entry point of this package.
///
/// ```sh
/// dart run festenaoprv_support
/// ```
library;

import 'dart:async';

import 'package:festenao_support/festenao_firebase_menu.dart';
import 'package:festenaoprv_common/festenaoprv_constant.dart';
import 'package:festenaoprv_common/firebase_io.dart';

/// The app id the menu acts on, remembered between runs.
var kvAppId = 'fao_app_id'.kvFromVar();

/// The project id the menu acts on, remembered between runs.
var kvProjectId = kvFestenaoProject;

Future<void> main(List<String> args) async {
  var appProject = FestenaoFbAppProject.serviceAccountMap(
    appId: kvAppId.value ?? festenaoPrvAppDev,
    serviceAccountMap: festenaoFreeDevServiceAccountMap,
  );

  mainMenuConsole(args, () {
    menuFestenaoFbAppProjectContent(
      appProject: appProject,
      projectId: kvProjectId.value,
      // Picking an app or a project in the menu keeps it for the next run.
      onAppIdSelected: (appId) => unawaited(kvAppId.set(appId)),
      onProjectIdSelected: (projectId) => unawaited(kvProjectId.set(projectId)),
    );
    keyValuesMenu('vars', [kvAppId, kvProjectId]);
  });
}
```

### Another entity type in the generic menu

```dart
import 'package:festenao_support/festenao_firebase_menu.dart';

/// The calendars of the app, with one extra action on the selected one.
void calendarMenu({
  required FirebaseContext firebaseContext,
  required TkCmsFirestoreDatabaseServiceEntityAccess<FsCalendar> calendarDb,
  required String appId,
}) {
  firebaseEntityMenu<FsCalendar>(
    firebaseContext: firebaseContext,
    entityDb: calendarDb,
    entityName: 'calendar',
    appId: appId,
    entityMenu: (calendar) {
      item('print events', () async {
        write('${calendar.id}: ${calendar.name.v}');
      });
    },
  );
}
```

### A menu of one's own, over the same project

```dart
import 'package:festenao_support/festenao_firebase_menu.dart';

void usersMenu(FestenaoFbAppProject appProject) {
  menu('users', () {
    enter(() async => write('App: ${appProject.appId ?? '<none>'}'));
    item('list', () async {
      for (var user in await appProject.listUsers(maxResults: 50)) {
        write('- ${user.uid}: ${user.email}');
      }
    });
    item('grant app admin', () async {
      var users = await appProject.listUsers(maxResults: 50);
      await showMenu(() {
        for (var user in users) {
          item(user.email ?? user.uid, () async {
            await appProject.grantAppAdmin(user.uid, name: user.email);
            write('granted');
            popMenu();
          });
        }
      });
    });
  });
}
```

## Common mistakes

* Initialising firebase before `mainMenuConsole`: the menu then takes a
  network round trip to show up, and fails to start when the credentials are
  wrong instead of saying so on the first item. Build the
  `FestenaoFbAppProject` (lazy) and let the item do the work.
* Forgetting `onAppIdSelected` / `onProjectIdSelected`: the selection is lost
  on the next run, and every session starts with `select app`.
* Acting on a level before selecting it: the calls throw a `StateError`
  naming the item to run first (`select app`, `select project`,
  `find user by email`) — catch nothing, read the message.
* Using the menus in an app: they are admin credential tools, for `bin/` and
  `tool/` only.
