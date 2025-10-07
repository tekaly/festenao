import 'package:festenao_admin_base_app/admin_app/app_compat.dart';
import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/sembast/projects_db_bloc.dart';
import 'package:festenao_common/data/festenao_firebase.dart';
// ignore: depend_on_referenced_packages
import 'package:tkcms_common/tkcms_firebase.dart';

/// Compat for existing.
void initFirebaseV2FromV1(FbContext fbContext) {
  globalTkCmsAdminAppFirebaseContext = FirebaseContext(
    firebaseApp: fbContext.app,
    firestore: fbContext.firestore,
    auth: fbContext.auth,
    storage: fbContext.storage,
  );
  globalFestenaoAppFirebaseContext = FestenaoAppFirebaseContext(
    storageBucket: fbContext.storageBucket!,
    storageRootPath: fbContext.storageRootPath!,
    firestoreRootPath: fbContext.firestoreRootPath!,
  );
}

Future<void> initConfigV2FromV1({required SyncedDb syncedDb}) async {
  globalProjectsDbBloc = SingleProjectDbBloc(syncedDb: syncedDb);
}

/// Compatibility
SingleFestenaoAdminAppProjectContext globalCompatAdminAppProjectContext =
    SingleFestenaoAdminAppProjectContext(
      projectId: 'main',
      syncedDb: festenaoDb,
      storage: fbContext.storage!,
      storageBucket: fbContext.storageBucket!,
      firestore: fbContext.firestore!,
      firestorePath: fbContext.firestoreRootPath!,
      storagePath: fbContext.storageRootPath!,
    );
