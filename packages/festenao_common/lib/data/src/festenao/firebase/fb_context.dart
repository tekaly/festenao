import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/data/festenao_storage.dart';
import 'package:path/path.dart';
import 'package:tekartik_firebase_auth/auth.dart';
import 'package:tekartik_firebase_storage/storage.dart';

/// Returns the storage-relative directory path for the given [imageName].
String getImageDirPath(String imageName) =>
    url.join(storageImageDirPart, imageName);

/// Convenience extension on [FbContext] to build storage and firestore paths.
extension FbContextExt on FbContext {
  /// Returns the storage path for an image within the configured storage root.
  String getImageDirStoragePath(String imageName) =>
      url.join(storageRootPath!, storageImageDirPart, imageName);

  /// Returns the storage path for the exported data file for [changeId].
  String getDataExportStoragePath(int changeId) => url.join(
    storageRootPath!,
    storageDataDirPart,
    getStoragePublishDataFileBasename(changeId),
  );

  /// Returns the storage path for the export meta file based on [isDev].
  String getMetaExportStoragePath(bool isDev) => url.join(
    storageRootPath!,
    storageDataDirPart,
    getStoragePublishMetaFileBasename(isDev),
  );

  /// Deprecated: returns a firestore path for export meta (do not use).
  String getMetaExportFirestorePath(bool isDev) => url.join(
    firestoreRootPath!,
    getInfosPath(),
    'export_meta${isDev ? '_dev' : ''}',
  );
}

/// Helper service to initialize a [FbContext] from provided Firebase services.
class FbContextService {
  /// Firebase admin interface.
  final Firebase firebase;

  /// Optional Firestore REST service provider.
  final FirestoreService? firestoreService;

  /// Optional Auth REST service provider.
  final AuthService? authService;

  /// Optional Storage REST service provider.
  final StorageService? storageService;

  /// Create a new [FbContextService].
  FbContextService({
    required this.firebase,
    required this.firestoreService,
    required this.authService,
    required this.storageService,
  });

  /// Initializes Firebase app and returns an [FbContext] with resolved services.
  Future<FbContext> init({FirebaseAppOptions? appOptions}) async {
    var app = await firebase.initializeAppAsync(options: appOptions);
    var firestore = firestoreService?.firestore(app);
    var storage = storageService?.storage(app);
    var auth = authService?.auth(app);
    return FbContext(
      app: app,
      firestore: firestore,
      auth: auth,
      storage: storage,
    );
  }
}

/// Container holding initialized Firebase-related clients and paths.
class FbContext {
  /// Underlying Firebase app instance (may be null).
  final App? app;

  /// Firestore client instance (may be null).
  final Firestore? firestore;

  /// Auth client instance (may be null).
  final Auth? auth;

  /// Storage client instance (may be null).
  final Storage? storage;

  /// Root path in Firestore used by this context (optional).
  final String? firestoreRootPath;

  /// Storage bucket name (optional).
  final String? storageBucket;

  /// Root path in Storage used by this context (optional).
  final String? storageRootPath;

  /// Project id resolved from [app] or provided explicitly.
  late final String? projectId;

  /// Optional Firestore service provider used to create clients.
  final FirestoreService? firestoreService;

  /// Creates an [FbContext]. If [projectId] is not provided it is read from [app].
  FbContext({
    this.app,
    String? projectId,
    this.auth,
    this.firestore,
    this.storage,
    this.firestoreRootPath,
    this.storageBucket,
    this.storageRootPath,
    this.firestoreService,
  }) {
    this.projectId = projectId ?? app?.options.projectId;
  }
}
