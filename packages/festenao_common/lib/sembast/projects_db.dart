import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_sembast.dart';

export 'package:tekartik_app_cv_sembast/app_cv_sembast.dart';

/// Database record for a project user.
class DbProjectUser extends DbStringRecordBase {
  /// Timestamp when the user is ready.
  final readyTimestamp = CvField<DbTimestamp>('readyTimestamp');

  @override
  CvFields get fields => [readyTimestamp];
}

/// Database record for a project.
class DbProject extends DbStringRecordBase with TkCmsCvUserAccessMixin {
  /// Firestore ID of the project.
  String get fsId => uid.v!;

  /// Name of the project.
  final name = CvField<String>('name');

  /// Firestore UID - not null.
  final uid = CvField<String>('uid');

  /// User ID associated with the project.
  final userId = CvField<String>('userId');

  @override
  CvFields get fields => [name, userId, uid, ...userAccessMixinfields];

  /// True if the user has write access.
  bool get isWrite => TkCmsCvUserAccessCommonExt(this).isWrite;

  /// True if the user has admin access.
  bool get isAdmin => TkCmsCvUserAccessCommonExt(this).isRead;

  /// True if the user has read access.
  bool get isRead => TkCmsCvUserAccessCommonExt(this).isRead;
}

/// The model for DbProject.
final dbProjectModel = DbProject();

/// Initializes the database builders for projects.
void initDbProjectsBuilders() {
  cvAddConstructors([DbProject.new, DbProjectUser.new]);
}

/// Name of the projects database.
const projectsDbName = 'projects_v1.db';

/// Store for project records.
final dbProjectStore = cvStringStoreFactory.store<DbProject>('project');

/// Store for project user records.
final dbProjectUserStore = cvStringStoreFactory.store<DbProjectUser>(
  'project_user',
);

/// Projects database manager.
class ProjectsDb {
  /// Database factory.
  /// Database factory.
  final DatabaseFactory factory;

  /// Name of the database.
  final String name;

  /// The database instance.
  late final Database db;

  /// Future that completes when the database is ready.
  late final Future<void> ready = () async {
    db = await factory.openDatabase(projectsDbName);
    initDbProjectsBuilders();
  }();

  /// Sets the current identity ID and initializes the user record if needed.
  Future<void> setCurrentIdentityId(String identityId) async {
    var client = db;
    await clientSetCurrentIdentityId(client, identityId);
  }

  /// Sets the current identity ID and initializes the user record if needed.
  Future<void> clientSetCurrentIdentityId(
    DatabaseClient client,
    String identityId,
  ) async {
    var record = dbProjectUserStore.record(identityId);
    var dbUser = dbProjectUserStore.record(identityId).getSync(client);
    if (dbUser?.readyTimestamp.v == null) {
      await record.put(
        client,
        DbProjectUser()..readyTimestamp.v = DbTimestamp.now(),
      );
    }
  }

  /// Creates a new [ProjectsDb] with the given [factory] and [name].
  ProjectsDb({required this.factory, required this.name});

  /// Stream of projects for the given [userId].
  Stream<List<DbProject>> onProjects({required String userId}) async* {
    await ready;
    await dbProjectUserStore
        .record(userId)
        .onRecord(db)
        .firstWhere((user) => user?.readyTimestamp.value != null);
    yield* getProjectsQuery(userId: userId).onRecords(db);
  }

  /// Stream of a single project for the given [projectId] and [userId].
  Stream<DbProject?> onProject(
    String projectId, {
    required String userId,
  }) async* {
    await ready;
    yield* _getProjectQuery(projectId, userId: userId).onRecord(db);
  }

  /// Gets a single project for the given [projectId] and [userId].
  Future<DbProject?> getProject(
    String projectId, {
    required String userId,
  }) async {
    await ready;
    return await _getProjectQuery(projectId, userId: userId).getRecord(db);
  }

  /// Adds a new project to the database.
  Future<void> addProject(DbProject project) async {
    await ready;
    assert(!project.hasId);
    await db.transaction((txn) async {
      await dbProjectStore.add(txn, project);
    });
  }

  /// Deletes a project for the given [projectId] and [userId].
  Future<void> deleteProject(String projectId, {required String userId}) async {
    await dbProjectStore.delete(
      db,
      finder: _getProjectFinder(projectId, userId: userId),
    );
  }

  /// Gets a query for projects for the given [userId].
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

  /// Gets a finder for a project given [userId] and [projectId].
  Finder getProjectFinder({required String userId, required String projectId}) {
    return Finder(
      filter: Filter.and([
        Filter.equals(dbProjectModel.userId.name, userId),
        Filter.equals(dbProjectModel.uid.name, projectId),
      ]),
    );
  }

  /// Clears all data from the database.
  Future<void> clear() async {
    await ready;
    await db.transaction((txn) async {
      await dbProjectStore.delete(txn);
      await dbProjectUserStore.delete(txn);
    });
  }
}

/// Global projects database instance.
/// Initialized once and used throughout the admin application.
ProjectsDb get globalProjectsDb => globalProjectsDbOrNull!;

/// Global projects database instance or null.
ProjectsDb? globalProjectsDbOrNull;

/// Sets the global projects database instance.
set globalProjectsDb(ProjectsDb value) {
  globalProjectsDbOrNull = value;
}
