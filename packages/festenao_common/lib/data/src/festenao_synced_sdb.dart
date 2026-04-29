import 'package:festenao_common/data/festenao_media_db.dart';
import 'package:festenao_common/data/festenao_media_sdb_synchronizer.dart';
import 'package:festenao_common/data/festenao_media_source_firebase.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:path/path.dart';
import 'package:tekaly_sdb_synced/synced_sdb.dart';
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

  StreamSubscription? _syncStatSubscription;
  late final FestenaoMediaSdbSynchronizer _mediaSynchronizer;
  late final SyncedSdbSynchronizer _syncedDbSynchronizer;

  final _syncMediaLock = Lock();

  /// File system (sandbox to location)
  final FestenaoSdb db;

  /// Source options
  final FestenaoSyncSourceOptions sourceOptions;

  /// Firebase storage
  final FirebaseStorage firebaseStorage;

  /// Firebase firestore
  final Firestore firestore;

  var _disposed = false;

  /// The media source
  FestenaoMediaSource get mediaSource => _mediaSynchronizer.source;

  /// Festenao synced db
  FestenaoSyncedSdb({
    required this.db,
    required this.sourceOptions,
    required this.firebaseStorage,
    required this.firestore,
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
    );
    _syncStatSubscription = _syncedDbSynchronizer.onSynced().listen((syncStat) {
      // On post sync with changes, trigger media sync
      if (_debugLog) {
        log('Synced done');
      }
      unawaited(synchronizeMedias());
    });
    db.syncedSdb.initialSynchronizationDone().then((_) {
      if (_debugLog) {
        log('initial synchronization done');
      }
      unawaited(synchronizeMedias());
    });

    // Synchronize the media on start, should not try to access the network if not
    // needed
    synchronizeMedias();
  }

  /// Synchronize medias.
  Future<SyncedSyncStat> synchronizeMedias() {
    return _syncMediaLock.synchronized(() {
      return _synchronizeMedias();
    });
  }

  /// Synchronize database.
  Future<SyncedSyncStat> synchronize() {
    return _syncedDbSynchronizer.lazySync();
  }

  /// Log message
  static void log(Object? message) {
    // ignore: avoid_print
    print('[FestenaoSyncedSdb] $message');
  }

  /// Synchronize medias.
  Future<SyncedSyncStat> _synchronizeMedias() async {
    if (_disposed) return SyncedSyncStat();
    try {
      if (debugLog) {
        log('Starting media sync');
      }
      // print('started syncMedia');
      var syncResult = await _mediaSynchronizer.sync();
      if (debugLog) {
        log('media sync: $syncResult');
      }
      return syncResult;
    } catch (e) {
      log('sync medias failed $e');
      rethrow;
    }
  }

  /// Clean up
  void dispose() {
    _disposed = true;
    _syncStatSubscription?.cancel();
    _syncedDbSynchronizer.close();
  }
}
