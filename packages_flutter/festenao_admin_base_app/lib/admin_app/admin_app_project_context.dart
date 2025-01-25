import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:path/path.dart';
import 'package:tkcms_admin_app/sembast/content_db_bloc.dart';
import 'package:tkcms_common/tkcms_storage.dart';

/// App project context
abstract class FestenaoAdminAppProjectContext {
  Firestore get firestore;
  FirebaseStorage get storage;
  String get firestorePath;
  String get storagePath;
}

extension FestenaoAdminAppProjectContextExt on FestenaoAdminAppProjectContext {
  Future<Database> get db async {
    var syncedDb = await this.syncedDb;
    var db = await syncedDb.database;
    return db;
  }

  Future<SyncedDb> get syncedDb async {
    var projectContext = this;
    if (projectContext is SingleFestenaoAdminAppProjectContext) {
      return projectContext.syncedDb;
    } else if (projectContext is ByProjectIdAdminAppProjectContext) {
      return (await globalContentBloc.grabContentDb(projectContext.projectId))
          .syncedDb;
    } else {
      throw UnsupportedError('Unknown projectContext $projectContext');
    }
  }
}

abstract class FestenaoAdminAppProjectContextBase
    implements FestenaoAdminAppProjectContext {
  @override
  final String firestorePath;
  @override
  final String storagePath;
  @override
  final Firestore firestore;
  @override
  final FirebaseStorage storage;

  FestenaoAdminAppProjectContextBase(
      {required this.firestorePath,
      required this.storagePath,
      required this.firestore,
      required this.storage});
}

/// Compat mode or single project mode
class SingleFestenaoAdminAppProjectContext
    extends FestenaoAdminAppProjectContextBase {
  final SyncedDb syncedDb;

  SingleFestenaoAdminAppProjectContext(
      {required this.syncedDb,
      required super.firestore,
      required super.storage,
      required super.firestorePath,
      required super.storagePath});
}

/// By project id
class ByProjectIdAdminAppProjectContext
    extends FestenaoAdminAppProjectContextBase {
  final String projectId;

  ByProjectIdAdminAppProjectContext({required this.projectId})
      : super(
            firestore: globalAdminAppFirebaseContext.firestore,
            storage: globalAdminAppFirebaseContext.storage,
            firestorePath: url.join(
                globalFestenaoAppFirebaseContext.firestoreRootPath,
                projectPathPart,
                projectId),
            storagePath: url.join(
                globalFestenaoAppFirebaseContext.storageRootPath,
                projectPathPart,
                projectId));
}
