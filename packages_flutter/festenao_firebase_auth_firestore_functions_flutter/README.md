# festenao_firebase_auth_firestore_functions_flutter

The firebase of a festenao app using auth, firestore and the functions call,
and no storage: flutterfire on the web, the rest apis elsewhere (desktop).
The package depends on these plugins only, so an app using it gets no
storage plugin (Flutter registers every plugin of the dependency graph).
Another combination of services gets a package of its own;
`festenao_firebase_flutter` is the bundle with storage.

| Function | What |
| --- | --- |
| `firebaseAuthFirestoreFunctionsFlutterSupported` | true on the web (flutterfire) |
| `initFirebaseAuthFirestoreFunctionsFlutter(options:, functionsCallRegion:, googleWebClientId:)` | the flutterfire context, the auth persisted in indexed db, the flutterfire sign in screens set up |
| `initFirebaseAuthFirestoreFunctionsRest(options:, functionsCallRegion:, sdbFactory:)` | the same project through the rest apis, the auth session kept in `sdbFactory` |

Both return the `FirebaseContext` (tkcms_common) the app wraps with its api
service and its sign in ui.
