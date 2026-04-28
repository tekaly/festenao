import 'dart:typed_data';

import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_media.dart';
import 'package:festenao_common/festenao_sembast.dart';
import 'package:fs_shim/fs_shim.dart';

/// Exception class for errors related to the FestenaoMediaDb.
class FestenaoMediaDbException implements Exception {
  /// Error message describing the exception.
  final String message;

  /// Constructor for creating a FestenaoMediaDbException with a specific message.
  FestenaoMediaDbException(this.message);

  @override
  String toString() => 'FestenaoMediaDbException: $message';
}

/// Not synced
class DbFestenaoMediaStatusFile extends DbStringRecordBase {
  /// Uploaded
  final remote = CvField<bool>('remote');

  /// Downloaded
  final local = CvField<bool>('local');

  /// Deleted local
  final deletedLocal = CvField<bool>('deletedLocal');
  @override
  CvFields get fields => [remote, local, deletedLocal];
}

/// model
final dbFestenaoMediaStatusFileModel = DbFestenaoMediaStatusFile();

/// Database record class for media files in Festenao, using SDB for metadata storage.
class DbFestenaoMediaFile extends DbStringRecordBase {
  /// Media type (mime type)
  final type = CvField<String>('type');

  /// File size
  final size = CvField<int>('size');

  /// Original filename of the media file, used to determine the file extension and for reference. This field is not used for storage but can be helpful for management and debugging purposes.
  final originalFilename = CvField<String>('filename');

  /// Path to the media file in the file system, stored as a string. This field is used to locate the media file for retrieval and management.
  final path = CvField<String>('path');

  /// Timestamp when the media file was created (local only)
  final createdTimestamp = CvField<DbTimestamp>('createdTimestamp');

  /// Set by uploader (if local is true and remote is false) then updated to true
  /// Also set for media to delete
  final uploaded = CvField<bool>('uploaded');

  /// Mark as deleted, need to need manually purged
  final deleted = CvField<bool>('deleted');

  @override
  CvFields get fields => [
    type,
    size,
    originalFilename,
    path,
    createdTimestamp,
    uploaded,
  ];

  /// To media file
  FestenaoMediaFile toMediaFile() {
    var doc = FestenaoMediaFile(
      originalFilename: originalFilename.v!,
      path: path.v!,
      uid: id,
      type: type.v ?? filenameMimeType(originalFilename.v!),
      size: size.v,
    );
    return doc;
  }
}

/// model
final dbFestenaoMediaFileModel = DbFestenaoMediaFile();

/// Media database for Festenao, using SDB for metadata and the file system for media storage.
class FestenaoMediaDb {
  /// Media part
  static String mediaPart = 'media';

  /// Google storage path
  static List<String> projectStorageParts(String projectId) => [
    'project',
    projectId,
  ];

  /// Opened database, valid when ready
  late final Database database;

  /// File system
  final FileSystem fs;

  final Future<Database> _futureDatabase;

  /// Ready to use!
  Future<void> get ready => _futureDatabase;

  /// Constructor for FestenaoMediaDb, requiring an SDB factory and a file system.
  FestenaoMediaDb({
    required this.fs,
    Database? database,
    Future<Database>? futureDatabase,
  }) : _futureDatabase = futureDatabase ?? Future.value(database) {
    cvAddConstructors([DbFestenaoMediaFile.new, DbFestenaoMediaStatusFile.new]);
    () async {
      database = (await _futureDatabase);
    }();
  }

  Future<void> _writeMediaFileBytes(String path, Uint8List bytes) async {
    var fsFile = fs.file(path);
    await fsFile.parent.create(recursive: true);
    await fsFile.writeAsBytes(bytes);
  }

  /// Adds a media file to the database and storage.
  /// [bytes] is the content of the media file.
  /// [filename] is the original filename, used to determine the file extension.
  Future<String> addMediaFile({
    required FestenaoMediaFile file,
    required Uint8List bytes,
  }) async {
    var db = await _futureDatabase;
    var uid = file.uid;
    var path = file.path;
    var size = file.size ?? bytes.length;

    // First write the file
    await _writeMediaFileBytes(path, bytes);

    // Then add to db, we know it exists, locally only
    await db.transaction((txn) async {
      var mediaRecord = dbMediaStoreRef.record(uid).cv()
        ..createdTimestamp.value = DbTimestamp.now()
        ..type.setValue(file.type)
        ..size.setValue(size)
        ..originalFilename.setValue(file.originalFilename)
        ..path.value = path;
      await mediaRecord.put(txn);
      var statusRecord = dbMediaLocalStoreRef.record(uid).cv()
        ..local.v = true
        ..remote.v = false;
      await statusRecord.put(txn);
    });

    return uid;
  }

  /// Reads the media file bytes for the given [fileId].
  Future<File> getMediaFile(String fileId) async {
    var db = await _futureDatabase;
    var fileRecord = await dbMediaStoreRef.record(fileId).get(db);

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
    var db = await _futureDatabase;
    DbFestenaoMediaFile? fileRecord;
    // Delete in db first
    await db.transaction((txn) async {
      var file = await dbMediaStoreRef.record(fileId).get(txn);
      if (file != null) {
        file
          ..deleted.v = true
          ..uploaded.v = false;
        var status = dbMediaLocalStoreRef.record(fileId).cv();
        status
          ..local.v = true
          ..remote.v = false;

        await file.put(txn);
        await status.put(txn);
        await dbMediaLocalStoreRef.record(fileId).delete(txn);
        await dbMediaStoreRef.record(fileId).delete(txn);
        fileRecord = file;
      }
    });

    if (fileRecord == null) {
      return;
    }
    var path = _ensurePath(fileId, fileRecord);

    final storageFile = fs.file(path);

    if (await storageFile.exists()) {
      await storageFile.delete();
    }
  }

  /// Gets all media file records from the database.
  Future<List<DbFestenaoMediaFile>> getAllRecords() async {
    var db = await _futureDatabase;
    var records = await dbMediaStoreRef.query().getRecords(db);
    return records;
  }

  /// File ids to upload (delete and create)
  Future<List<String>> fileIdsToUpload() async {
    var db = await _futureDatabase;
    return await dbMediaLocalStoreRef
        .query(
          finder: Finder(
            filter: Filter.and([
              Filter.equals(dbFestenaoMediaStatusFileModel.remote.name, false),
              Filter.equals(dbFestenaoMediaStatusFileModel.local.name, true),
            ]),
          ),
        )
        .getKeys(db);
  }

  /// File to download
  Future<List<String>> fileIdsToDownload() async {
    var db = await _futureDatabase;
    return await dbMediaLocalStoreRef
        .query(
          finder: Finder(
            filter: Filter.equals(
              dbFestenaoMediaStatusFileModel.local.name,
              false,
            ),
          ),
        )
        .getKeys(db);
  }

  /// File to download
  Future<List<String>> fileIdsToDelete() async {
    var db = await _futureDatabase;
    var idsToDelete = <String>[];
    await db.transaction((txn) async {
      var fileIds = await dbMediaStoreRef
          .query(
            finder: Finder(
              filter: Filter.equals(
                dbFestenaoMediaFileModel.deleted.name,
                true,
              ),
            ),
          )
          .getKeys(txn);
      for (var fileId in fileIds) {
        var status = await dbMediaLocalStoreRef.record(fileId).get(txn);
        if (status?.deletedLocal.v != true) {
          idsToDelete.add(fileId);
        }
      }
    });
    return idsToDelete;
  }

  /// Get media file record
  Future<DbFestenaoMediaFile?> getMediaFileRecord(String fileId) async {
    var db = await _futureDatabase;
    var record = await dbMediaStoreRef.record(fileId).get(db);
    return record;
  }

  /// Mark a file as uploaded
  Future<void> markLocalAndRemote(String fileId) async {
    var db = await _futureDatabase;
    await db.transaction((txn) async {
      var file = await dbMediaStoreRef.record(fileId).get(txn);
      if (file != null) {
        file.uploaded.v = true;
        await file.put(txn);
        var status = dbMediaLocalStoreRef.record(fileId).cv();
        status
          ..remote.v = true
          ..local.v = true;
        await status.put(txn);
      }
    });
  }

  /// Mark a file as uploaded
  Future<void> markLocalDeleted(String fileId) async {
    var db = await _futureDatabase;
    await db.transaction((txn) async {
      var file = await dbMediaStoreRef.record(fileId).get(txn);
      if (file != null) {
        var status = dbMediaLocalStoreRef.record(fileId).cv();
        status
          ..remote.v = true
          ..local.v = true
          ..deletedLocal.v = true;
        await status.put(txn);
      }
    });
  }

  /// Write media file bytes.
  Future<void> writeMediaFileBytes(
    FestenaoMediaFileRef ref,
    Uint8List bytes,
  ) async {
    await _writeMediaFileBytes(ref.path, bytes);
  }

  /// Delete media file bytes
  Future<void> deleteMediaFileBytes(FestenaoMediaFileRef ref) async {
    var fsFile = fs.file(ref.path);
    try {
      await fsFile.delete(recursive: true);
    } catch (e) {
      // ignore: avoid_print
      print('Error deleting file $fsFile');
    }
  }
}
