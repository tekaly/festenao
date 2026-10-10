/// An admin build: everything the explorers reach, behind credentials the app
/// itself holds.
///
/// [AdminExplorerScreen] is the whole of it in one list — firestore and the
/// users through a service account, the file system from wherever it is
/// rooted, and any sembast or sdb database by its path — so an app shows it
/// behind one item of its start page.
///
/// The credentials live in an sdb database of their own
/// ([AdminCredentialsDb]), which the user manages from the app: pasting a
/// service account, picking which one to use, deleting one. It is a plain sdb
/// database, so the explorer opens it like any other when something looks
/// wrong.
///
/// The apps of the project come with it ([AdminAppsScreen]): every app and
/// project, who may do what on them, an admin or a super admin made.
///
/// On linux (`admin_explorer_io.dart`), the service account of
/// `FESTENAO_SERVICE_ACCOUNT` and the service account files are copied in the
/// credentials, and firebase is reached through the admin sdk.
///
/// ```dart
/// var credentialsDb = await AdminCredentialsDb.open(sdbFactory);
/// await goToAdminExplorerScreen(
///   context,
///   credentialsDb: credentialsDb,
///   homePath: Platform.environment['HOME'],
/// );
/// ```
library;

export 'package:festenao_common/admin/festenao_apps_admin.dart'
    show
        FestenaoAdminApp,
        FestenaoAdminFirebase,
        FestenaoAdminProject,
        FestenaoAdminUserEntityAccess,
        FestenaoAppsAdmin,
        FestenaoUserAccessGrant,
        festenaoAdminFirebaseRest;

export 'file_system_explorer_flutter.dart';
export 'firebase_users_explorer_flutter.dart';
export 'firestore_explorer_flutter.dart';
export 'src/admin/admin_apps_screen.dart'
    show
        AdminAppScreen,
        AdminAppsScreen,
        AdminEntityUserAccessScreen,
        AdminUserAccessScreen,
        adminUserAccessAction,
        goToAdminAppScreen,
        goToAdminAppsScreen,
        goToAdminEntityUserAccessScreen,
        goToAdminUserAccessScreen;
export 'src/admin/admin_credentials.dart'
    show
        AdminCredentials,
        AdminCredentialsDb,
        adminCredentialsDatabaseSchema,
        adminCredentialsProjectIdIndex,
        adminCredentialsStore,
        adminCurrentCredentialsKey,
        adminServiceAccountError,
        adminServiceAccountMap,
        adminServiceAccountProjectId,
        adminSettingsStore,
        initAdminCredentialsBuilders;
export 'src/admin/admin_credentials_screen.dart'
    show
        AdminCredentialsEditScreen,
        AdminCredentialsScreen,
        goToAdminCredentialsEditScreen,
        goToAdminCredentialsScreen;
export 'src/admin/admin_explorer_screen.dart'
    show
        AdminExplorerScreen,
        adminFileSystem,
        adminFileSystemRootPath,
        adminFileSystemRoots,
        goToAdminExplorerScreen;
