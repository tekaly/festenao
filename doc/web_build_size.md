# Web build size: link only what the web uses

Draft, 2026-10-12, from the note:

> It is important on the web that rest initialization is not called (so then
> not linked), it is not always the case. It is often better to have a
> `main_web.dart` and `main.dart` calling it if `kIsWeb` to make the js/wasm
> slightly lighter. Not all services are needed every time: does having a
> `storageServiceFlutter` used or not change the web build size? Any
> recommendation to include only what is needed?

Everything below was measured on Flutter 3.47.6 stable with
firebase_core_web 3.12.0, which loads the Firebase JS SDK 12.19.0. The method
is in §1. KB means 1024 bytes, and "gz" is `gzip -9`.

## 0. In short

1. **Reachability decides what gets linked, not imports and not runtime
   calls.** dart2js and dart2wasm keep what `main` can reach once compile-time
   constants are folded. Importing the rest libraries without reaching them
   adds 0 bytes (§2, G).
2. **A choice made on a constant drops the rest code, even when the constant
   is indirect.** That covers `kIsWeb` in the `if`, a getter or a top-level
   `final` built on it, a top-level flag that the web program never assigns,
   a helper parameter that always gets the same constant, and a conditional
   import. Each of these builds is within 6 KB of the flutterfire-only one
   (§2). So playelio's `if (kIsWeb || supportsFirebaseFlutter)` is fine, and
   so are the `bool get …Supported => kIsWeb` getters of
   sondelio/recettelio/quick_covoit. The real recettelio web build contains
   neither its rest init nor its demo data (§5).
3. **A choice made at runtime links the rest code.** Examples: a url
   parameter, a flag set at startup, a default backend replaced at startup (a
   riverpod provider default, `x ??= initLocal()`), or `defaultTargetPlatform`.
   For the rest stack this costs **+128 KB js (+39 KB gz)** and
   **+805 KB wasm (+305 KB gz)**. On wasm, the rest stack alone is 3.6 times
   the size of the flutterfire stack.
4. **So `main_web.dart` is not lighter than a `main.dart` whose only switch is
   a constant: the output is byte for byte the same size.** It is still worth
   having as a guarantee. It is a file that cannot reach rest, local, sim or
   demo, which anyone can check by reading its imports. It also stays light
   when someone later adds a runtime switch (a debug url parameter, a demo
   mode…) to `main.dart`. Recommended layout in §4.
5. **Which Firebase JS SDK modules the page downloads depends on the
   dependency graph, not on the code.** Every flutterfire web plugin in the
   resolved dependencies registers its JS SDK module. firebase_core_web
   downloads all of them from gstatic before `initializeApp` completes,
   whether the app uses them or not (verified at runtime, §3). Many apps get
   `firebase_storage` through `festenao_admin_base_app` or
   `festenao_firebase_flutter` without ever using Storage.
6. **`storageServiceFlutter`, the answer:**
   - **Dependency only**: +0.3 KB of Dart, plus `firebase-storage.js`
     (46 KB, 14 KB gz) downloaded at every cold start.
   - **Passed to `FirebaseServicesContext` but never called**: about +2 KB.
   - **Storage calls in the app** (upload, download, list, exists):
     +91 KB js (+25 KB gz), +8 KB wasm.

## 1. How it was measured

The test app is a throwaway Flutter app in a scratch folder (not committed).
It has the same imports as the apps:

- **flutterfire**: `FirebaseServicesContext(firebase: firebaseFlutter,
  firestoreService: firestoreServiceFlutter, authService:
  firebaseAuthServiceFlutter, functionsCallService:
  firebaseFunctionsCallServiceFlutter).init()`.
- **rest**: the set used by `festenaoInitFirebaseRestApp`, namely
  `firebaseRest`, `firestoreServiceRest`, `FirebaseAuthServiceRest`,
  `firebaseStorageServiceRest` and `firebaseFunctionsCallServiceRest`.
- **Shared app code**: uses the services through the abstract interfaces.
  Auth signs in and out and listens to `onCurrentUser`. Firestore does
  set/update/get, a query get, `onSnapshot` on a query and on a document, a
  transaction and a batch. One callable is called. The calls sit behind
  `Uri.base.queryParameters.containsKey('use')`, a condition the compiler
  cannot fold.
- **Two pubspecs**, identical except for `tekartik_firebase_storage_flutter`.
  They resolve to the same versions, apart from the three firebase_storage
  packages.
- **Build and measure**: one entry point per pattern,
  `flutter build web --release --wasm -t lib/<entry>.dart -o <dir>`, then the
  sizes of `main.dart.js` and `main.dart.wasm`, raw and gzipped.

**Pitfall: measure with code that uses the services.** A first series only
created the services and called nothing. In that series a runtime switch to
rest cost only +8 KB of js, and storage +2 KB. Tree shaking works per method.
With abstract interfaces, though, every call site links that method in every
implementation the program can instantiate. A runtime choice between two
backends therefore doubles the cost of every service call the app makes.

## 2. Results

The baseline is A, the flutterfire-only entry point: `main.dart.js`
1,377,784 bytes, `main.dart.wasm` 320,515 bytes. Each delta is measured
against the A built in the same series.

| | Entry point pattern | Δ js (gz) | Δ wasm (gz) | Rest linked |
|---|---|---|---|---|
| A | flutterfire only (a `main_web.dart`) | — | — | no |
| B | rest only | −31 KB (−1 KB) | **+805 KB (+304 KB)** | only rest |
| C | `if (kIsWeb \|\| supportsFirebaseFlutter)` (playelio) | 0 | −2 KB | no |
| D | `if (supportsFirebaseFlutter)`, the getter wrapping `kIsWeb \|\| …` | 0 | −2 KB | no |
| I | a top-level `final supportsFirebaseFlutter = kIsWeb \|\| …` | 0 | −2 KB | no |
| F | rest behind `import 'stub.dart' if (dart.library.io) 'rest.dart'` | 0 | −1 KB | no |
| G | rest library imported, never called | 0 | −1 KB | no |
| J | shared helper `initAny(rest: false)` with both branches inside | +6 KB (+1 KB) | +2 KB | no (the 6 KB is the helper's own code) |
| L | mutable `bool forceRest = false;` never assigned in the web program | +5 KB (+1 KB) | +3 KB | no |
| E | runtime: `?rest` url parameter | **+128 KB (+39 KB)** | **+810 KB (+306 KB)** | yes |
| M | the same flag as L, assigned at startup | **+128 KB (+39 KB)** | **+805 KB (+305 KB)** | yes |
| N | default backend replaced in `main` (riverpod provider default pattern) | **+128 KB (+39 KB)** | **+805 KB (+304 KB)** | yes |

Storage, flutterfire only:

| | Variant | Δ js (gz) | Δ wasm (gz) | At runtime |
|---|---|---|---|---|
| A2 | `tekartik_firebase_storage_flutter` in the pubspec, not referenced | +0.3 KB | 0 | + `firebase-storage.js` loaded |
| — | `storageService: storageServiceFlutter` passed, never called (first series) | +1.8 KB | 0 | idem |
| H | `storageServiceFlutter` passed, and upload/download/list/exists called | **+91 KB (+25 KB)** | +8 KB (+2 KB) | idem |

For scale, the real recettelio release build has a 4.84 MB `main.dart.js`
and a 3.94 MB `main.dart.wasm`. The engine files come on top
(`canvaskit.wasm` 7.3 MB, `skwasm.wasm` 3.6 MB). They are the same for every
app. A runtime switch to rest therefore adds about 3 % to recettelio's js and
about 20 % to its wasm.

## 3. The Firebase JS SDK: the plugins decide, not the code

How it works (read in the sources, then verified at runtime):

1. `flutter build web` generates `web_plugin_registrant.dart`. It calls
   `registerWith` for **every web plugin in the resolved dependency graph**,
   whether the app imports it or not
   (`.dart_tool/flutter_build/<hash>/web_plugin_registrant.dart`).
2. Each flutterfire web plugin's `registerWith` calls
   `FirebaseCoreWeb.registerService('<service>')`. For example,
   firebase_storage_web 3.11.13 calls `registerService('storage')`.
3. At `Firebase.initializeApp`, `FirebaseCoreWeb._initializeCore`
   (firebase_core_web 3.12.0, `lib/src/firebase_core_web.dart`) injects
   `https://www.gstatic.com/firebasejs/<version>/firebase-<service>.js` for
   every registered service and waits for all of them. For Firestore it
   loads `firebase-firestore-pipelines.js`.

Verified in headless Chrome, where the console logs one
`Initializing Firebase firebase_<service>` line per module:

- **A**: core, auth, firestore and functions.
- **A2**: the same modules plus `firebase_storage`, even though the code never
  references storage.

These modules are not part of `main.dart.js`, so a size check of the build
output does not see them. Their URLs are versioned, so the browser caches
them, and the cost falls mostly on the first visit and on the init wait.

| JS SDK 12.19.0 module | raw | gz |
|---|---|---|
| `firebase-app.js` | 104 KB | 23 KB |
| `firebase-firestore-pipelines.js` (cloud_firestore_web) | 735 KB | 184 KB |
| `firebase-auth.js` | 153 KB | 41 KB |
| `firebase-functions.js` | 15 KB | 5 KB |
| `firebase-storage.js` | 46 KB | 14 KB |
| `firebase-analytics.js` | 29 KB | 9 KB |
| `firebase-app-check.js` | 26 KB | 8 KB |
| `firebase-messaging.js` | 37 KB | 10 KB |

Remedies:

1. **Do not depend on a flutterfire plugin that the web app does not use.**
   The storage plugin mostly arrives through festenao packages:
   - `festenao_admin_base_app` depends on the storage, firestore, auth and ui
     flutter wrappers, and `festenao_dashboard_base_app` depends on
     `festenao_admin_base_app`.
   - `packages_flutter/festenao_firebase_flutter` is a pubspec-only bundle
     that includes `tekartik_firebase_storage_flutter`.
   - `initFestenaoAdminFirebaseFlutter`
     (`festenao_admin_base_app/lib/firebase/firebase_flutter.dart:25`) always
     passes `storageServiceFlutter`.

   playelio, for example, imports only `festenao_admin_base_app/auth/auth.dart`.
   Its web registrant still registers `FirebaseStorageWeb` (checked), so
   every start downloads `firebase-storage.js`, which playelio never uses: it
   reads objects through its api.
2. **Stopgap that leaves the dependencies alone:** in `web/index.html`, before
   `flutter_bootstrap.js`, add
   `<script>window.flutterfire_ignore_scripts = ['storage'];</script>`.
   Verified: the storage module is no longer loaded. Any storage call then
   fails, so use this only when the client really never touches Storage.
3. **The same reasoning applies to the largest module.** An app whose client
   never reads Firestore itself (only callables, or an http api) should not
   depend on `tekartik_firebase_firestore_flutter`. That saves 184 KB gz at
   startup.

## 4. Recommendations for entry points

### 4.1 The rule

The web program must not reach a non-web backend (rest, local sembast/sdb,
sim, memory demo, admin sdk) through a runtime path. A switch on a constant
is fine.

**Folded (not linked)**, as measured in §2:

- `kIsWeb`, `kIsWasm`, and `kDartIsWeb` (tekartik_common_utils: same
  `bool.fromEnvironment('dart.library.js_interop')` as `kIsWeb`).
- `kReleaseMode`, `kDebugMode`, `kProfileMode`.
- `bool.fromEnvironment` and `--dart-define` values.
- Anything derived from these as in C, D, I, J and L.

**Runtime (linked):**

- `Uri.base` and url parameters (`?demo`, `?rest`, `?local`).
- `defaultTargetPlatform`. On the web it is the browser's OS, so a test
  without `kIsWeb` in front also sends Android Chrome down the mobile branch.
- A mutable variable assigned anywhere in the web program.
- A provider or variable whose default is a backend, replaced at startup.
- `context ??= initLocal()` fallbacks.
- `try { flutter } catch (_) { rest }` fallbacks.
- Backends listed in a map or menu (debug screens offering to switch
  backend).

Write the constant in the `if` itself (`if (kIsWeb || …)`, as playelio does)
rather than relying on a getter. The output is the same today, but the
intent is visible and it does not depend on what the compiler inlines.

### 4.2 Layout

```
lib/main.dart          // dispatch only: kIsWeb → main_web, else main_io
lib/main_web.dart      // flutterfire only; imports no rest/local/sim/demo/admin sdk
lib/main_io.dart       // rest (desktop), main_rest.dart in older apps
lib/main_local.dart    // local backend, never imported by main_web.dart
lib/main_demo.dart     // memory demo, never imported by main_web.dart
lib/main_emulator.dart, main_*_driver.dart ...
```

```dart
import 'package:flutter/foundation.dart';

import 'main_io.dart' as io;
import 'main_web.dart' as web;

/// The shipped entry point: flutterfire on the web, the rest apis elsewhere.
Future<void> main() async {
  // kIsWeb tested in the `if` itself: the io path is dropped from the web
  // build (and the web path from the io build).
  if (kIsWeb) {
    await web.main();
  } else {
    await io.main();
  }
}
```

When flutterfire is also configured for mobile, use
`if (kIsWeb || supportsFirebaseFlutter)`, as in playelio.

- **Pass the backend init in as a parameter.** The shared bootstrap
  (`run<App>App`, `<app>Run`) receives the firebase init from the entry
  point (quick_covoit's `initFirebase` callback) and imports no backend
  itself. Never give that parameter a default backend: that is pattern N,
  and it is linked.
- **Demo.** `main_demo.dart` passes `demo: true`, and `main.dart` never
  passes it. The memory backend and the seeded data are then dropped
  (verified on recettelio). Do not read `?demo` from the url in the real
  entry point: that would link the memory backend, the in-process server and
  the data.
- **Debug switches.** Anything like `?rest` belongs in a separate entry point
  (`main_io.dart` run on Chrome), not in `main.dart`.

### 4.3 Builders

- **`FestenaoFirebaseAppBuilder` has no target option.**
  `festenao_support/lib/src/festenao_app_builder.dart:26` builds
  `lib/main.dart` (wasm) with `FlutterWebAppBuildOptions(wasm: true)`.
  `FlutterWebAppBuildOptions` has a `target`. Exposing it would let an app
  build `lib/main_web.dart` directly.
- **One build menu targets a missing file.** The festenaoprv user_plus menu
  (`festenaoprv_support/tool/user_plus_app/user_plus_app_build_menu.dart:28`)
  targets `lib/main_web.dart`, but `festenaoprv_user_plus_app/lib` only has
  `main.dart`.

### 4.4 Libraries

Imports are free (G), so umbrella libraries such as
`festenao_common/festenao_firebase_rest.dart` cost nothing in size by being
imported from flutter libraries. What costs is a helper that decides at
runtime.

No festenao helper puts the flutterfire and rest inits in the same function.
`initFesteaoPrvFirebaseFlutterGeneric` in festenaoprv_admin_app
(`lib/firebase/init_firebase_flutter.dart:91-122`) does, but it switches on
`if (kIsWeb)`, so it is folded.

## 5. Apps (survey 2026-10-12)

About 175 packages with a `web/` folder were scanned, and the 41
Firebase/festenao apps were classified. These rows were rechecked by hand:

| App | Web entry point | Verdict |
|---|---|---|
| recettelio_app (template) | `main.dart`, getter `=> kIsWeb`, `demo` parameter | Real release build: no `firebase_auth_rest.db` (rest init), no demo recipe. `main_demo.dart` has them. Fine |
| playelio_app (and karasongelio_app) | `main.dart`, `if (kIsWeb \|\| supportsFirebaseFlutter)` | Rest folded. **firebase_storage registered, Storage unused** |
| decat2026_app | `main.dart` | **Linked**: the provider default builds the in-memory backend and the server (`lib/state/api_service_provider.dart:15-20`, `:52-54`), overridden in `main.dart` (pattern N). Fix: a default that throws, overridden by each entry point |
| snudifo_admin_app | `main.dart` | **Linked**: `run.dart:39` `snfoFirebaseContextOrNull ??= … initFirebaseSim(…)` runs after the web branch. Fix: put it in an `else` |
| tkfaceswap_app | `main.dart` | `bool forceLocalFirebase = false;` (`main.dart:33`) is only assigned by `main_local.dart`, which the web build does not include: folded (pattern L) |
| festenaoprv_user_plus_app | `main_web.dart` (missing) | **The build menu targets a file that does not exist** |

From the survey, not rechecked:

- **Runtime-linked:** ctdo_app (`run.dart:41`, `??= initFirebaseLocalDev()`).
- **Rest on the web by design:** festenaoprv_user_app, festenaoprv_min_auth_user_app.
- **Constant-guarded:** notelio, calendelio, cronelio_admin, linkelio_admin,
  fuf_admin_app/fuf_bp_app, songbookelio, decat2026_admin_app,
  festenaoprv admin/dashboard, and the getter apps (sondelio, quick_covoit,
  pointelio, qrcodelio, tkhostelio).
- **Separate web file:** clipelio_app (builder targets `main_web.dart`),
  buzzerelio_app (`main.dart` → `main_web.dart`).
- **Storage plugin in the graph with no client Storage use** (each downloads
  `firebase-storage.js` for nothing): playelio, karasongelio, notelio,
  calendelio, cronelio_admin, buzzerelio, songbookelio firebase app,
  cokestudio2025, decat2026_app, festenaoprv min auth/sdb dashboards, and
  festenao_admin_base_app's own `main.dart`.

## 6. How to check an app

1. **Build into a scratch folder**:
   `flutter build web --release --wasm --no-pub -o <scratch>/web`.
   Workspace overrides stay as they are.
2. **Search for a marker.** Pick a string literal that only the unwanted code
   contains, such as an sdb name (`'firebase_auth_rest.db'`) or a demo record
   title. Count it in `main.dart.js` and `main.dart.wasm`, for example with
   Python `data.count(b'…')` (`grep -c` counts lines). Validate the marker
   first by building the entry point that must contain it (`main_demo.dart`,
   `main_io.dart`).
3. **Compare sizes.** festenaoprv
   `example/festenaoprv_min_common/tool/build_web_js_size.dart`
   (`tekartik_flutter_build`'s `FlutterWebBuildSize`) builds and reports js and
   wasm sizes for a list of app paths.
4. **List the plugins.** The newest
   `.dart_tool/flutter_build/<hash>/web_plugin_registrant.dart` lists the
   registered web plugins.
5. **Check the SDK modules at runtime.** Run
   `google-chrome --headless=new --enable-logging=stderr` on the served build.
   The console shows one `Initializing Firebase firebase_<service>` per JS SDK
   module. Serve the build at the root, since `<base href="/">`.

## 7. Follow-ups (not done)

- **festenao, storage:** move `tekartik_firebase_storage_flutter` out of
  `festenao_admin_base_app` and out of `festenao_firebase_flutter` (or into a
  separate storage bundle). Make storage a parameter of
  `initFestenaoAdminFirebaseFlutter`.
- **festenao, builder:** expose `target` in `FestenaoFirebaseAppBuilder`.
- **Apps:** decat2026_app provider default, snudifo_admin_app `??=`,
  festenaoprv_user_plus_app's missing `main_web.dart`, ctdo_app.
- **Stopgap:** `flutterfire_ignore_scripts = ['storage']` in the apps that
  keep the storage plugin.
- **Skill:** add §4.1 to the festenao skill
  (`app-new-project.md` §5, entry points).
