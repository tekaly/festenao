import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_sembast.dart';

export 'package:tekartik_app_cv_sembast/app_cv_sembast.dart';

/// Key is the user id
class DbProjectUser extends DbStringRecordBase {
  /// Timestamp when the user is ready
  final readyTimestamp = CvField<DbTimestamp>('readyTimestamp');

  @override
  CvFields get fields => [readyTimestamp];
}

/// Project, its id matches the firestore id
class DbProject extends DbStringRecordBase with TkCmsCvUserAccessMixin {
  String get fsId => uid.v!;

  /// Name
  final name = CvField<String>('name');

  /// Firestore uid - not null
  final uid = CvField<String>('uid');

  /// User id
  final userId = CvField<String>('userId');

  @override
  CvFields get fields => [name, userId, uid, ...userAccessMixinfields];

  /// True if the user has write access
  bool get isWrite => TkCmsCvUserAccessCommonExt(this).isWrite;

  /// True if the user has admin access
  bool get isAdmin => TkCmsCvUserAccessCommonExt(this).isRead;

  /// True if the user has read access
  bool get isRead => TkCmsCvUserAccessCommonExt(this).isRead;
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
final dbProjectStore = cvStringStoreFactory.store<DbProject>('project');

/// Project user store
final dbProjectUserStore = cvStringStoreFactory.store<DbProjectUser>(
  'project_user',
);

/// Projects db
class ProjectsDb {
  final DatabaseFactory factory;
  final String name;

  /// Database
  late final Database db;

  /// ready state
  late final Future<void> ready = () async {
    db = await factory.openDatabase(projectsDbName);
    initDbProjectsBuilders();
  }();

  ProjectsDb({required this.factory, required this.name});

  /// on Projects
  Stream<List<DbProject>> onProjects({required String userId}) async* {
    await ready;
    await dbProjectUserStore
        .record(userId)
        .onRecord(db)
        .firstWhere((user) => user?.readyTimestamp.value != null);
    yield* getProjectsQuery(userId: userId).onRecords(db);
  }

  /// on Projects
  Stream<DbProject?> onProject(
    String projectId, {
    required String userId,
  }) async* {
    await ready;
    yield* _getProjectQuery(projectId, userId: userId).onRecord(db);
  }

  Future<DbProject?> getProject(
    String projectId, {
    required String userId,
  }) async {
    await ready;
    return await _getProjectQuery(projectId, userId: userId).getRecord(db);
  }

  Future<void> addProject(DbProject project) async {
    await ready;
    assert(!project.hasId);
    await db.transaction((txn) async {
      await dbProjectStore.add(txn, project);
    });
  }

  /// Delete Project
  Future<void> deleteProject(String projectId, {required String userId}) async {
    await dbProjectStore.delete(
      db,
      finder: _getProjectFinder(projectId, userId: userId),
    );
  }

  /// Query
  CvQueryRef<String, DbProject> getProjectsQuery({required String userId}) {
    return dbProjectStore.query(
      finder: Finder(
        filter: Filter.or([
          Filter.equals(dbProjectModel.userId.name, userId),
          // Filter.isNull(dbProjectModel.uid.name),
        ]),
      ),
    );
  }

  // Query
  CvQueryRef<String, DbProject> _getProjectQuery(
    String projectId, {
    required String userId,
  }) {
    return dbProjectStore.query(
      finder: _getProjectFinder(projectId, userId: userId),
    );
  }

  Finder _getProjectFinder(String projectId, {required String userId}) {
    return Finder(
      filter: Filter.and([
        Filter.equals(dbProjectModel.userId.name, userId),
        Filter.equals(dbProjectModel.uid.name, projectId),
      ]),
    );
  }

  Finder getProjectFinder({required String userId, required String projectId}) {
    return Finder(
      filter: Filter.and([
        Filter.equals(dbProjectModel.userId.name, userId),
        Filter.equals(dbProjectModel.uid.name, projectId),
      ]),
    );
  }

  Future<void> clear() async {
    await ready;
    await db.transaction((txn) async {
      await dbProjectStore.delete(txn);
      await dbProjectUserStore.delete(txn);
    });
  }
}

/// Global Projects db
late ProjectsDb globalProjectsDb;
