import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_media.dart';

import 'package:festenao_common/data/festenao_media_source.dart';

import 'festenao_media_sdb.dart';

/// Class to synchronize a local [FestenaoMediaDb] with a [FestenaoMediaSource].
class FestenaoMediaSdbSynchronizer {
  /// The local db
  final FestenaoMediaSdb db;

  /// The source
  final FestenaoMediaSource source;

  /// Constructor for [FestenaoMediaSdbSynchronizer].
  FestenaoMediaSdbSynchronizer({required this.db, required this.source});

  /// Sync up
  Future<SyncedSyncStat> syncUp() async {
    var fileIds = await db.fileIdsToUpload();
    var remoteCreated = 0;
    for (var fileId in fileIds) {
      var fileRecord = await db.getMediaFileRecord(fileId);
      if (fileRecord != null) {
        var bytes = await db.readMediaFileBytes(fileId);
        await source.addMediaFile(file: fileRecord.toMediaFile(), bytes: bytes);
        // Update status
        // ignore: invalid_use_of_protected_member
        await db.markDownloadedAndUploaded(fileId);
        remoteCreated++;
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
    var upStat = await syncUp();
    var downStat = await syncDown();
    return upStat..add(downStat);
  }
}
