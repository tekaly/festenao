import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:path/path.dart';
import 'package:tkcms_common/tkcms_storage.dart';

/// App project context
abstract class FestenaoAdminAppProjectContext {
  String get projectId;

  Firestore get firestore;

  FirebaseStorage get storage;

  String get storageBucket;

  /// Firestore root path for the app/projectId
  String get firestorePath;

  String get storagePath;
}

extension FestenaoAdminAppProjectContextExt on FestenaoAdminAppProjectContext {
  CvDocumentReference get _rootDocumentRef =>
      CvDocumentReference(firestorePath);

  /// Firestore database context
  FirestoreDatabaseContext get firestoreDatabaseContext =>
      FirestoreDatabaseContext(
        firestore: firestore,
        rootDocument: _rootDocumentRef,
      );
  String get pathProjectId => projectId;
  /*
  @Deprecated('do not use, grab and release instead')
  Future<Database> get db async {
    var syncedDb = await this.syncedDb;
    var db = await syncedDb.database;
    return db;
  }

  @Deprecated('do not use, grab and release instead')
  Future<SyncedDb> get syncedDb async {
    var projectContext = this;
    if (projectContext is SingleFestenaoAdminAppProjectContext) {
      return projectContext.syncedDb;
    } else if (projectContext is ByProjectIdAdminAppProjectContext) {
      return (await globalProjectsDbBloc.grabContentDb(
              userId: projectContext.userId,
              projectId: projectContext.projectId))
          .contentDb
          .syncedDb;
    } else {
      throw UnsupportedError('Unknown projectContext $projectContext');
    }
  }*/
}

abstract class FestenaoAdminAppProjectContextBase
    implements FestenaoAdminAppProjectContext {
  @override
  final String firestorePath;
  @override
  final String storageBucket;
  @override
  final String storagePath;
  @override
  final Firestore firestore;
  @override
  final FirebaseStorage storage;

  FestenaoAdminAppProjectContextBase({
    required this.firestorePath,
    required this.storageBucket,
    required this.storagePath,
    required this.firestore,
    required this.storage,
  });
}

/// Compat mode or single project mode
class SingleFestenaoAdminAppProjectContext
    extends FestenaoAdminAppProjectContextBase {
  @override
  final String projectId;
  final SyncedDb syncedDb;

  SingleFestenaoAdminAppProjectContext({
    required this.projectId,
    required this.syncedDb,
    required super.firestore,
    required super.storage,
    required super.storageBucket,
    required super.firestorePath,
    required super.storagePath,
  });
}

/// By project id
abstract class ByProjectIdAdminAppProjectContext
    extends FestenaoAdminAppProjectContext {
  // final String userId;

  factory ByProjectIdAdminAppProjectContext({required String projectId}) {
    return _ByProjectIdAdminAppProjectContext(projectId: projectId);
  }
}

/// By project id
class _ByProjectIdAdminAppProjectContext
    extends FestenaoAdminAppProjectContextBase
    implements ByProjectIdAdminAppProjectContext {
  @override
  final String projectId;

  // final String userId;

  _ByProjectIdAdminAppProjectContext({required this.projectId})
    : super(
        firestore: globalFestenaoAdminAppFirebaseContext.firestore,
        storage: globalFestenaoAdminAppFirebaseContext.storage,
        firestorePath: url.join(
          globalFestenaoAppFirebaseContext.firestoreRootPath,
          projectPathPart,
          projectId,
        ),
        storageBucket: globalFestenaoAppFirebaseContext.storageBucket,
        storagePath: url.join(
          globalFestenaoAppFirebaseContext.storageRootPath,
          projectPathPart,
          projectId,
        ),
      );
}
