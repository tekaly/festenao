---
name: festenao-dartff-functions
description: >-
  Use when working on the festenao Dart cloud functions project
  festenao_dartff (admin sdk runtime, dart3 firebase functions): FfApp (the
  FestenaoServerApp of the functions), festenaoAmpCommand,
  festenaoAmpDartV2Handler, declareRunner, festenaoCmsSiteDartHandler /
  declareCmsSiteRunner / festenaoCmsCommand (the festenao cms site as an
  http function), serveFestenaoFunctionsHttp (a standalone local server,
  port 8040), the functions/bin/server.dart
  entry point registering commanddartv2dev / callcommanddartv2dev / ampdev
  and their prod twins with runFunctions, functionsHttpDartV2Handler and
  functionsCallDartV2Handler, compiling with tool/compile_dart_function.dart,
  running the firebase emulator (FirebaseEmulatorService,
  initEmulatorServerContext, testFestenaoServerGroup) and the three firestore
  rules contexts (api, full api, no api).
---

# Festenao Dart cloud functions (festenao_dartff)

`festenao_dartff` is the Cloud Functions project of festenao written in Dart
for the admin sdk runtime (`firebase.json` runtime `dart3`,
`package:firebase_functions`). It holds `FfApp`, the `FestenaoServerApp`
answering the festenao api, the handlers that `functions/bin/server.dart`
registers, the firebase project files (rules, indexes, emulator ports) and
three sibling rules projects.

## Guidelines

* Layout: `lib/functions.dart` (the library), `functions/` (the deployable
  package `festenao_dartff_functions`: `bin/server.dart`, generated
  `functions.yaml`), `firebase.json` (functions on 5001, firestore on 8080,
  auth on 9099), `firestore.rules`, `firestore.indexes.json`, `tool/`
  (`start_festenao_emulator.dart`, `compile_dart_function.dart`),
  `test/emulator_test.dart`, and the rules contexts
  `festenao_firebase_api_context.dart/` (api + rules, no client side project
  creation), `festenao_firebase_full_api_context.dart/` (api + rules with
  standalone creation, public access and invites) and
  `festenao_firebase_no_api_context.dart/` (rules only, no function: what
  the no-api providers of `festenao_riverpod` run against). Each has its
  own `firestore.rules`, `tool/` emulator starter and one `test/` file.
* Import `package:festenao_dartff/functions.dart`: `FfApp`,
  `festenaoAmpCommand(app)`, `festenaoAmpDartV2Handler`, `declareRunner`;
  it re-exports `festenao_common/server/festeano_server_app.dart`
  (`FestenaoServerApp`). Around it:
  `package:tekartik_firebase_functions_admin_sdk/functions_admin_sdk.dart`
  (`runFunctions`, `HttpsOptions`, `CallableOptions`, `Cors`, `Region`,
  `SupportedRegion`, `httpsHandler`, `callHandler`),
  `package:tkcms_common/server/server_admin_sdk.dart`
  (`functionsHttpDartV2Handler`, `functionsCallDartV2Handler` on the app),
  `package:tkcms_common/server/server_common.dart` (the function names).
* `FfApp({required context, app})`: `context` is a
  `TkCmsServerAppContext(firebaseContext:, flavorContext:)`, `app` defaults
  to `'festenao'` (the firestore root `app/<app>`; the tests use
  `testAppId = 'festenao'`). The constructor registers the entity api
  builders of `FsProject` and `TkCmsFsApp`; `onCommand` first asks
  `appHandler` (a `FestenaoEntityHandler` on `fsDatabase.appDb`, the app
  top entity) then falls back to `FestenaoServerAppTest.onCommand`. Add a
  command by subclassing, see the `festenao-common-server-app` skill.
* Two apps per process, one per flavor: dev (`FlavorContext.dev`) behind
  `commanddartv2dev` (`functionCommandDartV2Dev`), `callcommanddartv2dev`
  (`callableFunctionCommandDartV2Dev`) and `ampdev`; prod behind
  `commanddartv2prod`, `callcommanddartv2prod` and `amp`.
  `festenaoAmpCommand(app)` is the amp name of an app's flavor. Both share
  one admin sdk `FirebaseContext` built from `firebaseAdminSdk`,
  `firestoreServiceAdminSdk`, `firebaseAuthServiceAdminSdk` and
  `firebaseStorageServiceAdminSdk` (`FirebaseServicesContext(...)
  .copyWith(firebaseApp: firebase.firebaseApp).initSync()`); set
  `firebaseContextOrNull` too, some `festenao_common` handlers still read
  the global.
* Registration happens inside `runFunctions((firebase) async { ... })`:
  `firebase.https.onRequest(name:, options:,
  firebase.httpsHandler(app.functionsHttpDartV2Handler))` and
  `firebase.https.onCall(name:, options:,
  firebase.callHandler(app.functionsCallDartV2Handler))`. Amp is a plain
  http function (`festenaoAmpDartV2Handler`, returns the built
  `FestenaoAmpPage` html): the admin sdk runtime has no express request, so
  `FestenaoServerApp.onHttpsAmp` is not used here. Options: `Cors(['*'])`
  and `Region(SupportedRegion.europeWest1)` (`regionBelgium`).
* Only the callable transport authenticates: the server gets `userId` from
  the verified auth context of `onCall`; an https `onRequest` command is
  anonymous and its user id is ignored. Entity creation with a first admin
  therefore goes through the callable api (see `test/emulator_test.dart`).
* `festenaoCmsSiteDartHandler(functionName:, siteHandler:)` is an http
  handler serving a `CmsSiteHandler` (`festenao_common/festenao_cms.dart`):
  the index, `page/<slug>`, `sitemap.xml`, `robots.txt`, a 404 for anything
  else (drafts included), with the content type of each and a CDN
  `cache-control` on the 200s. `siteHandler` is called per request (a
  `FestenaoCmsSiteHandlerProvider`, sync or async): open the content
  database lazily there, and give the `CmsSite` the function url as base
  url (`https://<region>-<project>.cloudfunctions.net/<functionName>/`) so
  the page links, canonical urls and sitemap point back at the function.
  The leading `functionName` segment is dropped (the local runners keep
  it, the deployed runtime does not). It is not registered by
  `functions/bin/server.dart`: festenao has no server side page database
  yet, an app registers it with its own `onRequest`.
* `declareCmsSiteRunner(functions, name:, siteHandler:)` registers that
  handler on the admin sdk http runner, next to `declareRunner(app,
  functions)`; `festenaoCmsCommand(app)` is its name for an app flavor
  (`cms` / `cmsdev`).
* `serveFestenaoFunctionsHttp(declare:, port:, firebaseApp:,
  httpServerFactory:)` serves what `declare` registers on a standalone
  server at `http://localhost:<port>/<function>/...` (`port` defaults to
  `festenaoFunctionsHttpServerPort`, 8040, handed to the `port:` of
  `FirebaseFunctionsServiceAdminSdkHttp`). `firebaseApp` defaults to an in memory app (enough for
  a cms site; give the app of a `FirebaseContext` for an `FfApp`),
  `httpServerFactory` to io (`httpFactoryMemory.server` in a test). It
  returns the functions: `functions.httpServer` to close. The
  `festenao_dashboard_base_app/example/demo` `bin/server.dart` (cms) and
  `bin/server_ff_app.dart` (`FfApp` plus cms) use both helpers.
* `declareRunner(app, functions)` performs the same registrations on a
  `FirebaseFunctionsAdminSdkHttp`, the raw http runner of
  `tekartik_firebase_functions_admin_sdk_http`:
  `newFirebaseFunctionsServiceAdminSdkHttp(httpServerFactory:)
  .fireUp(firebaseApp, (functions) => declareRunner(app, functions))`
  (memory http server by default, for tests).
* Build and deploy from `packages/festenao_dartff`: `dart run
  tool/compile_dart_function.dart` compiles `functions/bin/server.dart` for
  linux x64 and copies `server.exe` to `functions/bin/server` (the command
  in `functions.yaml`), then `firebase deploy --only functions`.
  `functions.yaml` is generated by `package:firebase_functions`, do not
  edit it; `functions/` depends on the library with `path: ../`.
* Emulator: `dart run tool/start_festenao_emulator.dart` starts functions,
  firestore and auth, persisted in `.data`. `dart test` runs the emulator
  test only when `FirebaseEmulatorService(path: '.').isSupported()` (the
  firebase cli is installed), on the vm, one file at a time
  (`dart_test.yaml`: `concurrency: 1`). A test gets a
  `FestenaoTestServerEmulatorContext` from
  `initEmulatorServerContext(appId:, path: '.', region: regionBelgium)`
  (`festenao_common/test/festenao_test_server_emulator_helper.dart`) and
  hands it to the shared runners (`testFestenaoServerGroup`,
  `testFestenaoDocServerGroup`, `testQuizzServerGroup`,
  `appProjectAccessTestRunner`, `appUserPrvAccessTestRunner`...), closing it
  in `tearDownAll` (this stops the emulator).
* The package is `publish_to: none`; to reuse `FfApp` from another project:
  ```yaml
  dependencies:
    festenao_dartff:
      git:
        url: https://github.com/tekaly/festenao
        path: packages/festenao_dartff
  ```

## Examples

### The deployed entry point (functions/bin/server.dart)

```dart
import 'package:festenao_dartff/functions.dart';
import 'package:tekartik_firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:tekartik_firebase_admin_sdk/firebase_auth_admin_sdk.dart';
import 'package:tekartik_firebase_admin_sdk/firebase_storage_admin_sdk.dart';
import 'package:tekartik_firebase_admin_sdk/firestore_admin_sdk.dart';
import 'package:tekartik_firebase_functions_admin_sdk/functions_admin_sdk.dart';
import 'package:tkcms_common/firebase/firebase.dart';
import 'package:tkcms_common/server/server_admin_sdk.dart';
import 'package:tkcms_common/server/server_common.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

const _httpsOptions = HttpsOptions(
  cors: Cors(['*']),
  region: Region(SupportedRegion.europeWest1),
);
const _callableOptions = CallableOptions(
  cors: Cors(['*']),
  region: Region(SupportedRegion.europeWest1),
);

void main(List<String> args) {
  runFunctions((firebase) async {
    // One admin sdk context, shared by the dev and prod apps.
    var fbContext = FirebaseServicesContext(
      firebase: firebaseAdminSdk,
      authService: firebaseAuthServiceAdminSdk,
      firestoreService: firestoreServiceAdminSdk,
      storageService: firebaseStorageServiceAdminSdk,
    ).copyWith(firebaseApp: firebase.firebaseApp).initSync();
    // Some festenao_common server handlers use the global context.
    firebaseContextOrNull = fbContext;

    // Function names must be constants: one explicit block per flavor.
    var appDev = FfApp(
      context: TkCmsServerAppContext(
        firebaseContext: fbContext,
        flavorContext: FlavorContext.dev,
      ),
    );
    firebase.https.onRequest(
      name: functionCommandDartV2Dev, // commanddartv2dev
      options: _httpsOptions,
      firebase.httpsHandler(appDev.functionsHttpDartV2Handler),
    );
    firebase.https.onCall(
      name: callableFunctionCommandDartV2Dev, // callcommanddartv2dev
      options: _callableOptions,
      firebase.callHandler(appDev.functionsCallDartV2Handler),
    );
    firebase.https.onRequest(
      name: 'ampdev', // festenaoAmpCommand(appDev)
      options: _httpsOptions,
      firebase.httpsHandler(festenaoAmpDartV2Handler),
    );

    var appProd = FfApp(
      context: TkCmsServerAppContext(
        firebaseContext: fbContext,
        flavorContext: FlavorContext.prod,
      ),
    );
    firebase.https.onRequest(
      name: functionCommandDartV2Prod, // commanddartv2prod
      options: _httpsOptions,
      firebase.httpsHandler(appProd.functionsHttpDartV2Handler),
    );
    firebase.https.onCall(
      name: callableFunctionCommandDartV2Prod, // callcommanddartv2prod
      options: _callableOptions,
      firebase.callHandler(appProd.functionsCallDartV2Handler),
    );
    firebase.https.onRequest(
      name: 'amp', // festenaoAmpCommand(appProd)
      options: _httpsOptions,
      firebase.httpsHandler(festenaoAmpDartV2Handler),
    );
  });
}
```

### Serving an FfApp on the raw http runner

```dart
import 'package:festenao_dartff/functions.dart';
import 'package:tekartik_firebase_functions_admin_sdk_http/functions_admin_sdk_http.dart';

/// Registers the functions of [app] on a local http server (in memory by
/// default; pass `httpServerFactory:` for a real io port).
Future<void> serveFfApp(FfApp app) async {
  var service = newFirebaseFunctionsServiceAdminSdkHttp();
  await service.fireUp(app.firebaseContext.firebaseApp, (functions) {
    declareRunner(app, functions);
  });
}
```

### A standalone cms server (port 8040), and FfApp next to it

```dart
import 'package:festenao_common/festenao_cms.dart';
import 'package:festenao_dartff/functions.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_flavor.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// `http://localhost:8040/cms/`: [pages] as a site, their links pointing at
/// the function url.
Future<FirebaseFunctionsAdminSdkHttp> serveCmsSite(CmsPageSdb pages) =>
    serveFestenaoFunctionsHttp(
      declare: (functions) => declareCmsSiteRunner(
        functions,
        name: 'cms',
        siteHandler: () => CmsSiteHandler(
          pages: pages,
          renderer: CmsRenderer(
            site: CmsSite(
              name: 'My festival',
              baseUrl: Uri.parse('http://localhost:8040/cms/'),
            ),
          ),
        ),
      ),
    );

/// The dev api, amp and cms site functions, firebase in memory.
Future<FirebaseFunctionsAdminSdkHttp> serveFfAppAndCms(CmsPageSdb pages) {
  var firebaseContext = initFirebaseServicesLocalMemory(
    projectId: 'my-project',
  ).initContext();
  firebaseContextOrNull = firebaseContext;
  var app = FfApp(
    context: TkCmsServerAppContext(
      firebaseContext: firebaseContext,
      flavorContext: FlavorContext.dev,
    ),
  );
  var cmsName = festenaoCmsCommand(app); // cmsdev
  return serveFestenaoFunctionsHttp(
    firebaseApp: firebaseContext.firebaseApp,
    declare: (functions) {
      declareRunner(app, functions);
      declareCmsSiteRunner(
        functions,
        name: cmsName,
        siteHandler: () => CmsSiteHandler(
          pages: pages,
          renderer: CmsRenderer(
            site: CmsSite(
              name: 'My festival',
              baseUrl: Uri.parse('http://localhost:8040/$cmsName/'),
            ),
          ),
        ),
      );
    },
  );
}
```

In a test, pass `httpServerFactory: httpFactoryMemory.server`
(`package:tekartik_http/http_memory.dart`) and read the pages with
`httpFactoryMemory.client.newClient()`. Deployed, register the handler next
to the others in `functions/bin/server.dart` with
`firebase.https.onRequest(name: 'cmsdev', options: _httpsOptions,
firebase.httpsHandler(festenaoCmsSiteDartHandler(...)))`.

### An emulator test

```dart
@TestOn('vm')
library;

import 'dart:io';

import 'package:festenao_common/test/festenao_test_server_emulator_helper.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:festenao_common/test/project_access_test_runner.dart';
import 'package:tekartik_firebase_emulator/firebase_emulator.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_server.dart';

var emulatorService = FirebaseEmulatorService(path: '.');

Future<void> main() async {
  if (!await emulatorService.isSupported(options: emulatorTestRunnerOptions)) {
    test('Firebase emulator not supported', () {
      stderr.writeln('Firebase emulator not supported');
    });
    return;
  }
  late FestenaoTestServerEmulatorContext testContext;
  group('emulator', () {
    setUpAll(() async {
      testContext = await initEmulatorServerContext(
        appId: 'festenao', // the default app of FfApp
        path: '.',
        region: regionBelgium,
      );
    });
    // The shared api suite, through the emulated functions.
    testFestenaoServerGroup(
      () async => testContext,
      noObjectStorage: true,
      options: TestFestenaoServerGroupOptions(addFirestoreDoc: true),
    );
    // The rules, through the rest client of the context.
    group('project access', () {
      appProjectAccessTestRunner(() async => testContext.clientContext);
    });
    tearDownAll(() async {
      await testContext.close(); // stops the emulator
    });
  }, timeout: Timeout(Duration(minutes: 5)));
}
```

### Day to day commands

```bash
cd packages/festenao_dartff
dart run tool/start_festenao_emulator.dart   # emulator, data kept in .data
dart test                                    # test/emulator_test.dart (needs the firebase cli)
(cd festenao_firebase_no_api_context.dart && dart test)   # rules only context
dart run tool/compile_dart_function.dart     # functions/bin/server (linux x64)
firebase deploy --only functions
```

## Common mistakes

* Registering an https command and expecting `userId` server side: only
  `onCall` carries the verified user.
* Editing `functions/functions.yaml` by hand (generated).
* Forgetting `firebaseContextOrNull = fbContext` before building the apps.
* Running two emulator test files concurrently (ports 5001/8080/9099 are
  shared; keep `concurrency: 1`).
