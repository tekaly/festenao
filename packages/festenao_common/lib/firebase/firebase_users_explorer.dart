/// Browsing the users of a firebase auth.
///
/// A [FirebaseUsersExplorer] lists the users of a `FirebaseAuth` page by page,
/// looks one up by uid or email, and creates or deletes one through
/// `FirebaseAuthAdmin` — as far as the backend goes: the admin sdk and the
/// local sdb backend do all of it, the rest api with a service account lists
/// and looks users up.
///
/// A backend implements only part of `UserRecord`, so a [FirebaseUserEntry]
/// reads each field once, keeping the ones it reports
/// ([firebaseUserRecordFields]).
///
/// [fillDemoFirebaseUsers] seeds a demo, on the in memory sdb backend
/// (`newFirebaseAuthSdbMemory` of `tekartik_firebase_auth_sdb`).
library;

export 'package:tekartik_firebase_auth/auth_admin.dart'
    show
        FirebaseAuthAdmin,
        FirebaseAuthCreateUserRequest,
        FirebaseAuthLocalAdmin;

export '../src/firebase/firebase_users_demo.dart'
    show
        demoFirebaseAnonymousUid,
        demoFirebaseUserRequests,
        fillDemoFirebaseUsers;
export '../src/firebase/firebase_users_explorer.dart'
    show
        FirebaseUserEntry,
        FirebaseUsersExplorer,
        FirebaseUsersPage,
        firebaseUserRecordFields;
