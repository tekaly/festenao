import 'package:festenao_common/festenao_audi.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_sembast.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:tekaly_sdb_synced/synced_sdb_firestore.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';
import 'package:tekartik_common_utils/env_utils.dart';
export 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';

/// Database record for a project user.
class SdbProjectsUser extends ScvStringRecordBase {
  /// Timestamp when the user is ready.
  final readyTimestamp = CvField<SdbTimestamp>('readyTimestamp');

  @override
  CvFields get fields => [readyTimestamp];
}

/// Database record for a project.
class SdbUserProject extends ScvStringRecordBase with TkCmsCvUserAccessMixin {
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

/// Extension for local path derivation for a project's festenao SDB.
extension SdbUserProjectLocalPath on SdbUserProject {
  /// Local database name for the project's festenao synchronized SDB.
  String get festenaoSdbName => 'festenao_$fsId.db';
}

/// Extension for [DbProject]
extension SdbUserProjectUtils on SdbUserProject {
  /// Update the [DbProject] from a [FsProject]
  void fromFirestore({
    required FsProject fsProject,

    /// Optional can be need after a create
    String? projectId,
    required TkCmsFsUserAccess? projectAccess,
    required String userId,
  }) {
    name.v = fsProject.name.v;
    uid.v = projectId ?? fsProject.id;
    this.userId.setValue(userId);
    if (projectAccess != null) {
      userAccessFields.fromCvFields(projectAccess.userAccessFields);
    }
  }

  /// Check if the [DbProject] need to be updated from another [DbProject]
  bool needUpdate(SdbUserProject project) {
    return name.v != project.name.v ||
        uid.v != project.uid.v ||
        userId.v != project.userId.v ||
        admin.v != project.admin.v ||
        write.v != project.write.v ||
        read.v != project.read.v ||
        role.v != project.role.v;
  }
}

/// The model for DbProject.
final dbProjectModel = SdbUserProject();

/// Initializes the database builders for projects.
void initDbProjectsBuilders() {
  cvAddConstructors([SdbUserProject.new, SdbProjectsUser.new]);
}

/// Name of the projects database.
const projectsDbName = 'projects_v1.db';

/// Store for project records.
final dbProjectStore = scvStringStoreFactory.store<SdbUserProject>('project');
//final dbProjectStoreIndex = dbProjectStore.index('user_project');

/// Store for project user records.
final dbProjectUserStore = scvStringStoreFactory.store<SdbProjectsUser>(
  'project_user',
);

/// Index for project user records.
final userProjectIndex = dbProjectStore.index2<String, String>(
  'user_project_idx',
);

/// Index for project user records.
final userProjectsIndex = dbProjectStore.index<String>('user_idx');

/// Schema for project user records.
final userProjectsIndexSchema = userProjectsIndex.schema(
  keyPath: dbProjectModel.userId.key,
);

/// Schema for user project records index.
final userProjectIndexSchema = userProjectIndex.schema(
  keyPath: [dbProjectModel.userId.key, dbProjectModel.uid.key],
);

/// Store schemas for the projects database.
List<SdbStoreSchema> userProjectsSdbStoreSchemas() => [
  dbProjectUserStore.schema(),
  dbProjectStore.schema(
    indexes: [userProjectIndexSchema, userProjectsIndexSchema],
  ),
];

/// Firestore root document path of the per user private projects database
/// `app/<appId>/user_prv/<userId>/data/projects`.
String fsUserPrvProjectsPath({required String app, required String userId}) =>
    fsAppRoot(app)
        .collection('user_prv')
        .doc(userId)
        .collection('data')
        .doc('projects')
        .path;

/// Sync options for a per user synced [UserProjectsSdb].
class UserProjectsSdbSyncOptions {
  /// Firestore instance.
  final Firestore firestore;

  /// App id.
  final String app;

  /// User id.
  final String userId;

  /// Sync options for a per user synced [UserProjectsSdb].
  UserProjectsSdbSyncOptions({
    required this.firestore,
    required this.app,
    required this.userId,
  });
}

/// Projects database manager.
class UserProjectsSdb {
  /// Database factory (sandboxed to the user id for a per user database).
  final SdbFactory factory;

  /// Name of the database.
  final String? name;

  /// Sync options, non null for a per user database synced to firestore.
  final UserProjectsSdbSyncOptions? syncOptions;

  /// User id, non null for a per user database.
  String? get userId => syncOptions?.userId;

  /// True when the database is synchronized to firestore.
  bool get isSynced => syncOptions != null;

  AutoSynchronizedFirestoreSyncedSdb? _autoSyncedSdb;

  /// The synced database, only valid when [isSynced] and [ready].
  AutoSynchronizedFirestoreSyncedSdb get autoSyncedSdb => _autoSyncedSdb!;

  /// The database instance.
  late final SdbDatabase db;

  SdbOpenDatabaseOptions _openDatabaseOptions({required bool synced}) =>
      SdbOpenDatabaseOptions(
        version: 2,
        schema: SdbDatabaseSchema(
          stores: [
            ...userProjectsSdbStoreSchemas(),
            if (synced) ...syncedSdbMetaSchema.stores,
          ],
        ),
      );

  /// Future that completes when the database is ready.
  late final Future<void> ready = () async {
    var dbName = name ?? projectsDbName;
    if (isDebug) {
      // ignore: avoid_print
      print(
        'UserProjectSdb ${factory.name} Opening ${await factory.getDatabaseFullPath(dbName)}',
      );
    }
    var syncOptions = this.syncOptions;
    if (syncOptions != null) {
      var autoSyncedSdb = await AutoSynchronizedFirestoreSyncedSdb.open(
        options: AutoSynchronizedFirestoreSyncedSdbOptions(
          firestore: syncOptions.firestore,
          databaseFactory: factory,
          dbName: dbName,
          rootDocumentPath: fsUserPrvProjectsPath(
            app: syncOptions.app,
            userId: syncOptions.userId,
          ),
          syncedSdbOptions: SyncedSdbOptions(
            openDatabaseOptions: _openDatabaseOptions(synced: true),
          ),
        ),
      );
      _autoSyncedSdb = autoSyncedSdb;
      db = autoSyncedSdb.database;
    } else {
      db = await factory.openDatabase(
        dbName,
        options: _openDatabaseOptions(synced: false),
      );
    }
    initDbProjectsBuilders();
  }();
  final _projectUserUpdated = BehaviorSubject<SdbProjectsUser?>();

  /// Creates a new [UserProjectsSdb] with the given [factory] and [name].
  UserProjectsSdb({required this.factory, required this.name})
    : syncOptions = null;

  /// Per user database synced to firestore
  /// `app/<app>/user_prv/<userId>/data/projects`.
  ///
  /// The [factory] is sandboxed to the user id so that each user gets its own
  /// local database.
  UserProjectsSdb.userSynced({
    required SdbFactory factory,
    this.name,
    required Firestore firestore,
    required String app,
    required String userId,
  }) : factory = factory.sandbox(path: userId),
       syncOptions = UserProjectsSdbSyncOptions(
         firestore: firestore,
         app: app,
         userId: userId,
       );

  /// All in memory database
  UserProjectsSdb.inMemory()
    : this(factory: sdbFactoryMemory, name: 'in_memory');

  /// Trigger a firestore synchronization (no-op for a local only database).
  Future<void> synchronize() async {
    await ready;
    await _autoSyncedSdb?.synchronize();
  }

  /// Project user
  Stream<SdbProjectsUser?> onProjectsUser({required String userId}) async* {
    await ready;
    yield* dbProjectUserStore.record(userId).onRecord(db);
  }

  bool _userReady(SdbProjectsUser user) => user.readyTimestamp.value != null;

  /// Project user ready, or null if no user.
  Stream<SdbProjectsUser?> onProjectsUserReady({
    required String userId,
  }) async* {
    await ready;
    yield* onProjectsUser(
      userId: userId,
    ).where((item) => item == null || _userReady(item));
  }

  /// Project user ready
  Future<SdbProjectsUser?> projectsUserReady({required String userId}) async {
    await ready;
    return await onProjectsUserReady(userId: userId).first;
  }

  /// Project user
  Future<SdbProjectsUser?> getProjectsUser({required String userId}) async {
    await ready;
    return await dbProjectUserStore.record(userId).get(db);
  }

  /// Stream of projects for the given [userId].
  Stream<List<SdbUserProject>> onProjects({required String userId}) async* {
    await for (var user in onProjectsUserReady(userId: userId)) {
      if (user != null) {
        yield* userProjectsIndex.record(userId).onObjects(db);
      }
    }
  }

  /// Get the projects for the given [userId].
  Future<List<SdbUserProject>> getProjects({required String userId}) async {
    await ready;

    return (await userProjectsIndex.record(userId).findRecords(db))
        .map((item) => item.record)
        .toList();
  }

  /// Stream of a single project for the given [projectId] and [userId].
  Stream<SdbUserProject?> onProject(
    String projectId, {
    required String userId,
  }) async* {
    await ready;
    yield* userProjectIndex.record(userId, projectId).onObject(db);
  }

  /// Gets a single project for the given [projectId] and [userId].
  Future<SdbUserProject?> getProject(
    String projectId, {
    required String userId,
  }) async {
    // await projectUserReady(userId: userId);
    await ready;
    return (await userProjectIndex.record(userId, projectId).get(db))?.record;
  }

  /// Adds a new project to the database.
  Future<void> addProject(SdbUserProject project) async {
    await ready;
    assert(!project.hasId);
    await db.inStoreTransaction(
      dbProjectStore.rawRef,
      SdbTransactionMode.readWrite,
      (txn) async {
        await dbProjectStore.add(txn, project);
      },
    );
  }

  /// Deletes a project for the given [projectId] and [userId].
  Future<void> deleteProject(String projectId, {required String userId}) async {
    await ready;

    await dbProjectStore.inTransaction(db, SdbTransactionMode.readWrite, (
      txn,
    ) async {
      await userProjectIndex.record(userId, projectId).delete(txn);
    });
  }

  /// Deletes a project for the given [projectId] and [userId].
  Future<void> deleteProjects({required String userId}) async {
    await ready;

    await dbProjectStore.inTransaction(db, SdbTransactionMode.readWrite, (
      txn,
    ) async {
      await userProjectsIndex.record(userId).delete(txn);
    });
  }

  /// Clears all data from the database.
  Future<void> clear() async {
    await ready;
    await db.inScvStoresTransaction(
      [dbProjectStore, dbProjectUserStore],
      SdbTransactionMode.readWrite,
      (txn) async {
        await dbProjectStore.delete(txn);
        await dbProjectUserStore.delete(txn);
      },
    );
  }

  /// Sets the current identity ID and initializes the user record if needed.
  Future<void> setCurrentIdentityId(String identityId) async {
    await ready;
    var client = db;
    await clientSetCurrentIdentityId(client, identityId);
  }

  /// Sets the current identity ID and initializes the user record if needed.
  Future<void> clientSetCurrentIdentityId(
    SdbClient client,
    String identityId,
  ) async {
    await ready;
    var record = dbProjectUserStore.record(identityId);
    var dbUser = await dbProjectUserStore.record(identityId).get(client);
    if (dbUser?.readyTimestamp.v == null) {
      await record.put(
        client,
        SdbProjectsUser()..readyTimestamp.v = DbTimestamp.now(),
      );
    }
    _projectUserUpdated.add(dbUser);
  }

  /// Closing the db (stops the synchronizer for a synced database)
  Future<void> close() async {
    await ready;
    var autoSyncedSdb = _autoSyncedSdb;
    if (autoSyncedSdb != null) {
      await autoSyncedSdb.close();
    } else {
      await db.close();
    }
    await _projectUserUpdated.close();
  }
}

/// Global projects database instance.
/// Initialized once and used throughout the admin application.
UserProjectsSdb get globalProjectsSdb => globalProjectsSdbOrNull!;

/// Global projects database instance or null.
UserProjectsSdb? globalProjectsSdbOrNull;

/// Sets the global projects database instance.
set globalProjectsSdb(UserProjectsSdb value) {
  globalProjectsSdbOrNull = value;
}
