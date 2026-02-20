import 'package:festenao_common/data/festenao_media.dart';
import 'package:festenao_common/data/festenao_media_db.dart';
import 'package:festenao_common/data/festenao_media_source.dart';

/// Class to synchronize a local [FestenaoMediaDb] with a [FestenaoMediaSource].
class FestenaoMediaDbSynchronizer {
  /// The local db
  final FestenaoMediaDb db;

  /// The source
  final FestenaoMediaSource source;

  /// Constructor for [FestenaoMediaDbSynchronizer].
  FestenaoMediaDbSynchronizer({required this.db, required this.source});

  /// Sync up
  Future<void> syncUp() async {
    var fileIds = await db.fileIdsToUpload();
    for (var fileId in fileIds) {
      var fileRecord = await db.getMediaFileRecord(fileId);
      if (fileRecord != null) {
        var bytes = await db.readMediaFileBytes(fileId);
        await source.addMediaFile(file: fileRecord.toMediaFile(), bytes: bytes);
        // Update status
        await db.markLocalAndRemote(fileId);
      }
    }
  }

  /// Synchronizes the local database with the source.
  Future<void> syncDown() async {
    var fileIds = await db.fileIdsToDownload();
    for (var fileId in fileIds) {
      var fileRecord = await db.getMediaFileRecord(fileId);
      if (fileRecord != null) {
        var path = fileRecord.path.v!;
        var ref = FestenaoMediaFileRef.fromPath(path);
        var bytes = await source.readMediaFileBytes(ref);
        await db.writeMediaFileBytes(ref, bytes);
        // Update status
        await db.markLocalAndRemote(fileId);
      }
    }
    fileIds = await db.fileIdsToDelete();
    for (var fileId in fileIds) {
      var fileRecord = await db.getMediaFileRecord(fileId);
      if (fileRecord != null) {
        var path = fileRecord.path.v!;
        var ref = FestenaoMediaFileRef.fromPath(path);

        await db.deleteMediaFileBytes(ref);
        // Update status
        await db.markLocalDeleted(fileId);
      }
    }
  }
}
