import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/sembast/sembast.dart';
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:tekartik_app_cv_sembast/app_cv_sembast.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

export 'package:tekartik_app_cv_sembast/app_cv_sembast.dart';

/// Reference to a Project
class ProjectRef {
  /// Local id
  final String? id;

  /// Synced id
  final String? syncedId;

  /// Project ref
  ProjectRef({this.id, this.syncedId}) {
    assert(id != null || syncedId != null);
  }

  /// True if local
  bool get isLocal => syncedId == null;

  /// True if remote
  bool get isRemote => !isLocal;

  ///
  Future<String?> getProjectId() async {
    if (id != null) {
      return id!;
    }
    var userId = (await globalFirebaseContext.auth.onCurrentUser.first)?.uid;
    if (userId != null) {
      var projectId = (await globalProjectsDb.getProjectBySyncedId(syncedId!,
              userId: userId))
          ?.id;
      if (projectId != null) {
        return projectId;
      } else {
        return null;
      }
    }
    return null;
  }
}

/// Key is the user id
class DbProjectUser extends DbStringRecordBase {
  /// Timestamp when the user is ready
  final readyTimestamp = CvField<DbTimestamp>('readyTimestamp');

  @override
  CvFields get fields => [readyTimestamp];
}

/// Project
class DbProject extends DbStringRecordBase with TkCmsCvUserAccessMixin {
  /// Name
  final name = CvField<String>('name');

  /// Firestore uid for non local
  final uid = CvField<String>('uid');

  /// User id
  final userId = CvField<String>('userId');

  /// True if local
  bool get isLocal => uid.isNull;

  /// True if remote
  bool get isRemote => !isLocal;

  @override
  CvFields get fields => [name, uid, userId, ...userAccessMixinfields];

  /// Project ref
  ProjectRef get ref {
    return ProjectRef(id: id, syncedId: uid.v);
  }

  /// True if the user has write access
  bool get isWrite => isLocal ? true : TkCmsCvUserAccessCommonExt(this).isWrite;

  /// True if the user has admin access
  bool get isAdmin => isLocal ? true : TkCmsCvUserAccessCommonExt(this).isRead;

  /// True if the user has read access
  bool get isRead => isLocal ? true : TkCmsCvUserAccessCommonExt(this).isRead;
}

/// The model
final dbProjectModel = DbProject();

/// Initialize the db builders
void initDbProjectsBuilders() {
  cvAddConstructors([DbProject.new, DbProjectUser.new]);
}

/// Projects db
const projectsDbName = 'projects_v1.db';

/// Project store
final dbProjectStore = cvStringStoreFactory.store<DbProject>('Project');

/// Project user store
final dbProjectUserStore =
    cvStringStoreFactory.store<DbProjectUser>('ProjectUser');
@Deprecated('Do not use')
CvCollectionReference<FsProject> fsAppProjectCollection(String app) =>
    fsAppRoot(app).collection<FsProject>(projectPathPart);
@Deprecated('Do not use')
CvDocumentReference<CvFirestoreDocument> fsAppBookletDataSyncedDocument(
        String app, String bookletId) =>
    fsAppProjectCollection(app)
        .doc(bookletId)
        .collection<CvFirestoreDocument>('data')
        .doc('synced');

/// Projects db
class ProjectsDb {
  /// Database
  late final Database db;

  /// ready state
  late final Future<void> ready = () async {
    db = await globalSembastDatabaseFactory.openDatabase(
      projectsDbName,
    );
    initDbProjectsBuilders();
  }();

  /// on Projects
  Stream<List<DbProject>> onProjects({required String userId}) async* {
    await ready;
    await dbProjectUserStore
        .record(userId)
        .onRecord(db)
        .firstWhere((user) => user?.readyTimestamp.value != null);
    yield* getProjectsQuery(userId: userId).onRecords(db);
  }

  /// Delete Project
  Future<void> deleteProject(ProjectRef projectRef) async {
    var projectId = await projectRef.getProjectId();
    if (projectId != null) {
      await dbProjectStore.record(projectId).delete(db);
    }
  }

  /// on local Projects
  Stream<List<DbProject>> onLocalProjects() async* {
    await ready;
    yield* getLocalProjectsQuery().onRecords(db);
  }

  /// on Project
  Stream<DbProject?> onProject(String projectId) async* {
    await ready;
    yield* dbProjectStore.record(projectId).onRecord(db);
  }

  /// Query
  CvQueryRef<String, DbProject> getProjectsQuery({required String userId}) {
    return dbProjectStore.query(
        finder: Finder(
            filter: Filter.or([
      Filter.equals(dbProjectModel.userId.name, userId),
      Filter.isNull(dbProjectModel.uid.name),
    ])));
  }

  /// Get local Projects
  CvQueryRef<String, DbProject> getLocalProjectsQuery() {
    return dbProjectStore.query(
        finder: Finder(
      filter: Filter.isNull(dbProjectModel.uid.name),
    ));
  }

  /// Get all remote Projects
  CvQueryRef<String, DbProject> getAllRemoteProjectsQuery() {
    return dbProjectStore.query(
        finder: Finder(
      filter: Filter.notNull(dbProjectModel.uid.name),
    ));
  }

  /// Get all remote Projects synced
  Future<List<DbProject>> getExistingSyncedProjects(
      {required String userId}) async {
    await ready;
    return dbProjectStore
        .query(
            finder: Finder(
                filter: Filter.equals(dbProjectModel.userId.name, userId)))
        .getRecords(db);
  }

  /// Get Project by synced id
  Future<DbProject?> getProjectBySyncedId(String uid,
      {required String userId}) async {
    await ready;
    return await db.transaction((txn) {
      return txnGetProjectBySyncedId(txn, uid, userId: userId);
    });
  }

  /// Get Project by synced id
  Future<DbProject?> txnGetProjectBySyncedId(DbTransaction txn, String uid,
      {required String userId}) async {
    return dbProjectStore
        .query(
            finder: Finder(
                filter: Filter.and([
          Filter.equals(dbProjectModel.userId.name, userId),
          Filter.equals(dbProjectModel.uid.name, uid)
        ])))
        .getRecord(txn);
  }

  /// Get Project by local id
  Future<DbProject?> getProjectByLocalId(String projectId) async {
    await ready;
    return dbProjectStore.record(projectId).getSync(db);
  }

  /// Get Project by local id
  Future<DbProject?> getProject(ProjectRef projectRef) async {
    await ready;
    if (projectRef.id != null) {
      return getProjectByLocalId(projectRef.id!);
    } else {
      var userId = (await globalFirebaseContext.auth.onCurrentUser.first)?.uid;
      if (userId != null) {
        return getProjectBySyncedId(projectRef.syncedId!, userId: userId);
      }
    }
    return null;
  }
}

/// Global Projects db
final globalProjectsDb = ProjectsDb();
