// To set on start
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/data/festenao_storage.dart';
import 'package:tkcms_admin_app/app/tkcms_admin_app.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

/// Global admin app context
FirebaseContext get globalFestenaoAdminAppFirebaseContext =>
    globalTkCmsAdminAppFirebaseContext;

FestenaoAppFirebaseOptions? _globalFestenaoAppFirebaseOptionsOrNull;

/// Compat
FestenaoAppFirebaseOptions? get globalFestenaoAppFirebaseContextOrNull =>
    _globalFestenaoAppFirebaseOptionsOrNull;

/// Compat
set globalFestenaoAppFirebaseContextOrNull(FestenaoAppFirebaseOptions? value) =>
    _globalFestenaoAppFirebaseOptionsOrNull = value;

/// Global festenao app firebase context
FestenaoAppFirebaseOptions get globalFestenaoAppFirebaseContext =>
    globalFestenaoAppFirebaseContextOrNull!;
set globalFestenaoAppFirebaseContext(FestenaoAppFirebaseContext value) {
  _globalFestenaoAppFirebaseOptionsOrNull = value;
}

set globalFestenaoAppFirebaseOptions(FestenaoAppFirebaseOptions value) {
  _globalFestenaoAppFirebaseOptionsOrNull = value;
}

typedef FestenaoAppFirebaseContext = FestenaoAppFirebaseOptions;

/// Festenao Firebase context
class FestenaoAppFirebaseOptions {
  /// App path, typically 'app' and at the root for firestore and storage
  final String storageRootPath;

  /// Storage bucket
  final String storageBucket;

  /// App path
  final String firestoreRootPath;

  FestenaoAppFirebaseOptions({
    required this.storageRootPath,
    required this.firestoreRootPath,
    required this.storageBucket,
  });
}

// TODO fix path
String getImageDirPath(String imageName) =>
    url.join(storageImageDirPart, imageName);

// TODO fix path
extension FestenaoFirebaseContextExt on FestenaoAppFirebaseContext {
  // @Deprecated('do not use')
  String getImageDirStoragePath(String imageName) =>
      url.join(storageRootPath, storageImageDirPart, imageName);

  @Deprecated('do not use')
  String getDataExportStoragePath(int changeId) => url.join(
    storageRootPath,
    storageDataDirPart,
    getStoragePublishDataFileBasename(changeId),
  );

  @Deprecated('do not use')
  String getMetaExportStoragePath(bool isDev) => url.join(
    storageRootPath,
    storageDataDirPart,
    getStoragePublishMetaFileBasename(isDev),
  );

  //@Deprecated('do not use') compat
  String getMetaExportFirestorePath(bool isDev) => url.join(
    firestoreRootPath,
    getInfosPath(),
    'export_meta${isDev ? '_dev' : ''}',
  );
}
