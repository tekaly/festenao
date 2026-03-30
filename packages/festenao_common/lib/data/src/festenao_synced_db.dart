import 'dart:async';

import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_media_db.dart';
import 'package:festenao_common/data/festenao_media_db_synchronizer.dart';
import 'package:festenao_common/data/festenao_media_source_firebase.dart';
import 'package:fs_shim/fs.dart';
import 'package:path/path.dart';
import 'package:tkcms_common/tkcms_content.dart';
import 'package:tkcms_common/tkcms_storage.dart';

import 'festenao/sync/sync_source_options.dart';

/// Festenao syncedDb
class FestenaoSyncedDb {
  StreamSubscription? _syncStatSubscription;
  late final FestenaoMediaDbSynchronizer _mediaSynchronizer;

  /// File system (sandbox to location)
  final FileSystem fs;

  /// Media db access
  late final FestenaoMediaDb mediaDb;

  /// Source options
  final FestenaoSyncSourceOptions sourceOptions;

  /// Local db options
  final FestenaoDbOptions options;

  /// New only
  final ContentDb? contentDb;

  /// New only
  final FirebaseStorage? firebaseStorage;

  /// Actual synced db
  final SyncedDb syncedDb;

  /// Festenao synced db
  FestenaoSyncedDb({
    required this.fs,
    required this.sourceOptions,
    required this.options,
    required this.syncedDb,

    /// New only
    this.contentDb,

    /// New only
    this.firebaseStorage,
  }) {
    mediaDb = FestenaoMediaDb(fs: fs, futureDatabase: syncedDb.database);
    if (contentDb != null) {
      _mediaSynchronizer = FestenaoMediaDbSynchronizer(
        db: mediaDb,
        source: FestenaoMediaSourceFirebase(
          storageContext: FirebaseStorageContext(
            storage: firebaseStorage!,
            rootDirectory: url.join(
              sourceOptions.storageRoot,
              FestenaoMediaDb.mediaPart,
            ),
            bucketName: sourceOptions.storageBucket,
          ),
        ),
      );
      _syncStatSubscription = contentDb!.autoSynchronizeDb.synchronizer
          .onSynced()
          .listen((syncStat) {
            // On post sync with changes, trigger media sync
            // if (!(syncStat == SyncedSyncStat())) {
            _mediaSynchronizer.sync();
            //}
          });
    }
  }

  /// Ready to use
  Future<void> get ready async {
    await syncedDb.ready;
    await mediaDb.ready;
  }

  /// Clean up
  void dispose() {
    _syncStatSubscription?.cancel();
  }
}
