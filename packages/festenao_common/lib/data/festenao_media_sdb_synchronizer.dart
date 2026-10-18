import 'package:festenao_common/data/src/import.dart';
import 'package:tekaly_sdb_synced/synced_sdb.dart' show SyncedSyncStat;
import 'package:tekaly_sdb_synced_media/synced_media.dart'
    show SyncedMediaCacheOptions, SyncedMediaSdbSynchronizer, debugSyncedMedia;

import 'festenao_media_sdb.dart';

/// Class to synchronize a local [FestenaoMediaSdb] with a `FestenaoMediaSource`
/// (see `SyncedMediaSdbSynchronizer`).
class FestenaoMediaSdbSynchronizer extends SyncedMediaSdbSynchronizer {
  /// Get debug log
  static bool get debugLog => debugSyncedMedia;

  /// Set debug log
  @doNotSubmit
  static set debugLog(bool value) {
    debugSyncedMedia = value;
  }

  /// The local db
  @override
  FestenaoMediaSdb get db => super.db as FestenaoMediaSdb;

  /// Constructor for [FestenaoMediaSdbSynchronizer], keeping every content
  /// locally unless [cacheOptions] says otherwise.
  FestenaoMediaSdbSynchronizer({
    required FestenaoMediaSdb super.db,
    required super.source,
    super.cacheOptions = const SyncedMediaCacheOptions.all(),
    super.storeUrl,
  });

  /// Compare existing keys and fix inconsistencies
  Future<void> compareExistingKeys() => reconcile();

  /// Sync dirty records
  Future<SyncedSyncStat> syncDirty() => reconcile();
}
