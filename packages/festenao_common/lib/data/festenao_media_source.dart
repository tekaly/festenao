import 'dart:typed_data';

import 'festenao_media.dart';

/// Abstract source for media files.
abstract class FestenaoMediaSource {
  /// Adds a media file to the source.
  Future<void> addMediaFile({
    required FestenaoMediaFile file,
    required Uint8List bytes,
  });

  /// Reads the media file bytes for the given [fileId].
  Future<Uint8List> readMediaFileBytes(String fileId);

  /// Deletes the media file for the given [fileId].
  Future<void> deleteMediaFile(String fileId);

  /// Get the media file record.
  Future<FestenaoMediaFile?> getMediaFileRecord(String fileId);

  /// Gets all media file records from the source.
  Future<List<FestenaoMediaFile>> getAllRecords();
}
