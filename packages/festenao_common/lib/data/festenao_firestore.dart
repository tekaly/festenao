import 'package:festenao_common/festenao_firebase.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';

export 'package:tekartik_firebase_firestore/firestore.dart';
export 'package:tekartik_firebase_firestore/utils/track_changes_support.dart';

export 'src/festenao/cv_import.dart';
export 'src/model/fs_export.dart';
export 'src/model/fs_paths.dart';
export 'src/model/fs_user.dart';

/// Gets the Firestore publish meta document name based on the development flag.
///
/// Returns 'export_meta_dev' if [isDev] is true, otherwise 'export_meta'.
String getFirestorePublishMetaDocumentName(bool isDev) =>
    'export_meta${isDev ? '_dev' : ''}';

/// Project collection info in app !
final festenaoAppAsProjectCollectionInfo =
    TkCmsFirestoreDatabaseEntityCollectionInfo<TkCmsFsEntity>(
      id: 'app',
      name: 'Project',
      treeDef: tkCmsSyncedTreeDef,
    );

final festenaoAppCollectionInfo =
    TkCmsFirestoreDatabaseEntityCollectionInfo<TkCmsFsEntity>(
      id: 'app',
      name: 'App',
      treeDef: tkCmsSyncedTreeDef,
    );

extension TkCmsFirestoreDatabaseEntityCollectionInfoExt<T extends TkCmsFsEntity>
    on TkCmsFirestoreDatabaseEntityCollectionInfo<T> {
  /// Access db
  TkCmsFirestoreDatabaseServiceEntityAccess<T> rootAccess(
    FirebaseContext firebaseContext,
  ) {
    return TkCmsFirestoreDatabaseServiceEntityAccess<T>(
      entityCollectionInfo: this,
      firestoreDatabaseContext: FirestoreDatabaseContext(
        firestore: firebaseContext.firestore,
        rootDocument: null,
      ),
    );
  }
}
