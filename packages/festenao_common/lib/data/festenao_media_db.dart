import 'dart:typed_data';

import 'package:festenao_common/data/festenao_media.dart';
import 'package:fs_shim/fs_shim.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';

/// Exception class for errors related to the FestenaoMediaDb.
class FestenaoMediaDbException implements Exception {
  /// Error message describing the exception.
  final String message;

  /// Constructor for creating a FestenaoMediaDbException with a specific message.
  FestenaoMediaDbException(this.message);

  @override
  String toString() => 'FestenaoMediaDbException: $message';
}

/// Database record class for media files in Festenao, using SDB for metadata storage.
class DbFestenaoMediaFile extends ScvStringRecordBase {
  /// Media type (mime type)
  final type = CvField<String>('type');

  /// File size
  final size = CvField<int>('size');

  /// Original filename of the media file, used to determine the file extension and for reference. This field is not used for storage but can be helpful for management and debugging purposes.
  final originalFilename = CvField<String>('filename');

  /// Path to the media file in the file system, stored as a string. This field is used to locate the media file for retrieval and management.
  final path = CvField<String>('path');

  /// Timestamp when the media file was created.
  final createdTimestamp = cvEncodedTimestampField('createdTimestamp');

  @override
  CvFields get fields => [type, size, originalFilename, path, createdTimestamp];
}

final _dbFestenaoMediaFileStore = ScvStoreRef<String, DbFestenaoMediaFile>(
  'file',
);
final _schema = SdbDatabaseSchema(stores: [_dbFestenaoMediaFileStore.schema()]);
final _options = SdbOpenDatabaseOptions(version: 1, schema: _schema);

/// Media database for Festenao, using SDB for metadata and the file system for media storage.
class FestenaoMediaDb {
  /// Factory for creating SDB instances, injected for flexibility and testing.
  final SdbFactory sdbFactory;

  /// File system for storing media files, injected for flexibility and testing.
  final FileSystem fs;

  /// Constructor for FestenaoMediaDb, requiring an SDB factory and a file system.
  FestenaoMediaDb({required this.sdbFactory, required this.fs}) {
    cvAddConstructors([DbFestenaoMediaFile.new]);
  }

  String get _rootPath {
    if (fs is FsShimSandboxedFileSystem) {
      return (fs as FsShimSandboxedFileSystem).rootDirectory.path;
    } else {
      return fs.currentDirectory.path;
    }
  }

  late final _db = sdbFactory.openDatabase(
    fs.path.join(_rootPath, 'festenao_media.db'),
    options: _options,
  );

  /// Adds a media file to the database and storage.
  /// [bytes] is the content of the media file.
  /// [filename] is the original filename, used to determine the file extension.
  Future<String> addMediaFile({
    required FestenaoMediaFile file,
    required Uint8List bytes,
  }) async {
    var db = await _db;
    var uid = file.uid.v!;
    var path = file.path.v!;
    await db.inStoreTransaction(
      _dbFestenaoMediaFileStore.rawRef,
      SdbTransactionMode.readWrite,
      (txn) async {
        var mediaRecord = _dbFestenaoMediaFileStore.record(uid).cv()
          ..createdTimestamp.value = ScvTimestamp.now()
          ..size.setValue(file.size.v)
          ..originalFilename.setValue(file.originalFilename.v)
          ..path.value = path;

        await mediaRecord.put(txn);
      },
    );

    var fsFile = fs.file(path);
    await fsFile.parent.create(recursive: true);
    await fsFile.writeAsBytes(bytes);

    return uid;
  }

  /// Reads the media file bytes for the given [fileId].
  Future<File> getMediaFile(String fileId) async {
    var db = await _db;
    var fileRecord = await _dbFestenaoMediaFileStore.record(fileId).get(db);

    var path = _ensurePath(fileId, fileRecord);
    return fs.file(path);
  }

  /// Reads the media file bytes for the given [fileId].
  Future<Uint8List> readMediaFileBytes(String fileId) async {
    return (await getMediaFile(fileId)).readAsBytes();
  }

  String _ensurePath(String fileId, DbFestenaoMediaFile? fileRecord) {
    if (fileRecord == null) {
      throw FestenaoMediaDbException(
        'Media file record not found for ID: $fileId',
      );
    }
    if (fileRecord.path.v == null) {
      throw FestenaoMediaDbException(
        'Media file path is missing for ID: $fileId',
      );
    }
    return fs.path.normalize(fileRecord.path.v!);
  }

  /// Deletes the media file and its corresponding database record for the given [fileId].
  Future<void> deleteMediaFile(String fileId) async {
    var db = await _db;
    DbFestenaoMediaFile? fileRecord;
    await db.inStoreTransaction(
      _dbFestenaoMediaFileStore.rawRef,
      SdbTransactionMode.readWrite,
      (txn) async {
        fileRecord = await _dbFestenaoMediaFileStore.record(fileId).get(txn);
        if (fileRecord != null) {
          await _dbFestenaoMediaFileStore.record(fileId).delete(txn);
        }
      },
    );

    var path = _ensurePath(fileId, fileRecord);

    final storageFile = fs.file(path);

    if (await storageFile.exists()) {
      await storageFile.delete();
    }
  }

  /// Gets all media file records from the database.
  Future<List<DbFestenaoMediaFile>> getAllRecords() async {
    var db = await _db;
    var records = await _dbFestenaoMediaFileStore.findRecords(db);
    return records;
  }

  /// Get media file record
  Future<DbFestenaoMediaFile?> getMediaFileRecord(String fileId) async {
    var db = await _db;
    var record = await _dbFestenaoMediaFileStore.record(fileId).get(db);
    return record;
  }
}
