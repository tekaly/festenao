import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_sync.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/utils/database_utils.dart';
import 'package:sembast/utils/sembast_import_export.dart';

const _debug = false;
void _log(Object? message) {
  if (_debug) {
    // ignore: avoid_print
    print('/app_sync $message');
  }
}

/// Sync either from an export or from firestore
abstract class FestenaoAppSync {
  FestenaoDb get db;

  /// synchronized (down)
  Future<void> sync();
}

mixin FestenaoAppSyncMixin implements FestenaoAppSync {
  @override
  late FestenaoDb db;
}

typedef FestenaoAppSyncFetchExportMeta =
    Future<Map<String, Object?>> Function();
typedef FestenaoAppSyncFetchExport = Future<String> Function(int changeId);

/// Sync from export
class FestenaoAppSyncExport
    with FestenaoAppSyncMixin
    implements FestenaoAppSync {
  FestenaoAppSyncExport(
    FestenaoDb db, {
    required this.fetchExport,
    required this.fetchExportMeta,
  }) {
    this.db = db;
  }

  /// Only sync if fetch export does not return null
  final FestenaoAppSyncFetchExport fetchExport;

  /// Only sync if fetch export does not return null
  final FestenaoAppSyncFetchExportMeta fetchExportMeta;

  @override
  Future<void> sync() async {
    var meta = await db.getSyncMetaInfo();
    var newMeta = FestenaoExportMeta()..fromMap(await fetchExportMeta());
    var newLastChangeId = newMeta.lastChangeId.v!;
    if ((meta?.sourceVersion.v != newMeta.sourceVersion.v) ||
        (newMeta.lastChangeId.v! > (meta?.lastChangeId.v ?? 0))) {
      if (_debug) {
        _log('importing data $newMeta');
      }

      var data = await fetchExport(newLastChangeId);
      var sourceDb = await importDatabaseAny(
        data,
        newDatabaseFactoryMemory(),
        'export',
      );
      await databaseMerge(await db.database, sourceDatabase: sourceDb);
      await sourceDb.close();
    }
  }
}

/// Sync from firestore
class FestenaoAppSyncFirestore
    with FestenaoAppSyncMixin
    implements FestenaoAppSync {
  FestenaoAppSyncFirestore(FestenaoDb db, this.sourceFirestore) {
    this.db = db;
  }

  final FestenaoSourceFirestore sourceFirestore;

  @override
  Future<void> sync() async {
    var sync = FestenaoDbSourceSync(db: db, source: sourceFirestore);
    var stat = await sync.syncDown();
    if (_debug) {
      _log('importing data $stat');
    }
  }
}
