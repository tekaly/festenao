import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tekaly_sdb_synced/synced_sdb_firestore.dart';
import 'package:tekartik_common_utils/map/lru_map.dart';

import '../../provider.dart';

part 'blog_providers.g.dart';

class SdbProjectContentBlog {
  final SdbProjectsContentBlogCache cache;
  final SdbUserProject project;
  final String dataId;
  late final BlogSdb blogSdb;
  final AppFlavorContext appFlavorContext;

  final _readyCompleter = Completer<void>();
  Future<void> get ready => _readyCompleter.future;

  late AutoSynchronizedFirestoreSyncedSdb _autoSyncedSdb;

  SyncedSdb get syncedSdb => _autoSyncedSdb.syncedSdb;

  SdbProjectContentBlog({
    required this.cache,
    required this.project,
    required this.dataId,
    required this.appFlavorContext,
  }) {
    () async {
      cvAddConstructor(DbBlog.new);
      _autoSyncedSdb = await openProjectSyncedSdb(
        userProjectsSdb: cache.userProjectsSdb,
        appFlavorContext: appFlavorContext,
        firestore: cache.firestore,
        project: project,
        dataId: dataId,
        openOptions: _sdbBlogOpenOptions,
      );
      blogSdb = BlogSdb._(db: _autoSyncedSdb.database);
      _readyCompleter.complete();
    }();
  }

  Future<SyncedSyncStat> synchronize() => _autoSyncedSdb.synchronize();

  void dispose() {
    _autoSyncedSdb.close();
  }
}

/// Blog entry model stored in the local sdb.
class DbBlog extends ScvStringRecordBase {
  final title = CvField<String>('title');
  final content = CvField<String>('content');
  final timestamp = CvField<SdbTimestamp>('timestamp');

  @override
  CvFields get fields => [title, content, timestamp];
}

final dbBlogStore = scvStringStoreFactory.store<DbBlog>('blog');

class BlogSdb {
  final SdbDatabase _db;

  BlogSdb._({required this._db});

  SdbDatabase get db => _db;

  Stream<List<DbBlog>> onBlogs() => dbBlogStore.onRecords(_db);

  Future<DbBlog> addBlog(DbBlog blog) => dbBlogStore.add(_db, blog);

  Future<void> deleteBlog(String id) => dbBlogStore.record(id).delete(_db);
}

var _sdbBlogOpenOptions = SdbOpenDatabaseOptions(
  version: 1,
  schema: SdbDatabaseSchema(
    stores: [dbBlogStore.schema(), ...syncedSdbMetaSchema.stores],
  ),
);

Future<AutoSynchronizedFirestoreSyncedSdb> openProjectSyncedSdb({
  required Firestore firestore,
  required UserProjectsSdb userProjectsSdb,
  required AppFlavorContext appFlavorContext,
  required SdbUserProject project,
  required String dataId,
  required SdbOpenDatabaseOptions openOptions,
}) {
  var app = appFlavorContext.app;
  var projectUid = project.uid.v!;
  return AutoSynchronizedFirestoreSyncedSdb.open(
    options: AutoSynchronizedFirestoreSyncedSdbOptions(
      firestore: firestore,
      syncedSdbOptions: SyncedSdbOptions(openDatabaseOptions: openOptions),
      databaseFactory: userProjectsSdb.factory,
      rootDocumentPath: 'app/$app/project/$projectUid/data/$dataId',
      dbName: '${dataId}_${app}_${projectUid}_synced.db',
    ),
  );
}

Future<void> accessPublicProject(
  UserProjectsSdb projectsSdb,
  String projectId,
) async {
  var userId = ''; // No userId, representing public/unauthenticated list
  await projectsSdb.setCurrentIdentityId(userId);
  var existing = await projectsSdb.getProject(projectId, userId: userId);
  if (existing == null) {
    var fsProjectDb = globalFestenaoFirestoreDatabase.projectDb;
    var firestore = fsProjectDb.firestore;
    var fsProject = await fsProjectDb.fsEntityRef(projectId).get(firestore);
    if (fsProject.exists && fsProject.deleted.v != true) {
      var newDbProject = SdbUserProject()
        ..uid.v = projectId
        ..userId.v = userId
        ..name.v = fsProject.name.v;

      newDbProject.read.v = true;
      await projectsSdb.ready;
      var db = projectsSdb.db;
      await dbProjectStore.inTransaction(db, SdbTransactionMode.readWrite, (
        txn,
      ) async {
        var existingInTxn = await userProjectIndex
            .record(userId, projectId)
            .get(txn);
        if (existingInTxn == null) {
          await dbProjectStore.add(txn, newDbProject);
        } else {
          await dbProjectStore
              .record(existingInTxn.record.id)
              .put(txn, newDbProject);
        }
      });
    }
  }
}

class SdbProjectsContentBlogCache {
  final UserProjectsSdb userProjectsSdb;
  final AppFlavorContext appFlavorContext;
  // final projectsSdbBloc = globalFestenaoUserProjectsSdbBloc;
  final Firestore firestore;

  SdbProjectsContentBlogCache(
    Firestore? firestore, {
    required this.userProjectsSdb,
    required this.appFlavorContext,
  }) : firestore = firestore ?? Firestore.instance;

  final _lru = LruMap<(String, String), SdbProjectContentBlog>(
    maximumSize: 4,
    dispose: (entry) {
      entry.value.dispose();
    },
  );

  Future<SdbProjectContentBlog> blog(String projectId, String dataId) async {
    var key = (projectId, dataId);
    var cached = _lru[key];
    if (cached != null) return cached;

    var userId = ''; // without userId
    await userProjectsSdb.setCurrentIdentityId(userId);

    // Make sure the project is added if accessed for the first time
    await accessPublicProject(userProjectsSdb, projectId);

    var sdbProject = await userProjectsSdb.getProject(
      projectId,
      userId: userId,
    );
    if (sdbProject == null) {
      throw StateError('Project $projectId not found');
    }
    var blog = SdbProjectContentBlog(
      appFlavorContext: appFlavorContext,
      cache: this,
      project: sdbProject,
      dataId: dataId,
    );
    await blog.ready;
    _lru[key] = blog;
    return blog;
  }
}

@riverpod
SdbProjectsContentBlogCache blogCache(Ref ref) {
  var firestore = ref.watch(rpdFirestoreProvider);
  var userProjectSdb = ref.watch(festenaoUserProjectsSdbProvider).requireValue!;
  var appFlavorContext = ref
      .watch(festenaoAppFlavorContextProvider)
      .appFlavorContext;
  return SdbProjectsContentBlogCache(
    firestore,
    userProjectsSdb: userProjectSdb,
    appFlavorContext: appFlavorContext,
  );
}

@riverpod
Future<SdbProjectContentBlog> blogContent(
  Ref ref,
  String projectId,
  String dataId,
) {
  return ref.watch(blogCacheProvider).blog(projectId, dataId);
}

@riverpod
Stream<BlogSdb?> blogSdb(Ref ref, String projectId, String dataId) async* {
  var content = await ref.watch(blogContentProvider(projectId, dataId).future);
  yield content.blogSdb;
}

@riverpod
Stream<List<DbBlog>> blogEntries(Ref ref, String projectId, String dataId) {
  return ref
      .watch(blogSdbProvider(projectId, dataId))
      .when(
        data: (sdb) => sdb?.onBlogs() ?? Stream.value([]),
        loading: () => Stream.value([]),
        error: (_, _) => Stream.value([]),
      );
}

@riverpod
Stream<List<SdbUserProject>> publicUserProjects(Ref ref) {
  var projectsDb = ref.watch(rpdUserProjectsDbProvider);
  return projectsDb.onProjects(userId: '');
}
