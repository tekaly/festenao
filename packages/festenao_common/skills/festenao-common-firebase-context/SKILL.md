---
name: festenao-common-firebase-context
description: >-
  Use when bootstrapping firebase for a festenao app, tool or test: the
  FirebaseContext (firestore, auth, storage, functions, functionsCall) built
  by a FirebaseServicesContext (init, initServer), the festenao bootstraps
  festenaoInitFirebaseMemory, festenaoInitFirebaseSim,
  festenaoInitFirebaseRest / festenaoInitFirebaseServicesContextRest,
  festenaoInitFirebaseIoWithServiceAccount, the tkcms local ones
  initFirebaseServicesLocalMemory / initFirebaseServicesLocalSembast, the
  flavors (FlavorContext, AppFlavorContext, toAppFlavorContext) and the
  FestenaoFirestoreDatabase (projectDb, fsAppRoot, app/<appId> layout).
---

# festenao_common firebase context

Everything firebase in festenao is written against the tekartik abstractions
(`Firestore`, `FirebaseAuth`, `FirebaseStorage`, `FirebaseFunctionsCall`),
so one code base runs on flutterfire, on the REST api (desktop tools), on the
admin sdk (server), on a sim server and fully in memory (tests). The entry
point picks the backend by building a `FirebaseServicesContext` and turning
it into the `FirebaseContext` the rest of the code receives.

## Guidelines

* Imports: `package:festenao_common/festenao_firebase.dart` for the types
  (`FirebaseContext`, `FirebaseServicesContext`, `FirebaseAppOptions`) and
  the tkcms local bootstraps; the festenao bootstraps sit in
  `package:festenao_common/firebase/firebase_memory.dart`, `firebase_sim.dart`,
  `firebase_rest.dart`, `firebase_io.dart`;
  `package:festenao_common/festenao_flavor.dart` for the flavors;
  `package:festenao_common/festenao_firestore.dart` plus
  `package:festenao_common/firebase/firestore_database.dart` for the
  firestore layout (`fsAppRoot`, `FestenaoFirestoreDatabase`, `FsProject`).
* A `FirebaseContext` carries `firebaseApp`, `firestore`, `auth`, `storage`,
  `functions` (server side, the runtime's `FirebaseFunctions`),
  `functionsCall` (client side, callables) and `local` (true off the real
  firebase). Pass it around, never a global `FirebaseFirestore.instance`.
* `FirebaseServicesContext(firebase:, appOptions:, firestoreService:,
  authService:, storageService:, functionsService:, functionsCallService:,
  functionsCallRegion:)` describes the services; `await init()` initializes
  the app and builds the client context (`init(firebaseApp:, ffServer:,
  serverApp:)` binds a local functions server), `await initServer()` builds
  the server one (no callables). `regionBelgium` is the functions region
  used everywhere.
* Bootstraps, from the most local to production:
  `festenaoInitFirebaseMemory()` (everything in memory, no functions),
  `initFirebaseServicesLocalMemory(projectId:)` and
  `initFirebaseServicesLocalSembast(databaseFactory:, projectId:)` (memory
  or on disk, with in process functions, the base of the local servers),
  `festenaoInitFirebaseSim(uri:)` (a client of the sim server),
  `festenaoInitFirebaseRest(options:)` / `festenaoInitFirebaseServicesContextRest(appOptions:,
  googleAuthOptions:)` (REST with a user signed in, persisted on disk, the
  desktop and tool case; `FirebaseAppOptions(projectId:, apiKey:)` with the
  web api key of the project), `festenaoInitFirebaseIoWithServiceAccount(serviceAccountMap:)`
  (REST with a service account, scripts). Flutter apps use the flutterfire
  context of `festenao_firebase_flutter` instead.
* Flavors: `FlavorContext.dev`, `devx`, `prod`, `prodx`, `test` with
  `isDev`, `isProd` and `ifNotProdFlavor` (`''` in prod, the flavor name
  otherwise, what suffixes function names and app ids).
  `flavorContext.toAppFlavorContext(baseAppId: 'myapp', local:)` gives the
  `AppFlavorContext` whose `app` (`appId`) is `myapp-dev` or `myapp-prod`,
  the firestore root `app/<appId>` every collection hangs under;
  `FestenaoAppFlavorContext.base(basePackageName:, appFlavorContext:)`
  adds the package name (`com.example.app` or `com.example.appdev`).
* Layout: `fsAppRoot(appId)` is the `app/<appId>` document; entities live in
  `app/<appId>/<type>/<id>`, their access rows in
  `app/<appId>/access/<type>/...`, per user private data in
  `app/<appId>/user_prv/<userId>/...`, app level rights in
  `app/<appId>/user_access/<userId>`. `FestenaoFirestoreDatabase(firebaseContext:,
  flavorContext: appFlavorContext)` builds the typed accesses: `projectDb`
  (`FsProject`, the festenao entity), `appDb`, `fsProjectCollection`,
  `copyWithAppId(other)`. Call `initFestenaoFsBuilders()` once before
  reading any model (it registers the tkcms and festenao cv models).
* Typed documents are cv models: `ref.get(firestore)`, `ref.set(firestore,
  doc)`, `ref.onSnapshot(firestore)` on a `CvDocumentReference<T>`, the
  `Firestore` instance always passed in. Check the `FirestoreService`
  support flags before relying on snapshots or aggregate queries: the REST
  and admin sdk backends do not track changes.

## Examples

### In memory, the app layout

```dart
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_common/firebase/firebase_memory.dart';
import 'package:festenao_common/firebase/firestore_database.dart';

Future<void> main() async {
  var ffContext = await festenaoInitFirebaseMemory();
  var appFlavorContext = FlavorContext.dev.toAppFlavorContext(
    baseAppId: 'demo',
  );
  print(appFlavorContext.app); // demo-dev
  var db = FestenaoFirestoreDatabase(
    firebaseContext: ffContext,
    flavorContext: appFlavorContext,
  );
  print(db.projectDb.fsEntityCollectionRef.path); // app/demo-dev/project

  var projectRef = db.projectDb.fsEntityRef('p1');
  await projectRef.set(ffContext.firestore, FsProject()..name.v = 'Demo');
  var project = await projectRef.get(ffContext.firestore);
  print('${project.exists} ${project.name.v}'); // true Demo
}
```

### A desktop tool on the REST backend

```dart
import 'package:festenao_common/festenao_firebase.dart';
import 'package:festenao_common/firebase/firebase_rest.dart';

Future<FirebaseContext> initToolFirebase() async {
  var services = await festenaoInitFirebaseServicesContextRest(
    appOptions: FirebaseAppOptions(
      projectId: 'my-project',
      apiKey: 'AIza...', // the web api key of the project
    ),
  );
  var ffContext = await services.init();
  // Persisted on disk by the rest auth: prompts once.
  await ffContext.auth.signInWithEmailAndPassword(
    email: 'me@example.com',
    password: 'secret',
  );
  return ffContext;
}
```

### A local server and its client (memory)

```dart
import 'package:festenao_common/festenao_firebase.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_common/festenao_server.dart';

Future<void> main() async {
  var services = initFirebaseServicesLocalMemory(projectId: 'demo');
  var serverContext = await services.initServer();
  var app = FestenaoServerApp(
    app: 'demo-dev',
    context: TkCmsServerAppContext(
      firebaseContext: serverContext,
      flavorContext: FlavorContext.dev,
    ),
  );
  app.initFunctions();
  var ffServer = await serverContext.functions.serve();

  var clientContext = await services.init(
    firebaseApp: serverContext.firebaseApp,
    ffServer: ffServer,
    serverApp: app,
  );
  // Same memory firestore on both sides.
  await serverContext.firestore.doc('app/demo-dev').set({'name': 'Demo'});
  print((await clientContext.firestore.doc('app/demo-dev').get()).data);
  await ffServer.close();
}
```

## Common mistakes

* Mixing the app id and the base id: `FestenaoFirestoreDatabase` wants the
  `AppFlavorContext` (`demo-dev`), not the bare `demo`, or the client reads
  another root than the server writes.
* Calling `initServer()` for a client (no `functionsCall`) or `init()` for
  the functions runtime (no `functions`).
* Relying on `onSnapshot` on the REST backend: `supportsTrackChanges` is
  false there, poll or use `onSnapshotSupport`.
