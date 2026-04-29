import 'package:collection/collection.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_media.dart';

import 'package:festenao_common/data/festenao_media_source.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:fs_shim/fs.dart';

import 'festenao_media_sdb.dart';

/// Class to synchronize a local [FestenaoMediaDb] with a [FestenaoMediaSource].
class FestenaoMediaSdbSynchronizer {
  static bool _debugLog = false;

  /// Get debug log
  static bool get debugLog => _debugLog;

  /// Set debug log
  @doNotSubmit
  static set debugLog(bool value) {
    _debugLog = value;
  }

  /// The local db
  final FestenaoMediaSdb db;

  /// The source
  final FestenaoMediaSource source;

  /// Constructor for [FestenaoMediaSdbSynchronizer].
  FestenaoMediaSdbSynchronizer({required this.db, required this.source});

  /// Log message
  void log(Object? messsage) {
    // ignore: avoid_print
    print('[FestenaoMediaSdbSynchronizer] $messsage');
  }

  /// Compare existing keys and fix inconsistencies
  Future<void> compareExistingKeys() async {
    late List<String> fileIds;
    late List<String> fileStatusIds;
    await db.database.inScvStoresTransaction(
      [sdbMediaStore, sdbMediaStatusLocalStore],
      SdbTransactionMode.readOnly,
      (txn) async {
        fileIds = await db.findFileRecordKeys(client: txn);
        fileStatusIds = await db.findFileStatusRecordKeys(client: txn);
      },
    );

    if (!const DeepCollectionEquality.unordered().equals(
      fileIds,
      fileStatusIds,
    )) {
      var fileSet = Set.of(fileIds);
      var fileStatusSet = Set.of(fileStatusIds);

      // Status missing for these files
      for (var fileId in fileSet) {
        if (!fileStatusSet.contains(fileId)) {
          if (debugLog) {
            log('Fixing missing status for $fileId');
          }
          await db.markStatusCleared(fileId);
        }
      }

      // Orphans in status store
      for (var fileId in fileStatusSet) {
        if (!fileSet.contains(fileId)) {
          if (debugLog) {
            log('Removing orphan status for $fileId');
          }
          // ignore: invalid_use_of_visible_for_testing_member
          await db.deleteStatusRecord(fileId);
        }
      }
    }
  }

  /// Sync dirty records
  Future<SyncedSyncStat> syncDirty() async {
    await compareExistingKeys();

    var toFixFileIds = await db.fileIdsDirty();
    for (var fileId in toFixFileIds) {
      if (debugLog) {
        log('Fix $fileId');
      }
      var fileRecord = await db.getMediaFileRecord(fileId);

      if (debugLog) {
        log('fileRecord $fileRecord');
      }
      if (fileRecord != null) {
        if (!fileRecord.isDeleted) {
          if (fileRecord.isUploaded) {
            // mark as to download
            await db.updateStatus(fileId, local: false, remote: true);
            if (debugLog) {
              log('Mark as not present to force download');
            }
          }
        }
        /*
        var path = fileRecord.path.v!;
        var deleted = fileRecord.isDeleted;
        if (fileRecord.uploaded.v == true) {}
        // If the file is marked as uploaded but does not exist in the source, mark it as to upload
        var ref = FestenaoMediaFileRef.fromPath(path);
        if (await source.exists(ref)) {
          // ignore: invalid_use_of_protected_member
          await db.markDownloadedAndUploaded(fileId);
        } else {
          // ignore: invalid_use_of_protected_member
          await db.markToUpload(fileId);
        }*/
      }
    }
    return SyncedSyncStat();
  }

  /// Sync up
  Future<SyncedSyncStat> syncUp() async {
    var fileIds = await db.fileIdsToUpload();
    var remoteCreated = 0;
    for (var fileId in fileIds) {
      var fileRecord = await db.getMediaFileRecord(fileId);
      if (fileRecord != null) {
        try {
          var bytes = await db.readMediaFileBytes(fileId);
          await source.addMediaFile(
            file: fileRecord.toMediaFile(),
            bytes: bytes,
          );
          // Update status
          // ignore: invalid_use_of_protected_member
          await db.markDownloadedAndUploaded(fileId);
          remoteCreated++;
        } on FileSystemException catch (e, st) {
          log('ignoring error $e');
          if (debugLog) {
            log(st);
          }
          // Not found locally, re-download
          if (fileRecord.isUploaded && !fileRecord.isDeleted) {
            // Mark as to be downloaded
            await db.updateStatus(fileId, local: false, remote: true);
          }
        }
      }
    }
    var remoteDeleted = 0;
    fileIds = await db.fileIdsToDeleteRemotely();
    for (var fileId in fileIds) {
      var fileRecord = await db.getMediaFileRecord(fileId);
      if (fileRecord != null) {
        var path = fileRecord.path.v!;
        var ref = FestenaoMediaFileRef.fromPath(path);
        await source.deleteMediaFile(ref);
        // Delete and purge
        await db.deleteMediaFile(fileId, purge: true);
        remoteDeleted++;
      }
    }
    return SyncedSyncStat(
      remoteCreatedCount: remoteCreated,
      remoteDeletedCount: remoteDeleted,
    );
  }

  /// Synchronizes the local database with the source.
  Future<SyncedSyncStat> syncDown() async {
    var fileIds = await db.fileIdsToDownload();
    var localCreated = 0;
    for (var fileId in fileIds) {
      var fileRecord = await db.getMediaFileRecord(fileId);
      if (fileRecord != null) {
        var path = fileRecord.path.v!;
        var ref = FestenaoMediaFileRef.fromPath(path);
        var bytes = await source.readMediaFileBytes(ref);
        await db.writeMediaFileBytes(ref, bytes);
        // Update status
        // ignore: invalid_use_of_protected_member
        await db.markDownloadedAndUploaded(fileId);
        localCreated++;
      }
    }
    fileIds = await db.fileIdsToDeleteLocally();
    var localDeleted = 0;
    for (var fileId in fileIds) {
      var fileRecord = await db.getMediaFileRecord(fileId);
      if (fileRecord != null) {
        // Delete and purge
        await db.deleteMediaFile(fileId, purge: true);

        localDeleted++;
      }
    }
    return SyncedSyncStat(
      localCreatedCount: localCreated,
      localDeletedCount: localDeleted,
    );
  }

  /// Sync media content
  Future<SyncedSyncStat> sync() async {
    return await _lock.synchronized(() async {
      var dirtyStat = await syncDirty();
      var upStat = await syncUp();
      var downStat = await syncDown();
      return upStat
        ..add(downStat)
        ..add(dirtyStat);
    });
  }

  final _lock = Lock(reentrant: true);
}
