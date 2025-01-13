export 'package:tekartik_firebase_firestore/firestore.dart';
export 'package:tekartik_firebase_firestore/utils/track_changes_support.dart';

export 'src/festenao/cv_import.dart';
export 'src/model/fs_export.dart';
export 'src/model/fs_paths.dart';
export 'src/model/fs_user.dart';

String getFirestorePublishMetaDocumentName(bool isDev) =>
    'export_meta${isDev ? '_dev' : ''}';
