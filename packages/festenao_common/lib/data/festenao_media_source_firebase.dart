import 'dart:typed_data';

import 'package:festenao_common/data/festenao_media_db.dart';
import 'package:festenao_common/data/festenao_media_source.dart';
import 'package:festenao_common/festenao_sembast.dart';
import 'package:tkcms_common/tkcms_storage.dart';

import '../festenao_firestore.dart';
import 'festenao_media.dart';

/// Collection reference for media files.
final _mediaCollection = CvCollectionReference<FsFestenaoMediaFile>('media');

/// Database record class for media files in Festenao
/// The uid is the file uid
class FsFestenaoMediaFile extends CvFirestoreDocumentBase {
  /// Media type (mime type)
  final type = CvField<String>('type');

  /// Original filename of the media file, used to determine the file extension and for reference. This field is not used for storage but can be helpful for management and debugging purposes.
  final originalFilename = CvField<String>('filename');

  /// Path to the media file in the file system, stored as a string. This field is used to locate the media file for retrieval and management.
  final filePath = CvField<String>('path');

  /// Timestamp when the media file was created.
  final createdTimestamp = CvField<Timestamp>('createdTimestamp');

  /// File size
  final size = CvField<int>('size');
  @override
  CvFields get fields => [
    type,
    originalFilename,
    filePath,
    createdTimestamp,
    size,
  ];
}

/// Firebase implementation of [FestenaoMediaSource].
class FestenaoMediaSourceFirebase implements FestenaoMediaSource {
  /// Firestore context
  final FirestoreDatabaseContext firestoreContext;

  /// Storage context
  final FirebaseStorageContext storageContext;

  /// Firestore
  Firestore get firestore => firestoreContext.firestore;

  /// Bucket name
  String? get bucketName => storageContext.bucketName;

  /// Storage
  Storage get storage => storageContext.storage;

  /// Constructor for [FestenaoMediaSourceFirebase].
  FestenaoMediaSourceFirebase({
    required this.firestoreContext,
    required this.storageContext,
  }) {
    cvAddConstructors([DbFestenaoMediaFile.new]);
  }

  @override
  Future<void> addMediaFile({
    required Uint8List bytes,
    required FestenaoMediaFile file,
  }) async {
    var uid = file.uid.v;
    if (uid == null) {
      throw ArgumentError.value(
        uid,
        'file.uid',
        'UID must be provided for media file',
      );
    }
    var path = file.path.v;
    if (path == null) {
      throw ArgumentError.value(
        path,
        'file.path',
        'File path must be provided for media file',
      );
    }
    var type = file.type.v;


    var bucket = storage.bucket(bucketName);
    var gsFile = bucket.file(path);
    await gsFile.upload(
      bytes,
      options: StorageUploadFileOptions(contentType: type),
    );
    /// Set to fs once uploaded
    var fsDoc = file.toFsMediaFile();
    await fsDoc.ref.set(firestore, fsDoc);

  }

  @override
  Future<void> deleteMediaFile(String fileId) async {
    var record = await getMediaFileRecord(fileId);
    if (record?.path.v != null) {
      var bucket = storage.bucket(bucketName);
      var file = bucket.file(record!.path.v!);
      try {
        await file.delete();
      } catch (_) {
        // Ignore if file does not exist
      }
    }
    await _mediaCollection.doc(fileId).delete(firestore);
  }

  @override
  Future<FestenaoMediaFile?> getMediaFileRecord(String fileId) async {
    var fsDoc = await _mediaCollection.doc(fileId).get(firestore);
    return fsDoc.toMediaFileOrNull();
  }

  @override
  Future<Uint8List> readMediaFileBytes(String fileId) async {
    var record = await getMediaFileRecord(fileId);
    if (record?.path.v != null) {
      var bucket = storage.bucket(bucketName);
      var file = bucket.file(record!.path.v!);
      return await file.readAsBytes();
    }
    throw FestenaoMediaDbException('Media file not found: $fileId');
  }

  @override
  Future<List<FestenaoMediaFile>> getAllRecords() async {
    var fsDocs = await _mediaCollection.get(firestore);
    return fsDocs.map((doc) => doc.toMediaFile()).toList();
  }
}

Timestamp _fromDbTimestamp(DbTimestamp timestamp) {
  return Timestamp(timestamp.seconds, timestamp.nanoseconds);
}

DbTimestamp _toDbTimestamp(Timestamp timestamp) {
  return DbTimestamp(timestamp.seconds, timestamp.nanoseconds);
}

Timestamp? _fromDbTimestampOrNull(DbTimestamp? timestamp) {
  if (timestamp == null) {
    return null;
  }
  return _fromDbTimestamp(timestamp);
}

DbTimestamp? _toDbTimestampOrNull(Timestamp? timestamp) {
  if (timestamp == null) {
    return null;
  }
  return _toDbTimestamp(timestamp);
}

extension _FsFestenaoMediaFileExt on FsFestenaoMediaFile {
  FestenaoMediaFile toMediaFile() {
    var doc = FestenaoMediaFile()
      ..path.fromCvField(filePath)
      ..size.fromCvField(size)
      ..type.fromCvField(type)
      ..createdTimestamp.setValue(_toDbTimestampOrNull(createdTimestamp.v))
      ..originalFilename.fromCvField(originalFilename)
      ..uid.v = id;
    return doc;
  }

  FestenaoMediaFile? toMediaFileOrNull() {
    if (exists) {
      return toMediaFile();
    }
    return null;
  }
}

extension _FestenaoMediaFileExt on FestenaoMediaFile {
  FsFestenaoMediaFile toFsMediaFile() {
    var uid = this.uid.v!;

    var fsDoc = _mediaCollection.doc(uid).cv()
      ..filePath.fromCvField(path)
      ..size.fromCvField(size)
      ..type.fromCvField(type)
      ..createdTimestamp.setValue(_fromDbTimestampOrNull(createdTimestamp.v))
      ..originalFilename.fromCvField(originalFilename);
    return fsDoc;
  }
}
