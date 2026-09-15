---
name: festenao-common-server-app
description: >-
  Use when writing or running the backend of a festenao app: a
  FestenaoServerApp (TkAppCmsServerAppBase) built on a TkCmsServerAppContext,
  its initFunctions() (command/callCommand v2 functions, the amp function),
  onCommand dispatch through FestenaoApiHandler.onCommandOrNull
  (FestenaoEntityHandler, FestenaoFirestoreHandler,
  FestenaoObjectStorageHandler), onCronCommand, ApiException errors, the
  local memory server (initFirebaseServicesLocalMemory, functions.serve) and
  the test contexts (initFestenaoTestServerContextAllMemory,
  testFestenaoServerGroup, FestenaoServerAppTest).
---

# festenao_common server app

The backend of a festenao app is one class, a `FestenaoServerApp`, that owns
the `FirebaseFunctions` of its runtime and answers the secured api commands
(`command` http function, `callCommand` callable) plus an AMP http function.
The same class runs on the deployed Cloud Functions (node or admin sdk
runtime), on a local http server, and in memory for the tests.

## Guidelines

* Import `package:festenao_common/festenao_server.dart`: `FestenaoServerApp`,
  `FestenaoEntityHandler` and the whole tkcms server layer
  (`TkCmsServerAppContext`, `TkCmsServerAppV2`, `ApiRequest`, `ApiResult`,
  `ApiError`, `ApiException`, `HttpsErrorCode`, `regionBelgium`). The other
  handlers have their own imports:
  `package:festenao_common/server/festeano_server_firestore_handler.dart`,
  `package:festenao_common/server/festeano_server_object_storage_handler.dart`.
* Build the app from a `TkCmsServerAppContext(firebaseContext:,
  flavorContext:)`: `FestenaoServerApp(app: 'myapp', context: context,
  version:)`. `app` is the firestore app id (`app/<app>`), exposed with the
  `appFlavorContext` (`AppFlavorContext`); `firebaseContext` gives
  `firestore`, `auth`, `storage`, `functions`; `flavorContext` is one of
  `FlavorContext.dev`, `devx`, `prod`, `prodx`, `test`.
* `initFunctions()` fills `functions[name]`: the api command function
  (`command`, `commandv2dev` in dev, `commandv2` in prod), the callable
  (`callCommand`), and `amp` (`ampdev` in dev, `amp` in prod). A subclass
  adds its own after `super.initFunctions()`, suffixing the name with
  `flavorContext.ifNotProdFlavor` like the others. Call it once, before
  serving or exporting the functions.
* Dispatch: override `onCommand(apiRequest)` and ask each handler in turn,
  `await handler.onCommandOrNull(apiRequest)` (a `FestenaoApiHandler`
  returns null for a command it does not know), then fall back to
  `super.onCommand` (echo, info, timestamp, secured, `cron`, `auth/me`),
  which throws `UnsupportedError` for an unknown command. Handlers:
  `FestenaoEntityHandler<T>` (`entity/<type>/...`),
  `FestenaoFirestoreHandler(options: FestenaoFirestoreHandlerOptions(firestore:))`
  (`firestore/get`, `firestore/set`, `firestore/delete`, the raw document
  api of the dashboard tools), `FestenaoObjectStorageHandler` (`gdrive/...`).
* A command handler reads `apiRequest.command.v` (`apiCommand`), `app.v`
  (the app id sent by the client), `userId.v` (the verified firebase user,
  null when signed out) and its typed query with
  `apiRequest.query<MyQuery>()`; it returns an `ApiResult` model. Refuse
  with `throw (ApiError()..code.v = HttpsErrorCode.permissionDenied
  ..message.v = '...'..noRetry.v = true).exception()`: the client gets an
  `ApiException` with that code (`permission-denied`, `unauthenticated`,
  `internal_error`...). `noRetry` stops the client's retry loop.
* In a subclass, qualify the inherited `firestore`, `firebaseContext`,
  `app` and `appFlavorContext` with `this.` (in field initializers and
  closures above all): tkcms exports library level names of the same
  spelling, a deprecated global `firebaseContext` among them, and Dart
  resolves an unqualified identifier to the library scope before an
  inherited member, so `firestore.doc(...)` may silently hit another
  instance.
* `onCronCommand(apiRequest)` answers `cron` (called daily by the
  scheduler): the base purges deleted projects and expired invites through
  `FestenaoFirestoreDatabase.projectDb`; an app with its own entities
  overrides it and calls `purgeDeletedEntities()` and `deleteOldInvites()`
  on each entity access.
* Local server: `initFirebaseServicesLocalMemory(projectId:)` (or
  `initFirebaseServicesLocalSembast(databaseFactory:, projectId:)` for a
  persistent one) then `await ....initServer()` gives the server side
  `FirebaseContext`; `app.initFunctions()`; `var ffServer = await
  ffContext.functions.serve()` listens on the memory port 4999
  (`ffServer.uri`, one server per process: `close()` it). A client in the
  same process uses `httpClientFactoryMemory` (exported by
  `festenao_api.dart`) and `ffServer.uri.replace(path: app.command)` as
  `httpsApiUri`, or the `functionsCall` of a client context built with
  `.init(firebaseApp:, ffServer:, serverApp:)`. Import
  `package:festenao_common/festenao_firebase.dart` for the local services
  and `festenao_flavor.dart` for `FlavorContext`.
* Tests: `initFestenaoTestServerContextAllMemory()` (import
  `package:festenao_common/test/festenao_test_server_test_runner.dart`)
  does all of the above with a `FestenaoServerAppTest` (project entity,
  firestore doc and object storage handlers) and returns a
  `FestenaoTestServerContext`: `apiService`, `projectApiClient`,
  `fsDatabase`, `ffContext` (`ffContext.serverApp` is the server),
  `clientContext.firebaseAuth`, `close()`. `testFestenaoServerGroup(init)`
  runs the standard suite (amp, timestamp, echo, entity commands) on any
  context builder, memory or emulator.

## Examples

### An app with its own command and handlers

```dart
import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/server/festeano_server_firestore_handler.dart';

/// `{ "text": "..." }` in, `{ "text": "..." }` out.
class ApiShoutQuery extends ApiQuery {
  final text = CvField<String>('text');

  @override
  CvFields get fields => [text];
}

class ApiShoutResult extends ApiResult {
  final text = CvField<String>('text');

  @override
  CvFields get fields => [text];
}

const commandShout = 'shout';

class MyServerApp extends FestenaoServerApp {
  MyServerApp({required super.context}) : super(app: 'myapp') {
    cvAddConstructors([ApiShoutQuery.new, ApiShoutResult.new]);
  }

  // `this.`: tkcms exports same-named globals (a deprecated
  // `firebaseContext` among them) and an unqualified name resolves to the
  // library level one before an inherited member.
  late final fsDatabase = FestenaoFirestoreDatabase(
    firebaseContext: this.firebaseContext,
    flavorContext: this.appFlavorContext,
  );

  late final projectHandler = FestenaoEntityHandler(
    app: this,
    entityAccess: fsDatabase.projectDb,
  );

  late final firestoreHandler = FestenaoFirestoreHandler(
    options: FestenaoFirestoreHandlerOptions(firestore: this.firestore),
  );

  @override
  Future<ApiResult> onCommand(ApiRequest apiRequest) async {
    for (var handler in [projectHandler, firestoreHandler]) {
      var result = await handler.onCommandOrNull(apiRequest);
      if (result != null) {
        return result;
      }
    }
    switch (apiRequest.apiCommand) {
      case commandShout:
        if (apiRequest.userId.v == null) {
          throw (ApiError()
                ..code.v = HttpsErrorCode.unauthenticated
                ..message.v = 'Sign in first'
                ..noRetry.v = true)
              .exception();
        }
        var query = apiRequest.query<ApiShoutQuery>();
        return ApiShoutResult()..text.v = query.text.v!.toUpperCase();
      default:
        return super.onCommand(apiRequest);
    }
  }

  @override
  Future<ApiResult> onCronCommand(ApiRequest apiRequest) async {
    await fsDatabase.projectDb.purgeDeletedEntities();
    await fsDatabase.projectDb.deleteOldInvites();
    return ApiEmpty();
  }
}
```

### Serving it in memory and calling it

```dart
import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firebase.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:tkcms_common/tkcms_auth.dart';

Future<void> main() async {
  var services = initFirebaseServicesLocalMemory(projectId: 'demo');
  var serverContext = await services.initServer();
  var app = MyServerApp(
    context: TkCmsServerAppContext(
      firebaseContext: serverContext,
      flavorContext: FlavorContext.dev,
    ),
  );
  app.initFunctions();
  var ffServer = await serverContext.functions.serve();

  // A client in the same process, on the same memory firebase.
  var clientContext = await services.init(
    firebaseApp: serverContext.firebaseApp,
    ffServer: ffServer,
    serverApp: app,
  );
  await clientContext.auth.signInOrUpWithEmailAndPassword(
    email: 'test',
    password: 'test',
  );
  var apiService = FestenaoApiService(
    app: 'myapp',
    httpClientFactory: httpClientFactoryMemory,
    httpsApiUri: ffServer.uri.replace(path: app.command),
    callableApi: clientContext.functionsCall.callable(app.callCommand),
  );
  await apiService.initClient();
  var result = await apiService.getApiResult<ApiShoutResult>(
    ApiRequest(command: commandShout)..setQuery(ApiShoutQuery()..text.v = 'hi'),
  );
  print(result.text.v); // HI
  await apiService.close();
  await ffServer.close();
}
```

### The standard suite on a memory server

```dart
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:test/test.dart';

void main() {
  group('memory server', () {
    testFestenaoServerGroup(initFestenaoTestServerContextAllMemory);
  });
}
```

## Common mistakes

* Registering functions before `initFunctions()` or forgetting to call it:
  `command` and `callCommand` are `late`, reading them throws.
* Returning null from `onCommand` for an unknown command instead of
  `super.onCommand`: the base handles echo, info, timestamp and the secured
  envelope, and throws a clear `UnsupportedError` otherwise.
* Throwing a plain `StateError` for a refusal: the client sees
  `internal_error` and retries. Throw an `ApiError` with a code and
  `noRetry`.
* Building two `FestenaoFirestoreDatabase` instances with different app ids
  on the server and the client of a test: the api writes under the server's
  `appFlavorContext.app`, whatever the client sends as `app`.
