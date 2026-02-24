import 'package:festenao_admin_base_app/admin_app/app_compat.dart';
import 'package:festenao_admin_base_app/data/file_system.dart';
import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/sembast/projects_db_bloc.dart';
import 'package:festenao_common/data/festenao_firebase.dart';
import 'package:festenao_common/data/src/festenao_synced_db.dart';
import 'package:fs_shim/fs.dart';
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
  var fs = globalFs;
  var localPath = fs.path.join('compat');
  fs = fs.sandbox(path: localPath);
  globalProjectsDbBloc = SingleCompatProjectDbBloc(
    festenaoSyncedDb: FestenaoSyncedDb(
      contentDb: null,
      fs: fs,
      sourceOptions: FestenaoSyncSourceOptions(
        firebaseProjectId: 'TODO',
        storageBucket: 'TODO',
        firestoreRoot: 'TODO',
        storageRoot: 'TODO',
      ),
      options: FestenaoDbOptions(dbPath: 'TODO', mediasPath: 'TODO'),
      syncedDb: syncedDb,
    ),

    projectPath:
        globalFestenaoAdminApp.options!.singleProject!.singleProjectRootPath,
  );
}

/// Compatibility
SingleFestenaoAdminAppProjectContext globalCompatAdminAppProjectContext =
    SingleFestenaoAdminAppProjectContext(
      projectId: 'main',

      festenaoSyncedDb: FestenaoSyncedDb(
        contentDb: null,
        fs: globalFs.sandbox(path: 'compat'),
        sourceOptions: FestenaoSyncSourceOptions(
          firebaseProjectId: fbContext.projectId!,
          storageBucket: fbContext.storageBucket!,
          firestoreRoot: fbContext.firestoreRootPath!,
          storageRoot: fbContext.storageRootPath!,
        ),
        options: FestenaoDbOptions(dbPath: 'TODO', mediasPath: 'TODO'),
        syncedDb: festenaoDb,
      ),
      storage: fbContext.storage!,
      storageBucket: fbContext.storageBucket!,
      firestore: fbContext.firestore!,
      firestorePath: fbContext.firestoreRootPath!,
      storagePath: fbContext.storageRootPath!,
    );
