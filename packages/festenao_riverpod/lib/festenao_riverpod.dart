/// Generic Festenao riverpod providers: [FileSystem], [SdbFactory],
/// [FestenaoAppFlavorContext], [FirebaseApp], [UserProjectsSdbManager] and
/// [UserProjectsSdb].
library;

export 'package:festenao_common/data/festenao_projects_sdb.dart'
    show UserProjectsSdb, UserProjectsSdbManager;
export 'package:festenao_common/festenao_flavor.dart'
    show FestenaoAppFlavorContext;

export 'src/app_flavor_context_provider.dart';
export 'src/file_system_provider.dart';
export 'src/firebase_app_provider.dart';
export 'src/sdb_factory_provider.dart';
export 'src/user_projects_sdb_manager_provider.dart';
export 'src/user_projects_sdb_provider.dart';
