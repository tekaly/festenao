import 'package:festenao_common/data/festenao_media_db.dart';
import 'package:festenao_common/data/festenao_media_sdb_synchronizer.dart';
import 'package:festenao_common/data/festenao_media_source_firebase.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:path/path.dart';
import 'package:tekaly_sdb_synced/synced_sdb.dart';
import 'package:tekaly_sdb_synced_media/synced_media.dart'
    show SyncedMediaCacheOptions;
import 'package:tekaly_sembast_synced/synced_db_firestore.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';
import 'package:tkcms_common/tkcms_storage.dart';

import '../festenao_media_source.dart';
import 'festenao/sync/sync_source_options.dart';
import 'festenao_sdb.dart';

/// Festenao syncedDb
class FestenaoSyncedSdb {
  /// Output debug log
  static bool _debugLog = false;

  /// Get output debug log
  static bool get debugLog => _debugLog;

  /// Set debug log
  @doNotSubmit
  static set debugLog(bool value) {
    _debugLog = value;
    FestenaoMediaSdbSynchronizer.debugLog = value;
  }

  late final FestenaoMediaSdbSynchronizer _mediaSynchronizer;
  late final SyncedSdbSynchronizer _syncedDbSynchronizer;

  /// File system (sandbox to location)
  final FestenaoSdb db;

  /// Source options
  final FestenaoSyncSourceOptions sourceOptions;

  /// Firebase storage
  final FirebaseStorage firebaseStorage;

  /// Firebase firestore
  final Firestore firestore;

  /// The media source
  FestenaoMediaSource get mediaSource => _mediaSynchronizer.source;

  /// The media synchronizer (cache aware reads, network urls).
  FestenaoMediaSdbSynchronizer get mediaSynchronizer => _mediaSynchronizer;

  /// Festenao synced db, the media contents kept locally per
  /// [mediaCacheOptions] (all by default).
  FestenaoSyncedSdb({
    required this.db,
    required this.sourceOptions,
    required this.firebaseStorage,
    required this.firestore,
    SyncedMediaCacheOptions mediaCacheOptions =
        const SyncedMediaCacheOptions.all(),
  }) {
    if (_debugLog) {
      log('Creating synced Sdb $sourceOptions');
    }
    var source = SyncedSourceFirestore(
      firestore: firestore,
      rootPath: sourceOptions.firestoreRoot,
    );
    _syncedDbSynchronizer = SyncedSdbSynchronizer(
      db: db.syncedSdb,
      source: source,
      autoSync: true,
    );
    _mediaSynchronizer = FestenaoMediaSdbSynchronizer(
      db: db.mediaDb,
      source: FestenaoMediaSourceFirebase(
        storageContext: FirebaseStorageContext(
          storage: firebaseStorage,
          rootDirectory: url.join(
            sourceOptions.storageRoot,
            FestenaoMediaDb.mediaPart,
          ),
          bucketName: sourceOptions.storageBucket,
        ),
      ),
      cacheOptions: mediaCacheOptions,
    );
    // Synchronize the media now and after each database synchronization
    // (new or deleted media records, local media to upload).
    _mediaSynchronizer.startAutoSync(_syncedDbSynchronizer.onSynced());
  }

  /// Synchronize medias.
  Future<SyncedSyncStat> synchronizeMedias() => _mediaSynchronizer.sync();

  /// Synchronize database.
  Future<SyncedSyncStat> synchronize() {
    return _syncedDbSynchronizer.lazySync();
  }

  /// The synchronization status of the database (not of the medias).
  SyncedDbSyncStatus get syncStatus => _syncedDbSynchronizer.syncStatus;

  /// The synchronization status of the database as it changes, starting
  /// with the current one.
  Stream<SyncedDbSyncStatus> onSyncStatus() =>
      _syncedDbSynchronizer.onSyncStatus();

  /// Log message
  static void log(Object? message) {
    // ignore: avoid_print
    print('[FestenaoSyncedSdb] $message');
  }

  /// Clean up
  void dispose() {
    unawaited(_mediaSynchronizer.close());
    _syncedDbSynchronizer.close();
  }
}
