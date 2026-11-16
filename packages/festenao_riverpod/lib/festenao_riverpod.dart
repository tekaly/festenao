/// Generic Festenao riverpod providers: [FileSystem], [SdbFactory],
/// [FestenaoAppFlavorContext], [FirebaseApp], [FirebaseContext], the
/// [TkCmsFbIdentity] (service account or user), the
/// [FestenaoFbIdentityAuthKeeper] (a user signed in, anonymous when nobody is),
/// [UserProjectsSdbManager] and
/// [UserProjectsSdb], plus the project providers and commands of an app with
/// no backend.
library;

export 'package:festenao_common/data/festenao_projects_sdb.dart'
    show UserProjectsSdb, UserProjectsSdbManager, SdbUserProject;
export 'package:festenao_common/festenao_flavor.dart'
    show FestenaoAppFlavorContext;
export 'package:tkcms_common/tkcms_auth.dart'
    show
        TkCmsFbIdentity,
        TkCmsFbIdentityExtension,
        TkCmsFbIdentityServiceAccount,
        TkCmsFbIdentityUser;

export 'src/app_flavor_context_provider.dart';
export 'src/fb_identity_auth_keeper.dart';
export 'src/file_system_provider.dart';
export 'src/firebase_app_provider.dart';
export 'src/firebase_context_provider.dart';
export 'src/no_api_projects_provider.dart';
export 'src/provider_wait.dart'
    show festenaoWaitUntil, FestenaoProviderContainerWaitExtension;
export 'src/sdb_factory_provider.dart';
export 'src/user_projects_sdb_manager_override.dart';
export 'src/user_projects_sdb_manager_provider.dart';
export 'src/user_projects_sdb_provider.dart';
