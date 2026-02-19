import 'package:festenao_common/data/festenao_media.dart';
import 'package:festenao_common/data/festenao_media_db.dart';
import 'package:festenao_common/data/festenao_media_source.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';

/// Class to synchronize a local [FestenaoMediaDb] with a [FestenaoMediaSource].
class FestenaoMediaDbSynchronizer {
  /// The local db
  final FestenaoMediaDb db;

  /// The source
  final FestenaoMediaSource source;

  /// Constructor for [FestenaoMediaDbSynchronizer].
  FestenaoMediaDbSynchronizer({required this.db, required this.source});

  /// Synchronizes the local database with the source.
  Future<void> sync() async {
    var sourceRecords = await source.getAllRecords();
    var localRecords = await db.getAllRecords();

    var sourceIds = sourceRecords.map((e) => e.uid.v).toSet();
    var localIds = localRecords.map((e) => e.ref.key).toSet();

    // Download new files
    for (var record in sourceRecords) {
      var key = record.uid.v;
      if (key != null) {
        if (!localIds.contains(key)) {
          var bytes = await source.readMediaFileBytes(key);
          await db.addMediaFile(
            bytes: bytes,
            file: FestenaoMediaFile.from(
              filename: record.originalFilename.v!,
              type: record.type.v,
            ),
          );
        }
      }
    }

    // Delete old files
    for (var record in localRecords) {
      var key = record.ref.key;
      if (!sourceIds.contains(key)) {
        await db.deleteMediaFile(key);
      }
    }
  }
}
