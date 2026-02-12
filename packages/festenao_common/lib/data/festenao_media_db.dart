import 'dart:typed_data';

import 'package:fs_shim/fs_shim.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';
import 'package:tekartik_app_text/sanitize.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

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
  /// Original filename of the media file, used to determine the file extension and for reference. This field is not used for storage but can be helpful for management and debugging purposes.
  final originalFilename = CvField<String>('filename');

  /// Path to the media file in the file system, stored as a string. This field is used to locate the media file for retrieval and management.
  final path = CvField<String>('path');

  /// Timestamp when the media file was created.
  final createdTimestamp = cvEncodedTimestampField('createdTimestamp');

  @override
  CvFields get fields => [originalFilename, path, createdTimestamp];
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

  /// no leading .
  String _fileExtension(String filename) {
    var parts = filename.split('.');
    if (parts.length > 1) {
      return parts.last;
    } else {
      return '';
    }
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
  /// This method generates a unique ID for the file, saves it to the file system, and creates a corresponding record in the SDB database.
  /// The media file is stored in a nested directory structure based on the generated ID to avoid too many files in a single directory.
  /// The database record includes timestamps for creation and last update, which can be used for management and cleanup purposes.
  /// This method ensures that the media file is properly stored and indexed in the database for later retrieval and management.
  /// Note: Error handling and edge cases (e.g., file write failures, database errors) should be implemented as needed for robustness.
  /// Example usage:
  /// ```dart
  /// final mediaDb = FestenaoMediaDb(sdbFactory: mySdbFactory
  ///    , fs: myFileSystem);
  Future<String> addMediaFile({
    required Uint8List bytes,
    required String filename,

    // Perform any necessary setup or migrations here
  }) async {
    // work on any file style
    var originalFilename = filename.split('/').last.split('\\').last;
    if (originalFilename.isEmpty) {
      originalFilename = 'file';
    }
    // sanitize filename to prevent issues with file system and storage
    var basename = sanitizeString(originalFilename).truncate(24);
    var extension = _fileExtension(originalFilename);
    // 1. Generate a unique ID for the media file
    final uid = _uuid.v4().replaceAll('-', '');

    var fileId = uid;

    // Find a good file id
    var db = await _db;
    var folder1 = fileId.substring(0, 2).toLowerCase();
    var folder2 = fileId.substring(2, 4).toLowerCase();
    late String path;
    await db.inStoreTransaction(
      _dbFestenaoMediaFileStore.rawRef,
      SdbTransactionMode.readWrite,
      (txn) async {
        // 1. Take the first two chunks of the ID for nesting
        // We use lowercase to avoid issues on case-insensitive file systems
        for (var i = 4; i <= uid.length; i++) {
          fileId = '${uid.truncate(i)}_$basename.$extension';
          if (!await _dbFestenaoMediaFileStore.record(fileId).exists(txn)) {
            break;
          }
        }
        path = fs.path.join(folder1, folder2, fileId);
        var mediaRecord = _dbFestenaoMediaFileStore.record(fileId).cv()
          ..createdTimestamp.value = ScvTimestamp.now()
          ..originalFilename.value = originalFilename
          ..path.value = path;

        // 5. Save the record to the database

        await mediaRecord.put(txn);
      },
    );

    var file = fs.file(path);
    // Write the media bytes to the storage file
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);

    return fileId;
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
    return fileRecord.path.v!;
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
          // Mark the record as deleted in the transaction
          await _dbFestenaoMediaFileStore.record(fileId).delete(txn);
        }
      },
    );

    var path = _ensurePath(fileId, fileRecord);

    // 1. Get the storage file path
    final storageFile = fs.file(path);

    // 2. Delete the media file from the storage
    if (await storageFile.exists()) {
      await storageFile.delete();
    }
  }
}
