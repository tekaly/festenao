---
name: festenao-common-entity-api
description: >-
  Use when an app built on festenao_common creates, shares or publishes CMS
  entities (projects, or the app's own TkCmsFsEntity type) through the secured
  api: FestenaoApiFsEntityClient (createEntity, deleteEntity, purgeEntity,
  joinEntity, leaveEntity, createEntityInvite, acceptEntityInvite,
  deleteEntityInvite, setEntityPublic), the entity/<type>/... commands, and
  the server side FestenaoEntityHandler with FestenaoEntityHandlerOptions
  (customIdGenerator, setPublicCheck) inside a FestenaoServerApp.
---

# festenao_common entity api

An entity is a firestore document with per user access rows (`TkCmsFsEntity`
and `TkCmsFsUserAccess` from tkcms). Creating one, granting access to it and
opening it to everybody go through the api cloud function: the firestore
rules only grant a client what an access document already says, and only the
server writes those. `festenao_common` ships both ends of that api for any
entity type: the client `FestenaoApiFsEntityClient<T>` and the server handler
`FestenaoEntityHandler<T>`, generic over the entity model `T`.

## Guidelines

* Imports: `package:festenao_common/festenao_api.dart` (client, command
  names, queries, results, `FestenaoApiService`, the tkcms api base) and
  `package:festenao_common/festenao_firestore.dart` (entity models, access
  services, `fsAppRoot`). Server side add
  `package:festenao_common/festenao_server.dart` (`FestenaoServerApp`,
  `FestenaoEntityHandler`, tkcms server). Never import `src/`.
* One `TkCmsFirestoreDatabaseServiceEntityAccess<T>(entityCollectionInfo:,
  firestore:, rootDocument: fsAppRoot(appId))` per entity type on each side.
  The `TkCmsFirestoreDatabaseEntityCollectionInfo<T>` `id` is the entity
  type (`project` for `FsProject`, festenao's own entity). The client access
  converts the api json back into a `T`; the server access reads and writes
  firestore. Register the models first, once: `initFestenaoFsBuilders()` (or
  `initTkCmsFsBuilders()` plus `cvAddConstructor` for the app's own types)
  and `initFestenaoFsEntityApiBuilders<T>()`.
* Commands are `entity/<type>/<action>` with the actions `create`, `delete`,
  `purge`, `join`, `leave`, `create-invite`, `accept-invite`,
  `delete-invite` and `set-public`: `entityAccess.info.createCommand` and
  friends (`FestenaoFirestoreDatabaseEntityCollectionInfoApiExt`), or
  `festenaoEntityCreateCommand(type)`. The handler also accepts the legacy
  `<type>-create-entity` spelling.
* `FestenaoApiFsEntityClient(apiService:, entityAccess:)` (any
  `TkCmsApiServiceBaseV2`: `FestenaoApiService` or an app's own service):
  `createEntity(entity:, entityId:)` returns the `T` read back with its id,
  the caller being its admin. `deleteEntity` marks it deleted (the daily cron
  purges), `purgeEntity` removes it for good, `leaveEntity` drops the
  caller's own access row, `joinEntity(fsUserAccess:)` adds it for an app
  that lets users join on their own; all take `entityId:`.
  `createEntityInvite(entityId:, fsUserAccess:, email:)` returns the invite
  id; with an `email` only a user with that email can accept.
  `acceptEntityInvite(entityId:, inviteId:, email:)` grants the invite's
  access to the caller, `deleteEntityInvite` revokes it.
  `setEntityPublic(entityId:, public:)` writes (or deletes) the
  `public_access/public` flag that lets anyone read the entity subtree and
  returns the resulting state.
* Access is a `TkCmsFsUserAccess`: `read`, `write`, `admin` bool fields
  (`grantAdminAccess()` sets the three), `role`. Read it back from firestore,
  not from the api: `entityAccess.fsEntityUserAccessRef(entityId, userId)
  .get(firestore)` (`exists`, `admin.v`), and the flag with
  `isEntityPublic(entityId)` or the live `onEntityPublic(entityId)`.
* A refused command throws an `ApiException` on the client whose
  `error?.code.v` is `permission-denied` (not an admin, `setPublicCheck`
  said no), `unauthenticated` or `internal_error` (`Missing userId`) when
  nobody is signed in. Every entity command needs a signed in user: the api
  carries the verified `userId` of the firebase auth token. The invite email
  is client supplied, a convenience check, not an authentication.
* Server side, one `FestenaoEntityHandler<T>(app:, entityAccess:, options:)`
  per entity type, asked from `onCommand` through `onCommandOrNull`, which
  returns null for a command it does not know. Options: `customIdGenerator`
  (the id of a created entity, a firestore auto id otherwise) and
  `setPublicCheck` (`({required userId, required entityId}) async => bool`,
  an app level privilege on top of being an admin of the entity; `false`
  refuses with `permission-denied`).
* Tests: `initFestenaoTestServerContextAllMemory()` (import
  `package:festenao_common/test/festenao_test_server_test_runner.dart`)
  boots a memory firebase with a `FestenaoServerAppTest` handling the
  project entity, and hands out `projectApiClient`, `fsDatabase.projectDb`
  and `clientContext.firebaseAuth` (sign in with
  `signInOrUpWithEmailAndPassword` from `package:tkcms_common/tkcms_auth.dart`).
  The memory firestore has no rules: only the api checks are exercised.
  `entitySetPublicApiTestRunner` (import
  `package:festenao_common/test/entity_set_public_api_test_runner.dart`)
  is the shared suite of `set-public` for any entity type and deployment:
  give it an `EntitySetPublicApiTestContext` (two sign in callbacks, create
  and purge, the client, `privilegeRequired` and, when writable from a test,
  `setPublishPrivilege`) inside a group of the app's server suite.

## Examples

### A client against a deployed api

```dart
import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:tekartik_app_http/app_http.dart';

/// [firestore] and [functionsCall] come from the app's firebase context.
FestenaoApiFsEntityClient<FsProject> projectClient({
  required Firestore firestore,
  required FirebaseFunctionsCall functionsCall,
  required String appId,
}) {
  initFestenaoFsBuilders();
  initFestenaoFsEntityApiBuilders<FsProject>();
  var apiService = FestenaoApiService(
    app: appId,
    httpClientFactory: httpClientFactoryUniversal,
    httpsApiUri: Uri.parse('https://commandv2dev-xxxx-ew.a.run.app'),
    callableApi: functionsCall.callableFromUri(
      Uri.parse('https://callcommandv2dev-xxxx-ew.a.run.app'),
    ),
  );
  return FestenaoApiFsEntityClient<FsProject>(
    apiService: apiService,
    entityAccess: TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>(
      entityCollectionInfo: projectCollectionInfo,
      firestore: firestore,
      rootDocument: fsAppRoot(appId),
    ),
  );
}
```

### Create, invite, publish (memory server)

```dart
import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:tkcms_common/tkcms_auth.dart';

Future<void> main() async {
  var context = await initFestenaoTestServerContextAllMemory();
  var auth = context.clientContext.firebaseAuth!;
  var client = context.projectApiClient;
  var projectDb = context.fsDatabase.projectDb;

  await auth.signInOrUpWithEmailAndPassword(
    email: 'owner@test.local',
    password: 'test1234',
  );
  var project = await client.createEntity(entity: FsProject()..name.v = 'Demo');
  var inviteId = await client.createEntityInvite(
    entityId: project.id,
    fsUserAccess: TkCmsFsUserAccess()
      ..read.v = true
      ..write.v = true,
  );
  // The creator is an admin of the project: it may publish it.
  var isPublic = await client.setEntityPublic(
    entityId: project.id,
    public: true,
  );
  print('public: $isPublic'); // true

  await auth.signOut();
  await auth.signInOrUpWithEmailAndPassword(
    email: 'guest@test.local',
    password: 'test1234',
  );
  await client.acceptEntityInvite(entityId: project.id, inviteId: inviteId);
  var access = await projectDb
      .fsEntityUserAccessRef(project.id, auth.currentUser!.uid)
      .get(projectDb.firestore);
  print('guest may write: ${access.write.v}, admin: ${access.admin.v}');

  // A writer is not an admin: publishing is refused.
  try {
    await client.setEntityPublic(entityId: project.id, public: false);
  } on ApiException catch (e) {
    print(e.error?.code.v); // permission-denied
  }
  await context.close();
}
```

### The server side of an app's own entity type

```dart
import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/firebase/firestore_database.dart';

class FsBooklet extends TkCmsFsEntity {
  final description = CvField<String>('description');

  @override
  CvFields get fields => [...super.fields, description];
}

final bookletCollectionInfo =
    TkCmsFirestoreDatabaseEntityCollectionInfo<FsBooklet>(
      id: 'booklet',
      name: 'Booklet',
      treeDef: tkCmsSyncedTreeDef,
    );

class BookletServerApp extends FestenaoServerApp {
  BookletServerApp({required super.context}) : super(app: 'booklets') {
    initTkCmsFsBuilders();
    cvAddConstructor(FsBooklet.new);
    initFestenaoFsEntityApiBuilders<FsBooklet>();
  }

  late final bookletDb = TkCmsFirestoreDatabaseServiceEntityAccess<FsBooklet>(
    entityCollectionInfo: bookletCollectionInfo,
    firestore: firestore,
    rootDocument: fsAppRoot(app),
  );

  late final bookletHandler = FestenaoEntityHandler<FsBooklet>(
    app: this,
    entityAccess: bookletDb,
    options: FestenaoEntityHandlerOptions(
      // Publishing takes an app level privilege on top of being an admin.
      setPublicCheck: ({required userId, required entityId}) async {
        var rights = await firestore.doc('app/$app/user_access/$userId').get();
        return rights.exists && rights.data['publish'] == true;
      },
    ),
  );

  @override
  Future<ApiResult> onCommand(ApiRequest apiRequest) async {
    return await bookletHandler.onCommandOrNull(apiRequest) ??
        await super.onCommand(apiRequest);
  }
}
```

## Common mistakes

* Writing an entity or an access document from the client: the rules refuse
  it (`permission-denied`), and a memory firestore silently accepts what a
  deployment never will. Go through the api.
* Building the client access with another `rootDocument` than the server's
  `fsAppRoot(app)`: the api works, but every direct read of what it wrote
  misses.
* Forgetting `initFestenaoFsEntityApiBuilders<T>()` for the app's own `T`:
  the result decodes to a generic model and `createEntity` returns an
  empty entity.
* Expecting `setEntityPublic` to work for a writer or a reader: only an
  admin of the entity may publish, whatever the app's `setPublicCheck` says.
