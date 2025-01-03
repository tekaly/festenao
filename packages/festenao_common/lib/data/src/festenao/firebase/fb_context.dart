import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/data/festenao_storage.dart';
import 'package:path/path.dart';
import 'package:tekartik_firebase_auth/auth.dart';
import 'package:tekartik_firebase_storage/storage.dart';

String getImageDirPath(String imageName) =>
    url.join(storageImageDirPart, imageName);

extension FbContextExt on FbContext {
  String getImageDirStoragePath(String imageName) =>
      url.join(storageRootPath!, storageImageDirPart, imageName);

  String getDataExportStoragePath(int changeId) => url.join(storageRootPath!,
      storageDataDirPart, getStoragePublishDataFileBasename(changeId));

  String getMetaExportStoragePath(bool isDev) => url.join(storageRootPath!,
      storageDataDirPart, getStoragePublishMetaFileBasename(isDev));

  String getMetaExportFirestorePath(bool isDev) => url.join(
      firestoreRootPath!, getInfosPath(), 'export_meta${isDev ? '_dev' : ''}');
}

class FbContextService {
  final Firebase firebase;
  final FirestoreService? firestoreService;
  final AuthService? authService;
  final StorageService? storageService;

  FbContextService(
      {required this.firebase,
      required this.firestoreService,
      required this.authService,
      required this.storageService});

  Future<FbContext> init({FirebaseAppOptions? appOptions}) async {
    var app = await firebase.initializeAppAsync(options: appOptions);
    var firestore = firestoreService?.firestore(app);
    var storage = storageService?.storage(app);
    var auth = authService?.auth(app);
    return FbContext(
        app: app, firestore: firestore, auth: auth, storage: storage);
  }
}

class FbContext {
  final App? app;
  final Firestore? firestore;
  final Auth? auth;
  final Storage? storage;
  final String? firestoreRootPath;
  final String? storageBucket;
  final String? storageRootPath;
  late final String? projectId;

  final FirestoreService? firestoreService;

  FbContext(
      {this.app,
      String? projectId,
      this.auth,
      this.firestore,
      this.storage,
      this.firestoreRootPath,
      this.storageBucket,
      this.storageRootPath,
      this.firestoreService}) {
    this.projectId = projectId ?? app?.options.projectId;
  }
}
