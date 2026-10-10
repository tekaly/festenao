/// The apps of a firebase project and their users, for an admin build or tool
/// holding a service account: list every app and its projects, and grant or
/// remove an access (read, write, admin, super admin) on an app or a project,
/// both sides of the tkcms entity access being written.
///
/// ```dart
/// var admin = FestenaoAppsAdmin(firestore: firestore);
/// for (var app in await admin.apps()) {
///   print(app.appId);
/// }
/// await admin.setUserAccess(
///   admin.appAccess,
///   'festenao-dev',
///   userId,
///   grant: FestenaoUserAccessGrant.superAdmin,
///   email: 'me@example.com',
/// );
/// ```
library;

export '../src/admin/festenao_apps_admin.dart'
    show
        FestenaoAdminApp,
        FestenaoAdminFirebase,
        FestenaoAdminProject,
        FestenaoAdminUserEntityAccess,
        FestenaoAppsAdmin,
        FestenaoUserAccessGrant,
        festenaoAdminFirebaseRest,
        festenaoAdminUserAccessLabel;
