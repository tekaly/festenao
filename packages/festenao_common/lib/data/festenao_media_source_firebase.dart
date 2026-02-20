import 'dart:typed_data';

import 'package:festenao_common/data/festenao_media_db.dart';
import 'package:festenao_common/data/festenao_media_source.dart';
import 'package:tkcms_common/tkcms_storage.dart';

import '../festenao_firestore.dart';
import 'festenao_media.dart';

/// Database record class for media files in Festenao
/// The uid is the file uid
class FsFestenaoMediaFile extends CvFirestoreDocumentBase {
  /// Media type (mime type)
  final type = CvField<String>('type');

  /// Original filename of the media file, used to determine the file extension and for reference. This field is not used for storage but can be helpful for management and debugging purposes.
  final originalFilename = CvField<String>('filename');

  /// Path to the media file in the file system, stored as a string. This field is used to locate the media file for retrieval and management.
  final filePath = CvField<String>('path');

  /// Timestamp when the media file was created (local)
  final createdTimestamp = CvField<Timestamp>('createdTimestamp');

  /// File size
  final size = CvField<int>('size');

  /// Server change id
  final syncChangeNum = CvField<int>('syncChangeNum');

  /// Timestamp when the media file was created on the server
  final serverCreatedTimestamp = CvField<Timestamp>('createdTimestamp');

  /// Deleted
  final deleted = CvField<bool>('deleted');

  @override
  CvFields get fields => [
    type,
    originalFilename,
    filePath,
    createdTimestamp,
    size,
    syncChangeNum,
    serverCreatedTimestamp,
  ];
}

/// Firebase implementation of [FestenaoMediaSource].
class FestenaoMediaSourceFirebase implements FestenaoMediaSource {
  /// Storage context
  final FirebaseStorageContext storageContext;

  /// Bucket name
  String? get bucketName => storageContext.bucketName;

  /// Storage
  Storage get storage => storageContext.storage;

  /// Constructor for [FestenaoMediaSourceFirebase].
  FestenaoMediaSourceFirebase({required this.storageContext}) {
    cvAddConstructors([DbFestenaoMediaFile.new]);
  }

  @override
  Future<void> addMediaFile({
    required Uint8List bytes,
    required FestenaoMediaFile file,
  }) async {
    var path = file.path;
    var type = file.type;

    var bucket = storage.bucket(bucketName);
    var gsFile = bucket.file(path);
    await gsFile.upload(
      bytes,
      options: StorageUploadFileOptions(contentType: type),
    );
  }

  @override
  Future<void> deleteMediaFile(FestenaoMediaFileRef ref) async {
    var bucket = storage.bucket(bucketName);
    var file = bucket.file(ref.path);
    try {
      await file.delete();
    } catch (_) {
      // Ignore if file does not exist
    }
  }

  @override
  Future<Uint8List> readMediaFileBytes(FestenaoMediaFileRef ref) async {
    var bucket = storage.bucket(bucketName);
    var file = bucket.file(ref.path);
    return await file.readAsBytes();
  }
}
