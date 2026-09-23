---
name: festenao-common-server-app
description: >-
  Use when writing or running the backend of a festenao app: a
  FestenaoServerApp (TkAppCmsServerAppBase) built on a TkCmsServerAppContext,
  its initFunctions() (command/callCommand v2 functions, the amp function,
  the cms site function cms / cmsdev and its hooks cmsSiteOf,
  cmsSiteProject, cmsSiteHandler, handleCmsRequest, cmsContentSdbOptions),
  isAppAllowed, onCommand dispatch through FestenaoApiHandler.onCommandOrNull
  (FestenaoEntityHandler, FestenaoFirestoreHandler,
  FestenaoObjectStorageHandler), onCronCommand, ApiException errors, the
  local memory server (initFirebaseServicesLocalMemory, functions.serve) and
  the test contexts (initFestenaoTestServerContextAllMemory,
  testFestenaoServerGroup, FestenaoServerAppTest).
---

# festenao_common server app

The backend of a festenao app is one class, a `FestenaoServerApp`, that owns
the `FirebaseFunctions` of its runtime and answers the secured api commands
(`command` http function, `callCommand` callable), serves the cms sites of
its projects (`cms` http function) plus an AMP http function.
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
  (`command`, `commandv2dev` in dev, `commandv2prod` in prod), the callable
  (`callCommand`, `callcommandv2dev` / `callcommandv2prod`) and `amp`
  (`ampdev` in dev, `amp` in prod); `initCmsFunction()`, called after it,
  adds `cmsCommand` (`cmsdev` in dev, `cms` in prod). A subclass
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
* In a subclass write `this.firebaseContext`: `festenao_firebase.dart`
  (through tkcms) exports a deprecated library level `firebaseContext`
  getter, and Dart resolves an unqualified name to the library scope before
  an inherited member, so the bare name reads (and throws on) that global.
  `firestore`, `app` and `appFlavorContext` have no such double.
* One memory firebase per process: the memory http port (4999) and the
  local apps are process wide registries, so a second local context in the
  same process shares them and a client may end up authenticated on the
  first one. Tests keep one context per file (`dart test` runs each file in
  its own process).
* Cms sites (`package:festenao_common/server/festenao_server_cms.dart`,
  exported by `festeano_server_app.dart`): the `cmsCommand` function serves
  the published pages (`festenao_cms.dart`) of the synced content database
  `app/<app>/project/<projectId>/data/<dataId>` at
  `<mount>/<projectId>/<dataId>/` (`page/<slug>`, `sitemap.xml`,
  `robots.txt`), the mount being the hosting path `cms` or the function name
  (`cmsMountNames`). `handleCmsRequest(CmsSiteRequest)` does it all and
  never throws (404 when the url, the project or the content is unknown,
  or the project deleted; 500 on error): `cmsSiteOf` splits the url into a
  `FestenaoCmsSiteRef` (the app is the server one), `cmsSiteProject` reads
  the project, `cmsContentCache` (`FestenaoCmsContentCache`) keeps the
  contents pulled read only in memory sdbs and re-synced on each request,
  `cmsSiteHandler` builds the `CmsSiteHandler` (site named after the
  project, at the request base url). Override those hooks to change the url
  shape or the site; give `cmsContentSdbOptions` the full schema when the
  synced database holds other stores than the pages and the media (a
  record of an unknown store fails the sync).
* `CmsSiteRequest.fromUrl(url, mountNames:, forwardedHost:,
  forwardedProto:)` derives the site base url from the request (firebase
  hosting forwards the visitor host), `shift(n)` moves path segments into
  it. `onHttpsCms` serves it on the express runtimes (io, node, sim,
  registered by `initCmsFunction()`), the admin sdk one uses
  `functionsCmsDartHandler`
  (`server/festenao_server_admin_sdk.dart`). `festenaoCmsAddProjectPages`
  writes pages into a project content in firestore (demos, tests).
* `isAppAllowed(app)`: a dev server handles no prod app, a prod server no
  dev app (`festenaoIsDevApp`: `-dev`, `_dev`, `-devx` suffixes). Not
  checked yet by `onCommand` nor `handleCmsRequest`: call it once the app
  comes from the request.
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

  // `this.firebaseContext`: an unqualified `firebaseContext` is the
  // deprecated tkcms global, not the inherited getter.
  late final fsDatabase = FestenaoFirestoreDatabase(
    firebaseContext: this.firebaseContext,
    flavorContext: appFlavorContext,
  );

  late final projectHandler = FestenaoEntityHandler(
    app: this,
    entityAccess: fsDatabase.projectDb,
  );

  late final firestoreHandler = FestenaoFirestoreHandler(
    options: FestenaoFirestoreHandlerOptions(firestore: firestore),
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

### A customized cms site

```dart
import 'package:festenao_common/festenao_cms.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/firebase/firestore_database.dart';

class MySiteServerApp extends FestenaoServerApp {
  MySiteServerApp({required super.context}) : super(app: 'myapp');

  /// A single data id: `<cms>/<projectId>/...`.
  @override
  (FestenaoCmsSiteRef, CmsSiteRequest)? cmsSiteOf(CmsSiteRequest request) {
    var siteRequest = request.shift(1);
    if (siteRequest == null) {
      return null;
    }
    return (
      FestenaoCmsSiteRef(
        app: app,
        projectId: request.segments.first,
        dataId: 'content',
      ),
      siteRequest,
    );
  }

  @override
  Future<CmsSiteHandler> cmsSiteHandler({
    required FsProject project,
    required FestenaoCmsContent content,
    required CmsSiteRequest request,
  }) async => CmsSiteHandler(
    pages: content.pages,
    renderer: CmsRenderer(
      site: CmsSite(
        name: project.name.v ?? 'My site',
        baseUrl: request.baseUrl,
        language: 'en',
      ),
    ),
  );
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
