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
