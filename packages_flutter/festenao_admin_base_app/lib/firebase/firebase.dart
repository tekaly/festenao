// To set on start
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/data/festenao_storage.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

/// Global admin app context
late FirebaseContext globalAdminAppFirebaseContext;

/// To keep?
FirebaseContext get globalFirebaseContext => globalAdminAppFirebaseContext;

late FestenaoAppFirebaseContext globalFestenaoAppFirebaseContext;

/// Festenao Firebase context
class FestenaoAppFirebaseContext {
  /// App path
  final String storageRootPath;

  /// Storage bucket
  final String storageBucket;

  /// App path
  final String firestoreRootPath;

  FestenaoAppFirebaseContext(
      {required this.storageRootPath,
      required this.firestoreRootPath,
      required this.storageBucket});
}

// TODO fix path
String getImageDirPath(String imageName) =>
    url.join(storageImageDirPart, imageName);

// TODO fix path
extension FestenaoFirebaseContextExt on FestenaoAppFirebaseContext {
  String getImageDirStoragePath(String imageName) =>
      url.join(storageRootPath, storageImageDirPart, imageName);

  String getDataExportStoragePath(int changeId) => url.join(storageRootPath,
      storageDataDirPart, getStoragePublishDataFileBasename(changeId));

  String getMetaExportStoragePath(bool isDev) => url.join(storageRootPath,
      storageDataDirPart, getStoragePublishMetaFileBasename(isDev));

  String getMetaExportFirestorePath(bool isDev) => url.join(
      firestoreRootPath, getInfosPath(), 'export_meta${isDev ? '_dev' : ''}');
}
