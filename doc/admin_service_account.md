# Admin builds and tools: the service account and the apps

An admin build (the linux `main_admin_sdk.dart` of a dashboard, for
instance) or a support tool runs as the firebase project itself, through a
service account. This is how it finds one, and what it does with the apps.

## Where the service account comes from

Never from the code. In this order:

1. `FESTENAO_SERVICE_ACCOUNT`: the json itself, or the path of a json file
   (`~/` allowed). Read from the process environment, then from the ds env
   user file (`~/.config/tekartik/process_run/env.yaml` on linux, what
   `ds env var set` writes), so it works from a terminal, an IDE launch
   configuration, or neither.
2. The files of `~/.config/tekartik/festenao/service_accounts`, one
   `<project_id>.json` per firebase project (a file the variable points to is
   counted once).
3. In an admin build only: pasted in its *Credentials* screen, kept in a local
   sdb database. The first two are copied there at start
   (`adminCredentialsImportFound`), the variable selected when it is set.

Everything is stored unencrypted: it is for a developer machine.

## Storing it: `festenao_service_account`

The command of `festenao_support` writes the file and/or the ds env variable:

```sh
cd festenao/packages/festenao_support
# The file (mode 600), and the ds env variable pointing to it.
dart run festenao_support:festenao_service_account write ~/Downloads/sa.json --ds-env
# The json in the ds env variable only, read from the clipboard.
xclip -o | dart run festenao_support:festenao_service_account write - --no-file --ds-env
# What is found: project, account, key id and source, never the key.
dart run festenao_support:festenao_service_account list
# Removes the file, and the variable when it is this project's.
dart run festenao_support:festenao_service_account delete my-project
dart run festenao_support:festenao_service_account unset
```

The ds env value is written quoted, so a json stays a string in the yaml
file. Nothing else of the ds env file is printed.

## Running the admin build

```sh
cd festenaoprv/packages_flutter/festenaoprv_dashboard_app
FESTENAO_SERVICE_ACCOUNT=~/Downloads/sa.json flutter run -d linux -t lib/main_admin_sdk.dart
# or, once the command above was run:
flutter run -d linux -t lib/main_admin_sdk.dart
```

It reaches firebase through the admin sdk (`festenaoAdminFirebaseAdminSdk`),
the start page saying what was found on the machine. *Admin* then offers:

- **Apps**: every app of the project, the ones without an `app/<appId>`
  document included (the admin sdk lists them; the rest apis only see the
  existing documents). An app shows its users and its projects; a project its
  users.
- **Users explorer**: the auth users; *Access to the apps* on a user lists
  every app and project access they have.
- Firestore, file system, sembast and sdb explorers.

## The access an app admin is

The server (`FestenaoEntityHandler`) and the apps check the tkcms entity
access, written on both sides:

- entity side `access/app/entity_id/<appId>/user_access/<userId>`;
- user side `access/app/user_id/<userId>/entity_access/<appId>`;
- for a project, the same below `app/<appId>`.

A grant (`FestenaoUserAccessGrant`) is `read`, `write`, `admin` (read, write,
admin) or `super admin` (admin plus the `superAdmin` role); changing it
resets the rights and the role, keeping the name and the email.
`FestenaoAppsAdmin` (`festenao_common/admin/festenao_apps_admin.dart`) does
all of it, for the screens and for a tool:

```dart
var account = await festenaoServiceAccountFromEnv();
var context = await festenaoAdminFirebaseAdminSdk.initWithServiceAccount(
  account!.map,
);
var firestore = context.firestore;
var admin = FestenaoAppsAdmin(
  firestore: firestore,
  listDocumentIds: (path) =>
      festenaoAdminFirebaseAdminSdk.listDocumentIds(firestore, path),
);
await admin.setUserAccess(
  admin.appAccess,
  'festenao-dev',
  userId,
  grant: FestenaoUserAccessGrant.superAdmin,
  email: 'me@example.com',
);
```

`app/<appId>/user_access/<userId>` is the legacy app access (the
`grantAppAdmin` of `FestenaoFbAppProject`, `FestenaoAppUserAccessScreen`);
the app screen still links it, under *Legacy app access*.
