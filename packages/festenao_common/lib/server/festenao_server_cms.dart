import 'package:festenao_common/data/festenao_media_sdb.dart';
import 'package:festenao_common/festenao_cms.dart';
import 'package:tekaly_sdb_synced/synced_sdb_firestore.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';

/// Hosting path of the cms sites: `https://<hosting>/cms/...` is rewritten
/// to the cms function of the hosting flavor ([festenaoCmsFunctionProd] or
/// [festenaoCmsFunctionDev]).
const festenaoCmsHostingPath = 'cms';

/// Cms site function, prod flavor.
const festenaoCmsFunctionProd = 'cms';

/// Cms site function, other flavors.
const festenaoCmsFunctionDev = 'cmsdev';

/// Demo cms site function, the hard coded site of `festenao_demo`, flavor
/// free; also its hosting path (`https://<hosting>/cmsdemo/`).
const festenaoCmsDemoFunction = 'cmsdemo';

/// True when [app] is a dev app, named with a dev flavor suffix
/// (`festenao-dev`, `festenao_dev`, `festenao-devx`).
bool festenaoIsDevApp(String app) => _devAppRegExp.hasMatch(app);

final _devAppRegExp = RegExp(r'[-_]devx?$');

/// Document of a project: `app/<app>/project/<projectId>`.
String festenaoProjectDocumentPath({
  required String app,
  required String projectId,
}) => 'app/$app/project/$projectId';

/// Root document of a synced content database of a project:
/// `app/<app>/project/<projectId>/data/<dataId>`.
String festenaoProjectDataDocumentPath({
  required String app,
  required String projectId,
  required String dataId,
}) =>
    '${festenaoProjectDocumentPath(app: app, projectId: projectId)}/data/$dataId';

/// The content database schema the server opens by default to read the cms
/// pages: the pages, the festenao media stores and the sync meta stores.
///
/// Every store of the synced content must be in the schema (a record of an
/// unknown store fails the synchronization): an app adding its own stores
/// next to the pages gives its own schema
/// (`FestenaoServerApp.cmsContentSdbOptions`).
final festenaoCmsContentSdbOpenOptions = SdbOpenDatabaseOptions(
  version: 1,
  schema: SdbDatabaseSchema(
    stores: [
      cmsPageStoreSchema,
      ...sdbMediaSchemaStores,
      ...syncedSdbMetaSchema.stores,
    ],
  ),
);

/// The project data a cms site shows.
class FestenaoCmsSiteRef {
  /// App id (`festenao`, `festenao-dev`...).
  final String app;

  /// Project id.
  final String projectId;

  /// Data id, a project can hold several synced content databases.
  final String dataId;

  /// A site ref.
  const FestenaoCmsSiteRef({
    required this.app,
    required this.projectId,
    required this.dataId,
  });

  /// The project document.
  String get projectDocumentPath =>
      festenaoProjectDocumentPath(app: app, projectId: projectId);

  /// The root document of the synced content.
  String get rootDocumentPath => festenaoProjectDataDocumentPath(
    app: app,
    projectId: projectId,
    dataId: dataId,
  );

  @override
  int get hashCode => Object.hash(app, projectId, dataId);

  @override
  bool operator ==(Object other) =>
      other is FestenaoCmsSiteRef &&
      other.app == app &&
      other.projectId == projectId &&
      other.dataId == dataId;

  @override
  String toString() => 'FestenaoCmsSiteRef($rootDocumentPath)';
}

/// The synced content database of a project, as the server reads it: an in
/// memory copy pulled from firestore, never written back.
class FestenaoCmsContent {
  /// What it is the content of.
  final FestenaoCmsSiteRef ref;

  final SyncedSdb _syncedSdb;
  final SyncedSdbSynchronizer _synchronizer;

  /// The database.
  final SdbDatabase db;

  /// Its pages.
  final CmsPageSdb pages;

  FestenaoCmsContent._(this.ref, this._syncedSdb, this._synchronizer, this.db)
    : pages = CmsPageSdb(db: db);

  /// Opens the content of [ref], not synced yet.
  static Future<FestenaoCmsContent> open({
    required FestenaoCmsSiteRef ref,
    required Firestore firestore,
    required SdbFactory sdbFactory,
    required SdbOpenDatabaseOptions openOptions,
  }) async {
    initFestenaoCmsBuilders();
    var syncedSdb = SyncedSdb.openDatabase(
      databaseFactory: sdbFactory,
      name: 'cms_${ref.app}_${ref.projectId}_${ref.dataId}.db',
      options: SyncedSdbOptions(openDatabaseOptions: openOptions),
    );
    var db = await syncedSdb.database;
    var synchronizer = SyncedSdbSynchronizer(
      db: syncedSdb,
      // Read only, sync down only.
      readSource: SyncedSourceFirestore(
        firestore: firestore,
        rootPath: ref.rootDocumentPath,
      ),
    );
    return FestenaoCmsContent._(ref, syncedSdb, synchronizer, db);
  }

  /// Pulls the changes (a cheap delta once the first sync is done).
  Future<void> sync() async {
    await _synchronizer.syncDown();
  }

  /// True when the content was ever synced from firestore: false for a
  /// project or a data id that does not exist.
  Future<bool> exists() async =>
      ((await _syncedSdb.getSyncMetaInfoLastChangeId()) ?? 0) > 0;

  /// Close.
  Future<void> close() async {
    await _synchronizer.close();
    await _syncedSdb.close();
  }
}

/// The project contents a server reads, the [maximumSize] most recently
/// used kept open per function instance, re-synced on each access.
class FestenaoCmsContentCache {
  /// Firestore.
  final Firestore firestore;

  /// The sdb factory the contents are opened on (memory by default).
  final SdbFactory sdbFactory;

  /// The content database schema, see [festenaoCmsContentSdbOpenOptions].
  final SdbOpenDatabaseOptions openOptions;

  /// Maximum number of contents kept open.
  final int maximumSize;

  final _lock = Lock();

  /// By access order, the most recent last.
  final _contents = <FestenaoCmsSiteRef, FestenaoCmsContent>{};

  /// A cache.
  FestenaoCmsContentCache({
    required this.firestore,
    SdbFactory? sdbFactory,
    SdbOpenDatabaseOptions? openOptions,
    this.maximumSize = 16,
  }) : sdbFactory = sdbFactory ?? newSdbFactoryMemory(),
       openOptions = openOptions ?? festenaoCmsContentSdbOpenOptions;

  /// The content of [ref], synced with firestore, null when there is none
  /// (not kept open then: unknown ids do not evict the others).
  Future<FestenaoCmsContent?> get(FestenaoCmsSiteRef ref) async {
    return await _lock.synchronized(() async {
      var content =
          _contents.remove(ref) ??
          await FestenaoCmsContent.open(
            ref: ref,
            firestore: firestore,
            sdbFactory: sdbFactory,
            openOptions: openOptions,
          );
      try {
        await content.sync();
        if (!await content.exists()) {
          await content.close();
          return null;
        }
      } catch (_) {
        await content.close();
        rethrow;
      }
      _contents[ref] = content;
      while (_contents.length > maximumSize) {
        await _contents.remove(_contents.keys.first)!.close();
      }
      return content;
    });
  }

  /// Close everything.
  Future<void> close() async {
    await _lock.synchronized(() async {
      var all = _contents.values.toList();
      _contents.clear();
      for (var content in all) {
        await content.close();
      }
    });
  }
}

/// Adds [pages] to the synced content of [ref] in firestore, as an app
/// editing its content database offline then syncing it would (a demo, a
/// test, an import): what the cms function then serves.
///
/// The content is pulled first, the slugs are made unique against it.
Future<void> festenaoCmsAddProjectPages({
  required Firestore firestore,
  required FestenaoCmsSiteRef ref,
  required List<SdbCmsPage> pages,
  SdbOpenDatabaseOptions? openOptions,
}) async {
  initFestenaoCmsBuilders();
  var syncedSdb = SyncedSdb.openDatabase(
    databaseFactory: newSdbFactoryMemory(),
    name: 'cms_add_pages.db',
    options: SyncedSdbOptions(
      openDatabaseOptions: openOptions ?? festenaoCmsContentSdbOpenOptions,
    ),
  );
  var synchronizer = SyncedSdbSynchronizer(
    db: syncedSdb,
    source: SyncedSourceFirestore(
      firestore: firestore,
      rootPath: ref.rootDocumentPath,
    ),
  );
  try {
    await synchronizer.sync();
    var cmsPages = CmsPageSdb(db: await syncedSdb.database);
    for (var page in pages) {
      await cmsPages.addPage(page);
    }
    await synchronizer.sync();
  } finally {
    await synchronizer.close();
    await syncedSdb.close();
  }
}
