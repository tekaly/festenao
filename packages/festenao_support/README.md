# Festenao support tools

The dart tools of a festenao app (its support package, `bin/` and `tool/`):
build and deploy menus, a dev menu acting on the firebase project with
admin credentials, the service account store, the assets data build. Never
an app dependency: it runs with admin credentials that bypass the Firestore
rules.

## Getting started

Not on pub.dev, a git dependency of the support package:

```yaml
dependencies:
  festenao_support:
    git:
      url: https://github.com/tekaly/festenao
      path: packages/festenao_support
```

Dart io only (Linux, macOS, Windows; `dart:io`, the admin sdk): not for the
web nor for a Flutter app. A minimal dev menu on the project of the current
firebase folder (`firebase.json` + `.firebaserc`), with the ambient
credentials (`gcloud auth application-default login`):

```dart
import 'package:dev_build/menu/menu_io.dart';
import 'package:festenao_support/festenao_firebase_menu.dart';

void main(List<String> args) {
  var appProject = FestenaoFbAppProject.firebaseFolder(appId: 'my_app');
  mainMenuConsole(args, () {
    menuFestenaoFbAppProjectContent(appProject: appProject);
  });
}
```

The package skills (`skills/`): `festenao-support-app-build`,
`festenao-support-dev-menu`, `festenao-support-firebase-admin`,
`festenao-support-synced-data`.

## Commands

- `festenao_service_account`: stores the service account of the admin builds
  and tools where they look for it, a file of
  `~/.config/tekartik/festenao/service_accounts` and/or the
  `FESTENAO_SERVICE_ACCOUNT` variable of the ds env user file:

  ```sh
  dart run festenao_support:festenao_service_account write ~/Downloads/sa.json --ds-env
  dart run festenao_support:festenao_service_account list
  ```

  See `doc/admin_service_account.md` of the festenao repository, with the
  `.local/service_account_enc.json` a project's support tool writes
  (`festenaoWriteServiceAccountEncFile`) for an admin build.

## Libraries

- `festenao_build_menu_flutter.dart`: build/deploy menus of the flutter apps.
- `festenao_firebase_menu.dart`: dev menu items on a firebase project through
  admin credentials: `firebaseFestenaoMenu` (app users, auth users, projects)
  and the generic `firebaseEntityMenu` for another tkcms entity database
  (an app plugs its own entities in, calendars for example); `menuFestenaoFbAppProjectContent` acts
  on a `FestenaoFbAppProject` at three levels — the auth users, the app
  (`app/<appId>`, where an app admin is granted) and an app project
  (`app/<appId>/project/<projectId>` and its per user access) — finding and
  creating users, granting and revoking access.
- `festenao_firebase_admin_sdk.dart`: firebase initialisation through the admin
  sdk, with a service account map or the ambient credentials.
- `festenao_synced_data.dart`: the assets data build (`buildData`,
  `FestenaoExportLocalBuilder`): the festenao content synced down from
  Firestore and exported as jsonl plus images for an app that ships its
  content (legacy sembast layer, see the `festenao-support-synced-data`
  skill).

## What to know

- Every menu item and `FestenaoFbAppProject` call goes to the real project
  of the credentials, with full privileges: check the project printed when
  the menu opens.
- In the `app project` menu, the selected project is kept when another app
  is picked: select the project again after changing the app.
- `listUsers` and the `list users` items show the first page only (100, or
  `limit`).
