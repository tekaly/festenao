# festenao_common

The pure Dart core of the festenao apps (festival and event sites, their
admin and orga apps), built on
[tkcms_common](https://github.com/tekartikprj/tkcms/tree/main/packages/tkcms_common):

- the Firestore entities (projects, user access, invites, user plans, slugs)
  and the secured api that creates and shares them,
- the backend: `FestenaoServerApp`, the cloud functions of an app (api
  commands, cms sites, cron), run deployed, on a local server or in memory,
- the local databases of the apps (sdb, synced with Firestore), the media and
  object storage (Firebase Storage, Google Drive, file system, sdb cache),
- features: a mini CMS (`festenao_cms.dart`), a timed quiz
  (`festenao_quizz.dart`), forms, logs, the file system and object explorers.

No Flutter: the widgets are in `festenao_common_flutter` and the
`packages_flutter` folder of [festenao](https://github.com/tekaly/festenao).

## Getting started

A git package (not on pub.dev), in `pubspec.yaml`:

```yaml
dependencies:
  festenao_common:
    git:
      url: https://github.com/tekaly/festenao
      path: packages/festenao_common
```

It depends on other git packages (tkcms, tekaly, tekartik firebase...):
`dart pub get` fetches them all.

A server and a client in memory: create a project, invite a guest, publish
it ([example/main.dart](example/main.dart) is the complete version):

```dart
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:tkcms_common/tkcms_auth.dart';

/// Run with asserts (`dart --enable-asserts`, as `dart test` does): the
/// memory callable passes the signed in user to the server in debug only.
Future<void> main() async {
  // A FestenaoServerApp on a memory firebase, and its api client.
  var context = await initFestenaoTestServerContextAllMemory();
  var auth = context.clientContext.firebaseAuth!;
  var client = context.projectApiClient;

  await auth.signInOrUpWithEmailAndPassword(
    email: 'owner@test.local',
    password: 'test1234',
  );
  var project = await client.createEntity(entity: FsProject()..name.v = 'Demo');
  var inviteId = await client.createEntityInvite(
    entityId: project.id,
    fsUserAccess: TkCmsFsUserAccess()..read.v = true,
  );
  print('invite $inviteId');
  // The creator is an admin of the project: it may publish it.
  print(await client.setEntityPublic(entityId: project.id, public: true));
  await context.close();
}
```

## Platforms

Every library compiles on the Dart VM, the web (dart2js and dart2wasm) and
Flutter. What needs `dart:io` at run time: the file system object storage
(`ObjectStorageFs` on an io file system), the service account lookup
(`firebase/festenao_service_account_io.dart`), the rest auth through a
service account (`festenao_firebase_rest.dart`), the admin sdk server
(`server/festenao_server_admin_sdk.dart`) and the local io server. The
memory backends (`firebase/firebase_memory.dart`,
`initFestenaoTestServerContextAllMemory`) run everywhere: use them in tests.

## Main libraries

| Import | What |
|---|---|
| `festenao_api.dart` | api client (`FestenaoApiService`, `FestenaoApiFsEntityClient`), commands and models, user plans, app status |
| `festenao_server.dart` | `FestenaoServerApp`, `FestenaoEntityHandler`, user plans, app status, email invites |
| `firebase/firestore_database.dart` | `FestenaoFirestoreDatabase`, `FsProject`, the project entity access |
| `festenao_firebase.dart`, `firebase/firebase_memory.dart` | firebase contexts (io, rest, memory, sim) |
| `festenao_sdb.dart`, `data/festenao_projects_sdb.dart` | project content databases (sdb), the user project list, the copy engine |
| `data/object_storage.dart` | `ObjectStorage`: Firebase Storage, Google Drive, file system, sdb and its cache |
| `festenao_cms.dart`, `server/festenao_server_cms.dart` | the mini CMS and the `cms` function |
| `festenao_quizz.dart` | the quiz models, database, player and its server clock |
| `festenao_slug.dart` | the human readable urls of the projects and their registry |
| `log/log.dart` | `FestenaoLogger`, storages (memory, sdb, fs, hybrid), transports |
| `fs/file_system_explorer.dart` | browse and open json, yaml, sembast and sdb files |

`festenao_sembast.dart` and `data/festenao_db.dart` are the legacy sembast
layer of the older apps: new code uses sdb (`festenao_sdb.dart`,
`FestenaoSyncedSdb`).

## What to know

- A client id (a project, a quiz, a session) is checked before it goes into a
  Firestore or Storage path on the server (`tkCmsCheckDocumentId`): new
  handlers do the same.
- Secured commands (tkcms) are an anti abuse speed bump, not a security
  boundary: a command that matters checks the signed in user (the callable
  carries it) on the server.
- One memory firebase per process (`initFestenaoTestServerContextAllMemory`,
  `initFirebaseServicesLocalMemory`): the memory http port and the local apps
  are process wide; `dart test` runs each test file in its own process.
- The quiz clock (`QuizzTimeService`) measures the offset with the server;
  call `dispose()` to stop its timers.
- `FestenaoLogger.close()` flushes what is not sent yet and closes the
  storage: await it before exiting.

## More

- Skills (also good reading for people): `skills/festenao-common-*/SKILL.md`
  (server app, entity api, firebase context, object storage, content copy,
  quizz).
- Design notes: [doc/](doc/) (logs, firestore backup, file system and object
  explorers, admin explorer).
- The Firestore rules of these entities, as code and tested: `festenao_firebase`.
