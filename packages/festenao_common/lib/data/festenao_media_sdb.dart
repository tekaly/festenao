import 'dart:typed_data';

import 'package:festenao_common/data/festenao_media.dart';
import 'package:festenao_common/festenao_sdb.dart';
import 'package:fs_shim/fs_shim.dart';
import 'package:meta/meta.dart';
import 'package:tekaly_sdb_synced/synced_sdb.dart';

/// Exception class for errors related to the FestenaoMediaDb.
class FestenaoMediaSdbException implements Exception {
  /// Error message describing the exception.
  final String message;

  /// Constructor for creating a FestenaoMediaDbException with a specific message.
  FestenaoMediaSdbException(this.message);

  @override
  String toString() => 'FestenaoMediaDbException: $message';
}

/// Not synced
/// Id is same as file id
class SdbFestenaoMediaFileStatus extends ScvStringRecordBase {
  /// Downloaded (1 or 0) or present locally
  final local = CvField<int>('local');

  /// Uploaded (1 or 0) or present remotely
  final remote = CvField<int>('remote');

  /// Deleted
  final deleted = CvField<int>('deleted');
  @override
  CvFields get fields => [remote, local, deleted];
}

/// Extension for [SdbFestenaoMediaFileStatus] to provide boolean helpers.
extension SdbFestenaoMediaFileStatusExt on SdbFestenaoMediaFileStatus {
  /// Whether the file is present locally.
  bool get isLocal => local.v == 1;

  /// Whether the file is present remotely.
  bool get isRemote => remote.v == 1;

  /// Whether the file is marked as deleted.
  bool get isDeleted => deleted.v == 1;

  /// Set the local status.
  void setLocal(bool? local) => this.local.v = (local ?? false) ? 1 : 0;

  /// Set the remote status.
  void setRemote(bool? remote) => this.remote.v = (remote ?? false) ? 1 : 0;

  /// Set the deleted status.
  void setDeleted(bool? deleted) => this.deleted.v = (deleted ?? false) ? 1 : 0;
}

/// model
final sdbFestenaoMediaStatusFileModel = SdbFestenaoMediaFileStatus();

/// Database record class for media files in Festenao, using SDB for metadata storage.
class SdbFestenaoMediaFile extends ScvStringRecordBase {
  /// Media type (mime type)
  final type = CvField<String>('type');

  /// File size
  final size = CvField<int>('size');

  /// Original filename of the media file, used to determine the file extension and for reference. This field is not used for storage but can be helpful for management and debugging purposes.
  final originalFilename = CvField<String>('filename');

  /// Path to the media file in the file system, stored as a string. This field is used to locate the media file for retrieval and management.
  final path = CvField<String>('path');

  /// Timestamp when the media file was created (local only)
  final createdTimestamp = CvField<SdbTimestamp>('createdTimestamp');

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
    deleted,
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
final sdbFestenaoMediaFileModel = SdbFestenaoMediaFile();

/// Media store
final sdbMediaStore = ScvStoreRef<String, SdbFestenaoMediaFile>('media');

/// Media schema
final sdbMediaStoreSchema = sdbMediaStore.schema();

/// Not synced
final sdbMediaStatusLocalStore =
    ScvStoreRef<String, SdbFestenaoMediaFileStatus>(
      'local_media_status',
    ); // local prefix to ignore sdb synchronization

/// index local/remote/deleted
final sdbMediaStatusLocalRemoteDeletedIndex = sdbMediaStatusLocalStore.index3(
  'local_remote_deleted',
);

/// Schema
final sdbMediaStatusLocalRemoteDeletedIndexSchema =
    sdbMediaStatusLocalRemoteDeletedIndex.schema(
      keyPath: [
        sdbFestenaoMediaStatusFileModel.local.name,
        sdbFestenaoMediaStatusFileModel.remote.name,
        sdbFestenaoMediaStatusFileModel.deleted.name,
      ],
    );

/// status schema
final sdbMediaStatusLocalStoreSchema = sdbMediaStatusLocalStore.schema(
  indexes: [sdbMediaStatusLocalRemoteDeletedIndexSchema],
);

/// All media stores
final sdbMediaSchemaStores = [
  sdbMediaStoreSchema,
  sdbMediaStatusLocalStoreSchema,
];

/// All synced stores for media and their content
final syncedSdbMediaSchemaStores = [
  ...sdbMediaSchemaStores,
  ...syncedSdbMetaSchema.stores,
];

/// Media database for Festenao, using SDB for metadata and the file system for media storage.
class FestenaoMediaSdb {
  /// Media part
  static String mediaPart = 'media';

  /// Google storage path
  static List<String> projectStorageParts(String projectId) => [
    'project',
    projectId,
  ];

  /// Opened database, valid when ready
  //late final SdbDatabase database;

  /// File system
  final FileSystem fs;

  /// Db path
  final SdbDatabase database;

  /// Constructor for FestenaoMediaDb, requiring an SDB factory and a file system.
  FestenaoMediaSdb({required this.fs, required this.database}) {
    cvAddConstructors([
      SdbFestenaoMediaFile.new,
      SdbFestenaoMediaFileStatus.new,
    ]);
  }

  Future<void> _writeMediaFileBytes(String path, Uint8List bytes) async {
    var fsFile = fs.file(path);
    await fsFile.parent.create(recursive: true);
    await fsFile.writeAsBytes(bytes);
  }

  /// Adds a media file to the database and storage.
  /// [bytes] is the content of the media file.
  /// [filename] is the original filename, used to determine the file extension.
  ///
  /// Returns the mediaId.
  Future<String> addMediaFile({
    required FestenaoMediaFile file,
    required Uint8List bytes,
  }) async {
    var db = database;
    var uid = file.uid;
    var path = file.path;
    var size = file.size ?? bytes.length;

    /// First write the file
    await _writeMediaFileBytes(path, bytes);

    // Then add to db, we know it exists, locally only
    await db.inScvStoresTransaction(
      [sdbMediaStore, sdbMediaStatusLocalStore],
      SdbTransactionMode.readWrite,
      (txn) async {
        var mediaRecord = sdbMediaStore.record(uid).cv()
          ..createdTimestamp.value = SdbTimestamp.now()
          ..type.setValue(file.type)
          ..size.setValue(size)
          ..originalFilename.setValue(file.originalFilename)
          ..path.value = path;
        await mediaRecord.put(txn);
        var statusRecord = sdbMediaStatusLocalStore.record(uid).cv()
          ..local.v = 1
          ..remote.v = 0
          ..deleted.v = 0;
        await statusRecord.put(txn);
      },
    );

    return uid;
  }

  /// Reads the media file bytes for the given [fileId].
  Future<File> getMediaFile(String fileId) async {
    return (await _getMediaFile(fileId)).$2;
  }

  /// Reads the media file bytes for the given [fileId].
  Future<(SdbFestenaoMediaFile, File file)> _getMediaFile(String fileId) async {
    var db = database;
    var fileRecord = await sdbMediaStore.record(fileId).get(db);
    if (fileRecord == null) {
      throw FestenaoMediaSdbException(
        'Media file record not found for ID: $fileId',
      );
    }

    var path = _ensurePath(fileId, fileRecord);
    return (fileRecord, fs.file(path));
  }

  /// Reads the media file bytes for the given [fileId].
  Future<Uint8List> readMediaFileBytes(String fileId) async {
    return (await getMediaFile(fileId)).readAsBytes();
  }

  /// Checks if a media file exists locally and matches the recorded size.
  Future<bool> mediaFileExists(String fileId) async {
    var (mediaFile, file) = await _getMediaFile(fileId);
    var stat = await file.stat();
    return stat.size == mediaFile.size.v;
  }

  String _ensurePath(String fileId, SdbFestenaoMediaFile? fileRecord) {
    if (fileRecord == null) {
      throw FestenaoMediaSdbException(
        'Media file record not found for ID: $fileId',
      );
    }
    if (fileRecord.path.v == null) {
      throw FestenaoMediaSdbException(
        'Media file path is missing for ID: $fileId',
      );
    }
    return fs.path.normalize(fileRecord.path.v!);
  }

  /// Deletes the media file database entry [fileId], must be deleted first
  Future<void> purgeMediaFile(String fileId) async {
    var db = database;
    // Delete in db first
    await db.inScvStoresTransaction(
      [sdbMediaStore, sdbMediaStatusLocalStore],
      SdbTransactionMode.readWrite,
      (txn) async {
        var fileRecordRef = sdbMediaStore.record(fileId);
        final fileStatusRecordRef = sdbMediaStatusLocalStore.record(fileId);
        var file = await fileRecordRef.get(txn);
        if (file != null && (file.deleted.v == true)) {
          await fileRecordRef.delete(txn);
          await fileStatusRecordRef.delete(txn);
        }
      },
    );
  }

  /// Mark the the media as deleted and delete the file content.
  Future<void> deleteMediaFile(String fileId, {bool purge = false}) async {
    var db = database;
    SdbFestenaoMediaFile? fileRecord;
    // Delete in db first
    await db.inScvStoresTransaction(
      [sdbMediaStore, sdbMediaStatusLocalStore],
      SdbTransactionMode.readWrite,
      (txn) async {
        var fileRecordRef = sdbMediaStore.record(fileId);
        final fileStatusRecordRef = sdbMediaStatusLocalStore.record(fileId);
        var file = await fileRecordRef.get(txn);
        var status =
            (await fileStatusRecordRef.get(txn)) ?? fileStatusRecordRef.cv();
        if (file != null) {
          fileRecord = file;
          if (purge) {
            await fileRecordRef.delete(txn);
            await fileStatusRecordRef.delete(txn);
          } else {
            file.deleted.v = true;
            status
              ..local.v = 0
              ..deleted.v = 1;

            await file.put(txn);
            await status.put(txn);
          }
        }
      },
    );

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
  Future<List<SdbFestenaoMediaFile>> getAllRecords() async {
    var db = database;
    var records = await sdbMediaStore.findRecords(db);
    return records;
  }

  /// File ids to upload (delete and create)
  Future<List<String>> fileIdsToUpload() async {
    var db = database;

    /// local but not remote
    return await sdbMediaStatusLocalRemoteDeletedIndex
        .record(1, 0, 0)
        .findRecordPrimaryKeys(db);
  }

  /// File ids to delete remotely
  Future<List<String>> fileIdsToDeleteRemotely() async {
    var db = database;

    /// remote only and deleted
    return await sdbMediaStatusLocalRemoteDeletedIndex
        .record(0, 1, 1)
        .findRecordPrimaryKeys(db);
  }

  /// File to download
  Future<List<String>> fileIdsToDownload() async {
    var db = database;
    return await sdbMediaStatusLocalRemoteDeletedIndex
        .record(0, 1, 0)
        .findRecordPrimaryKeys(db);
  }

  /// File to deleted
  Future<List<String>> fileIdsToDeleteLocally() async {
    var db = database;
    return await sdbMediaStatusLocalRemoteDeletedIndex
        .record(1, 0, 1)
        .findRecordPrimaryKeys(db);
  }

  /// file record entry
  Future<List<String>> findFileRecordKeys({SdbClient? client}) async {
    var dbClient = client ?? database;
    var keys = await sdbMediaStore.findRecordKeys(dbClient);
    return keys;
  }

  /// file status entry
  Future<List<String>> findFileStatusRecordKeys({SdbClient? client}) async {
    var dbClient = client ?? database;
    var keys = await sdbMediaStatusLocalStore.findRecordKeys(dbClient);
    return keys;
  }

  /// Files to inspect
  Future<List<String>> fileIdsDirty() async {
    var db = database;
    return await sdbMediaStatusLocalRemoteDeletedIndex
        .record(0, 0, 0)
        .findRecordPrimaryKeys(db);
  }

  /// Get media file record
  Future<SdbFestenaoMediaFile?> getMediaFileRecord(String fileId) async {
    var db = database;
    var record = await sdbMediaStore.record(fileId).get(db);
    return record;
  }

  /// Fix missing uploaded
  Future<SdbFestenaoMediaFile?> fixMediaFileRecord(String fileId) async {
    var db = database;
    var record = await sdbMediaStore.record(fileId).get(db);
    if (record != null) {
      var changed = false;
      if (record.uploaded.v == null) {
        record.uploaded.v = false;
        changed = true;
      }
      if (record.deleted.v == null) {
        record.deleted.v = false;
        changed = true;
      }
      if (changed) {
        await record.put(db);
      }
    }
    return record;
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

/// Internal extension for FestenaoMediaSdb
extension FestenaoMediaSdbInternalExt on FestenaoMediaSdb {
  /// Mark a file as uploaded
  Future<void> updateStatus(
    String fileId, {
    bool? local,
    bool? remote,
    bool? localDeleted,
  }) async {
    var db = database;
    await db.inScvStoresTransaction(
      [sdbMediaStatusLocalStore],
      SdbTransactionMode.readWrite,
      (txn) async {
        var status =
            (await sdbMediaStatusLocalStore.record(fileId).get(txn)) ??
            sdbMediaStatusLocalStore.record(fileId).cv();

        local ??= status.isLocal;
        remote ??= status.isRemote;
        localDeleted ??= status.isDeleted;
        status
          ..setLocal(local)
          ..setDeleted(localDeleted)
          ..setRemote(remote);
        await status.put(txn);
      },
    );
  }

  /// Mark a file as uploaded
  Future<void> markDownloadedAndUploaded(String fileId) async {
    var db = database;
    await db.inScvStoresTransaction(
      [sdbMediaStore, sdbMediaStatusLocalStore],
      SdbTransactionMode.readWrite,
      (txn) async {
        var file = await sdbMediaStore.record(fileId).get(txn);
        if (file != null) {
          file.uploaded.v = true;
          await file.put(txn);
          var status = sdbMediaStatusLocalStore.record(fileId).cv();
          status
            ..setLocal(true)
            ..setRemote(true)
            ..setDeleted(false);
          await status.put(txn);
        }
      },
    );
  }

  /// Mark a file as uploaded
  Future<void> markLocalDeleted(String fileId) async {
    var db = database;
    await db.inScvStoresTransaction(
      [sdbMediaStore, sdbMediaStatusLocalStore],
      SdbTransactionMode.readWrite,
      (txn) async {
        var file = await sdbMediaStore.record(fileId).get(txn);
        if (file != null) {
          var status = sdbMediaStatusLocalStore.record(fileId).cv();
          status
            ..setLocal(false)
            ..setRemote(false)
            ..setDeleted(true);
          await status.put(txn);
        }
      },
    );
  }

  /// Mark a file as to upload
  Future<void> markToUpload(String fileId) async {
    var db = database;
    await db.inScvStoresTransaction(
      [sdbMediaStore, sdbMediaStatusLocalStore],
      SdbTransactionMode.readWrite,
      (txn) async {
        var file = await sdbMediaStore.record(fileId).get(txn);
        if (file != null) {
          var status = sdbMediaStatusLocalStore.record(fileId).cv();
          status
            ..setLocal(true)
            ..setRemote(false)
            ..setDeleted(false);
          await status.put(txn);
        }
      },
    );
  }

  /// Mark a file as remote deleted
  Future<void> markRemoteDeleted(String fileId) async {
    var db = database;
    await db.inScvStoresTransaction(
      [sdbMediaStore, sdbMediaStatusLocalStore],
      SdbTransactionMode.readWrite,
      (txn) async {
        var file = await sdbMediaStore.record(fileId).get(txn);
        var statusRef = sdbMediaStatusLocalStore.record(fileId);
        var fileStatus = (await statusRef.get(txn)) ?? statusRef.cv();
        if (file != null) {
          if (file.deleted.v != true) {
            file.deleted.v = true;
            await file.put(txn);
          }
          fileStatus
            ..setRemote(false)
            ..setDeleted(true);
          await fileStatus.put(txn);
        }
      },
    );
  }

  /// Mark a file as local not present
  @visibleForTesting
  Future<void> markLocalNotPresent(String fileId) async {
    var db = database;
    await db.inScvStoresTransaction(
      [sdbMediaStore, sdbMediaStatusLocalStore],
      SdbTransactionMode.readWrite,
      (txn) async {
        var file = await sdbMediaStore.record(fileId).get(txn);
        var statusRef = sdbMediaStatusLocalStore.record(fileId);
        var fileStatus = (await statusRef.get(txn)) ?? statusRef.cv();
        if (file != null) {
          fileStatus.setLocal(false);
          await fileStatus.put(txn);
        }
      },
    );
  }

  /// Mark a file as no info, check on synchronization
  Future<void> markStatusCleared(String fileId) async {
    var db = database;
    await db.inScvStoresTransaction(
      [sdbMediaStore, sdbMediaStatusLocalStore],
      SdbTransactionMode.readWrite,
      (txn) async {
        var file = await sdbMediaStore.record(fileId).get(txn);
        var statusRef = sdbMediaStatusLocalStore.record(fileId);
        var fileStatus = (await statusRef.get(txn)) ?? statusRef.cv();
        if (file != null) {
          fileStatus
            ..setLocal(false)
            ..setRemote(false)
            ..setDeleted(false);
          await fileStatus.put(txn);
        }
      },
    );
  }

  /// Mark a file as no info, check on synchronization
  @visibleForTesting
  Future<void> deleteStatusRecord(String fileId) async {
    var db = database;
    await db.inScvStoresTransaction(
      [sdbMediaStore, sdbMediaStatusLocalStore],
      SdbTransactionMode.readWrite,
      (txn) async {
        var statusRef = sdbMediaStatusLocalStore.record(fileId);
        await statusRef.delete(txn);
      },
    );
  }
}

/// Extension for [SdbFestenaoMediaFile] to provide status helpers.
extension SdbFestenaoMediaFileExt on SdbFestenaoMediaFile {
  /// Whether the file is marked as deleted.
  bool get isDeleted => deleted.v ?? false;

  /// Whether the file has been uploaded.
  bool get isUploaded => uploaded.v ?? false;
}
