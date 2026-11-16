/// The firebase of an app on auth, firestore and the functions call (no
/// storage): [initFirebaseAuthFirestoreFunctionsFlutter] (flutterfire, the
/// web) and [initFirebaseAuthFirestoreFunctionsRest] (the rest apis,
/// desktop), [firebaseAuthFirestoreFunctionsFlutterSupported] telling which
/// one; [FestenaoAppFirebase] (and [FestenaoFirebaseMode]) holds what an app
/// builds on them.
///
/// The package depends on these plugins only: an app using another
/// combination of services (storage) uses another package.
library;

export 'src/app_firebase.dart' show FestenaoAppFirebase, FestenaoFirebaseMode;
export 'src/firebase_auth_firestore_functions.dart'
    show
        firebaseAuthFirestoreFunctionsFlutterSupported,
        initFirebaseAuthFirestoreFunctionsFlutter,
        initFirebaseAuthFirestoreFunctionsRest;
