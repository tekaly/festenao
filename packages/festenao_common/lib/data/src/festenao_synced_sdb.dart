import 'package:festenao_common/data/festenao_media_db.dart';
import 'package:festenao_common/data/festenao_media_sdb_synchronizer.dart';
import 'package:festenao_common/data/festenao_media_source_firebase.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:path/path.dart';
import 'package:tekaly_sdb_synced/synced_sdb.dart';
import 'package:tekaly_sembast_synced/synced_db_firestore.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';
import 'package:tkcms_common/tkcms_storage.dart';

import 'festenao/sync/sync_source_options.dart';
import 'festenao_sdb.dart';

/// Festenao syncedDb
class FestenaoSyncedSdb {
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

  /// Festenao synced db
  FestenaoSyncedSdb({
    required this.db,
    required this.sourceOptions,
    required this.firebaseStorage,
    required this.firestore,
  }) {
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
      unawaited(synchronizeMedias());
    });
    db.syncedSdb.initialSynchronizationDone().then((_) {
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

  /// Synchronize medias.
  Future<SyncedSyncStat> _synchronizeMedias() async {
    if (_disposed) return SyncedSyncStat();
    try {
      // print('started syncMedia');
      var syncResult = await _mediaSynchronizer.sync();
      // print('syncMedia: $syncResult');
      return syncResult;
    } catch (e) {
      //print('syncMedia failed $e');
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
