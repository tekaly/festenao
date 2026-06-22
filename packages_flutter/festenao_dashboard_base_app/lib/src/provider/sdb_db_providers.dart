import 'dart:async';

import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_common/data/festenao_media_sdb.dart';
import 'package:festenao_common/data/festenao_media_source.dart';
import 'package:festenao_common/data/festenao_projects_fs.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/festenao/sync/sync_source_options.dart';
import 'package:festenao_common/data/src/festenao_sdb.dart';
import 'package:festenao_common/data/src/festenao_synced_sdb.dart';
import 'package:festenao_common/festenao_firebase_rest.dart';
import 'package:festenao_dashboard_base_app/src/provider/firebase_app_rpd.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_blog_demo_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tekaly_sdb_synced/synced_sdb_firestore.dart';
import 'package:tekartik_common_utils/map/lru_map.dart';
part 'sdb_db_providers.g.dart';

// ─── Generic helper ───────────────────────────────────────────────────────────

// Note: the deprecated `openProjectSyncedSdb` helper that previously lived here
// has been removed in favour of the one in `blog_providers.dart` (now part of
// this same package) to avoid an ambiguous export.

/// Opens an [AutoSynchronizedFirestoreSyncedSdb] for a given project at
/// `app/<app>/project/<projectUid>/data/<dataId>`.
///
/// Reused by every project-scoped content database (blog, festenao content, …).
Future<FestenaoSyncedSdb> openProjectFestenaoSyncedSdb({
  FileSystem? fs,
  FileSystem? rootFs,
  required FestenaoUserProjectsSdbBloc projectsSdbBloc,

  required SdbUserProject project,
  required String dataId,
  required Firestore firestore,
  required FirebaseStorage firebaseStorage,
  required SdbOpenDatabaseOptions openOptions,
}) async {
  var app = projectsSdbBloc.appFlavorContext.app;
  var projectUid = project.uid.v!;
  var sdbFactory = projectsSdbBloc.projectsSdb.factory;
  var dbName = '${dataId}_${app}_${projectUid}_synced.db';
  var fileSystem = fs;
  var rootDocPath = 'app/$app/project/$projectUid/data/$dataId';
  var syncSourceOption = FestenaoSyncSourceOptions(
    firebaseProjectId: projectUid,
    firestoreRoot: rootDocPath,
    storageRoot: rootDocPath,
    storageBucket: firebaseStorage.app.options.storageBucket!,
  );
  fileSystem ??= rootFs!.sandbox(path: rootFs.path.join(projectUid, dataId));

  var festenaoSdb = FestenaoSdb(
    sdbFactory: sdbFactory,
    dbName: dbName,
    fs: fileSystem,
    syncedSdbOptions: SyncedSdbOptions(openDatabaseOptions: openOptions),
  );
  await festenaoSdb.ready;
  return FestenaoSyncedSdb(
    db: festenaoSdb,
    sourceOptions: syncSourceOption,
    firebaseStorage: firebaseStorage,
    firestore: firestore,
  );
}

/// LRU cache of per-project [SdbProjectContent] instances.
class SdbProjectsContentCache {
  final projectsSdbBloc = globalFestenaoUserProjectsSdbBloc;
  final projectsFsBloc = globalFestenaoUserProjectsFsBloc;
  final Firestore firestore;

  SdbProjectsContentCache(Firestore? firestore)
    : firestore = firestore ?? Firestore.instance;

  final _lru = LruMap<(String, String), SdbProjectContent>(
    maximumSize: 4,
    dispose: (entry) => entry.value.dispose(),
  );

  Future<SdbProjectContent> content(String projectId, String dataId) async {
    var key = (projectId, dataId);
    var cached = _lru[key];
    if (cached != null) return cached;
    var projectSdbBloc = FestenaoUserProjectSdbBloc(
      projectsSdbBloc: projectsSdbBloc,
      projectId: projectId,
    );
    var sdbProject = await projectSdbBloc.projectStream.whereNotNull().first;
    var fs = projectsFsBloc.fs;
    fs = fs.sandbox(path: fs.path.join(projectId, dataId));
    var content = SdbProjectContent(
      fs: fs,
      cache: this,
      project: sdbProject,
      dataId: dataId,
    );
    await content.ready;
    _lru[key] = content;
    return content;
  }
}

class SdbProjectContentOptions {
  final String dataId;
  final SdbOpenDatabaseOptions openDatabaseOptions;

  SdbProjectContentOptions({
    required this.dataId,
    required this.openDatabaseOptions,
  });
}

/// Per-project synced SDB holding artist, event, image, and location stores.
class SdbProjectContent {
  /// Default data id for festenao
  static const defaultDataId = 'content';
  final SdbProjectsContentCache cache;
  final SdbUserProject project;
  final String dataId;
  final FileSystem fs;
  late final SdfContentSdb contentSdb;

  FestenaoMediaSource? get mediaSource => _festenaoSyncedSdb.mediaSource;
  final _readyCompleter = Completer<void>();
  Future<void> get ready => _readyCompleter.future;

  late FestenaoSyncedSdb _festenaoSyncedSdb;
  //late AutoSynchronizedFirestoreSyncedSdb _autoSyncedSdb;

  // Add a global option
  static void addContentOptions(SdbProjectContentOptions options) {
    _map[options.dataId] = options;
  }

  static final _map = <String, SdbProjectContentOptions>{};
  SyncedSdb get syncedSdb => _festenaoSyncedSdb.db.syncedSdb;

  SdbProjectContent({
    required this.cache,
    required this.project,
    required this.dataId,
    required this.fs,
  }) {
    () async {
      initSdfConstructors();
      try {
        var openOptions =
            _map[dataId]?.openDatabaseOptions ?? sdfContentOpenOptions;
        var festenaoSyncedSdb = await openProjectFestenaoSyncedSdb(
          fs: fs,
          projectsSdbBloc: cache.projectsSdbBloc,

          project: project,
          dataId: dataId,
          firestore: Firestore.instance,
          firebaseStorage: FirebaseStorage.instance,
          openOptions: openOptions,
        );
        _festenaoSyncedSdb = festenaoSyncedSdb;
        /*
      _autoSyncedSdb = await openProjectSyncedSdb(
        projectsSdbBloc: cache.projectsSdbBloc,
        firestore: cache.firestore,
        project: project,
        dataId: dataId,
        openOptions: sdfContentOpenOptions,
      );*/
        contentSdb = SdfContentSdb(
          fs: fs,
          db: await _festenaoSyncedSdb.db.syncedSdb.database,
        );
        _readyCompleter.complete();
      } catch (e) {
        // ignore: avoid_print
        print('error init: $e');
        rethrow;
      }
    }();
  }

  Future<SyncedSyncStat> synchronize() => _festenaoSyncedSdb.synchronize();

  void dispose() {
    _festenaoSyncedSdb.dispose();
  }
}

// ─── Riverpod providers ───────────────────────────────────────────────────────

// Blog demo providers (blogCache/blogContent/blogSdb/blogEntries) live in
// `blog_providers.dart` (now part of this package). They were previously
// duplicated here; removed to avoid an ambiguous export.

// Festenao content providers (artist / event / image / location)

@Riverpod(keepAlive: true)
SdbProjectsContentCache contentCache(Ref ref) {
  var firestore = ref.watch(rpdFirestoreProvider);
  return SdbProjectsContentCache(firestore);
}

@riverpod
Future<SdbProjectContent> projectContent(
  Ref ref,
  String projectId,
  String dataId,
) {
  return ref.watch(contentCacheProvider).content(projectId, dataId);
}

@riverpod
Stream<SdbProjectContent> sdbProjectContent(
  Ref ref,
  String projectId,
  String dataId,
) async* {
  var content = await ref.watch(
    projectContentProvider(projectId, dataId).future,
  );
  yield content;
}

@riverpod
Stream<SdfContentSdb?> contentSdb(
  Ref ref,
  String projectId,
  String dataId,
) async* {
  var content = await ref.watch(
    projectContentProvider(projectId, dataId).future,
  );
  yield content.contentSdb;
}

@riverpod
Stream<List<SdfArtist>> artistEntries(
  Ref ref,
  String projectId,
  String dataId,
) {
  return ref
      .watch(contentSdbProvider(projectId, dataId))
      .when(
        data: (sdb) => sdb?.onArtists() ?? Stream.value([]),
        loading: () => Stream.value([]),
        error: (_, _) => Stream.value([]),
      );
}

@riverpod
Stream<List<SdfEvent>> eventEntries(Ref ref, String projectId, String dataId) {
  return ref
      .watch(contentSdbProvider(projectId, dataId))
      .when(
        data: (sdb) => sdb?.onEvents() ?? Stream.value([]),
        loading: () => Stream.value([]),
        error: (_, _) => Stream.value([]),
      );
}

@riverpod
Stream<List<SdfImage>> imageEntries(Ref ref, String projectId, String dataId) {
  return ref
      .watch(contentSdbProvider(projectId, dataId))
      .when(
        data: (sdb) => sdb?.onImages() ?? Stream.value([]),
        loading: () => Stream.value([]),
        error: (_, _) => Stream.value([]),
      );
}

@riverpod
Stream<SdfImage?> imageEntry(
  Ref ref,
  String projectId,
  String dataId,
  String imageId,
) {
  return ref
      .watch(contentSdbProvider(projectId, dataId))
      .when(
        data: (sdb) => sdb?.onImage(imageId) ?? Stream.value(null),
        loading: () => Stream.value(null),
        error: (_, _) => Stream.value(null),
      );
}

@riverpod
Stream<List<SdbFestenaoMediaFile>> mediaEntries(
  Ref ref,
  String projectId,
  String dataId,
) {
  return ref
      .watch(contentSdbProvider(projectId, dataId))
      .when(
        data: (sdb) =>
            sdb?.mediaDb.onMediaFiles() ??
            Stream.value(<SdbFestenaoMediaFile>[]),
        loading: () => Stream.value(<SdbFestenaoMediaFile>[]),
        error: (_, _) => Stream.value(<SdbFestenaoMediaFile>[]),
      );
}

@riverpod
Stream<SdbFestenaoMediaFile?> mediaEntry(
  Ref ref,
  String projectId,
  String dataId,
  String mediaId,
) {
  return ref
      .watch(contentSdbProvider(projectId, dataId))
      .when(
        data: (sdb) => sdb?.mediaDb.onMediaFile(mediaId) ?? Stream.value(null),
        loading: () => Stream.value(null),
        error: (_, _) => Stream.value(null),
      );
}

@riverpod
Stream<SdbFestenaoMediaFileStatus?> mediaStatusFileEntry(
  Ref ref,
  String projectId,
  String dataId,
  String mediaId,
) {
  return ref
      .watch(contentSdbProvider(projectId, dataId))
      .when(
        data: (sdb) =>
            sdb?.mediaDb.onMediaStatusFile(mediaId) ?? Stream.value(null),
        loading: () => Stream.value(null),
        error: (_, _) => Stream.value(null),
      );
}

@riverpod
Stream<List<SdfLocation>> locationEntries(
  Ref ref,
  String projectId,
  String dataId,
) {
  return ref
      .watch(contentSdbProvider(projectId, dataId))
      .when(
        data: (sdb) => sdb?.onLocations() ?? Stream.value([]),
        loading: () => Stream.value([]),
        error: (_, _) => Stream.value([]),
      );
}
