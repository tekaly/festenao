import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_common/data/festenao_media_sdb.dart';
import 'package:festenao_common/data/festenao_media_sdb_synchronizer.dart'
    show SyncedMediaCacheOptions;
import 'package:festenao_common/data/festenao_media_source.dart';
import 'package:festenao_common/data/festenao_projects_fs.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/festenao_synced_sdb.dart';
import 'package:festenao_common/festenao_firebase_rest.dart';
import 'package:festenao_dashboard_base_app/src/provider/festenao_user_projects.dart';
import 'package:festenao_dashboard_base_app/src/provider/firebase_app_rpd.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_blog_demo_providers.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_home_screen_bloc.dart';
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tekaly_sdb_synced/synced_sdb_firestore.dart';
import 'package:tekartik_common_utils/map/lru_map.dart';
import 'package:tkcms_common/tkcms_common.dart';

export 'package:festenao_common/data/festenao_projects_sdb.dart'
    show openProjectFestenaoSyncedSdb;

part 'sdb_db_providers.g.dart';

// ─── Generic helper ───────────────────────────────────────────────────────────

// Note: the deprecated `openProjectSyncedSdb` helper that previously lived here
// has been removed in favour of the one in `blog_providers.dart` (now part of
// this same package) to avoid an ambiguous export.

/// LRU cache of per-project [SdbProjectContent] instances.
class SdbProjectsContentCache {
  /// The (possibly per user) local projects database.
  final UserProjectsSdb projectsSdb;

  /// The app id, used to namespace the per-project synced sdb.
  final String app;

  final projectsFsBloc = globalFestenaoUserProjectsFsBloc;

  /// The Firestore the contents synchronize with.
  final Firestore firestore;

  /// The storage of the media files of the contents, the one of the default
  /// app ([FirebaseStorage.instance]) when null.
  final FirebaseStorage? firebaseStorage;

  SdbProjectsContentCache({
    required this.projectsSdb,
    required this.app,
    Firestore? firestore,
    this.firebaseStorage,
  }) : firestore = firestore ?? Firestore.instance;

  /// A project may hold several data ids open (an app with its content and
  /// its own data ids), two projects at once (a copy).
  final _lru = LruMap<(String, String), SdbProjectContent>(
    maximumSize: 8,
    dispose: (entry) => entry.value.dispose(),
  );

  Future<SdbProjectContent> content(String projectId, String dataId) async {
    var key = (projectId, dataId);
    var cached = _lru[key];
    if (cached != null) return cached;
    var projectSdbBloc = ProjectHomeScreenBloc(
      projectsSdb: projectsSdb,
      projectId: projectId,
    );
    var sdbProject = await projectSdbBloc.state.whereNotNull().first;
    projectSdbBloc.dispose();
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

  Future<void> deleteData() async {
    var sdbFactory = projectsSdb.factory;
    var name = projectsSdb.db.name;
    await projectsSdb.close();
    await sdbFactory.deleteDatabase(name);
  }
}

class SdbProjectContentOptions {
  final String dataId;
  final SdbOpenDatabaseOptions openDatabaseOptions;

  /// The partition of the records of the data id for the user of a project
  /// (their access), if any: see [SyncedSourcePartition].
  final SyncedSourcePartition? Function(SdbUserProject project)? partitionOf;

  /// The media contents kept locally, all of them when null (a data id read
  /// for its records only passes `SyncedMediaCacheOptions.lru()`: downloaded
  /// on demand, nothing prefetched).
  final SyncedMediaCacheOptions? mediaCacheOptions;

  SdbProjectContentOptions({
    required this.dataId,
    required this.openDatabaseOptions,
    this.partitionOf,
    this.mediaCacheOptions,
  });
}

/// Per-project synced SDB holding artist, event, image, and location stores.
class SdbProjectContent {
  /// Default data id for festenao
  static const defaultDataId = 'content';

  /// RAM cache
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
        var options = _map[dataId];
        var openOptions = options?.openDatabaseOptions ?? sdfContentOpenOptions;
        var festenaoSyncedSdb = await openProjectFestenaoSyncedSdb(
          fs: fs,
          app: cache.app,
          sdbFactory: cache.projectsSdb.factory,

          project: project,
          dataId: dataId,
          // The ones of the cache (its provider's), never the default app's.
          firestore: cache.firestore,
          firebaseStorage: cache.firebaseStorage ?? FirebaseStorage.instance,
          openOptions: openOptions,
          partition: options?.partitionOf?.call(project),
          mediaCacheOptions:
              options?.mediaCacheOptions ?? const SyncedMediaCacheOptions.all(),
        );
        _festenaoSyncedSdb = festenaoSyncedSdb;
        contentSdb = SdfContentSdb(
          fs: fs,
          db: await _festenaoSyncedSdb.db.syncedSdb.database,
        );
        _readyCompleter.complete();
      } catch (e, st) {
        // ignore: avoid_print
        print('error init: $e');
        // [ready] fails (it would never complete otherwise).
        _readyCompleter.completeError(e, st);
      }
    }();
  }

  Future<SyncedSyncStat> synchronize() => _festenaoSyncedSdb.synchronize();

  /// The synchronization status of the content database as it changes, once
  /// open.
  Stream<SyncedDbSyncStatus> onSyncStatus() async* {
    await ready;
    yield* _festenaoSyncedSdb.onSyncStatus();
  }

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
  var projectsSdb = ref.watch(rpdUserProjectsDbProvider);
  var app = ref.watch(festenaoAppFlavorContextProvider).appId;
  return SdbProjectsContentCache(
    projectsSdb: projectsSdb,
    app: app,
    firestore: firestore,
  );
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

/// The synchronization status of the content of `(projectId, dataId)`.
@riverpod
Stream<SyncedDbSyncStatus> projectContentSyncStatus(
  Ref ref,
  String projectId,
  String dataId,
) async* {
  var content = await ref.watch(
    projectContentProvider(projectId, dataId).future,
  );
  yield* content.onSyncStatus();
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
