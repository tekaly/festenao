import 'dart:typed_data';

import 'package:festenao_common/data/festenao_media.dart';
import 'package:festenao_common/festenao_sdb.dart';
import 'package:tekaly_sdb_synced/synced_sdb.dart';
import 'package:tekaly_sdb_synced_media/synced_media.dart'
    hide SdbSyncedMediaFileExt, SdbSyncedMediaFileStatusExt;

export 'package:tekaly_sdb_synced_media/synced_media.dart'
    show SyncedMediaSdbInternalExt, SyncedMediaCacheStat;

/// Exception class for errors related to the FestenaoMediaDb.
typedef FestenaoMediaSdbException = SyncedMediaSdbException;

/// Not synced, id is same as file id (see `SdbSyncedMediaFileStatus`).
typedef SdbFestenaoMediaFileStatus = SdbSyncedMediaFileStatus;

/// Extension for [SdbFestenaoMediaFileStatus] to provide boolean helpers.
///
/// Same as `SdbSyncedMediaFileStatusExt`, do not import both.
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
final sdbFestenaoMediaStatusFileModel = sdbSyncedMediaFileStatusModel;

/// Database record class for media files in Festenao, using SDB for metadata
/// storage (see `SdbSyncedMediaFile`).
typedef SdbFestenaoMediaFile = SdbSyncedMediaFile;

/// model
final sdbFestenaoMediaFileModel = sdbSyncedMediaFileModel;

/// Media store
final sdbMediaStore = syncedMediaSdbStoresDefault.mediaStore;

/// Media schema
final sdbMediaStoreSchema = sdbMediaStore.schema();

/// Not synced
final sdbMediaStatusLocalStore = syncedMediaSdbStoresDefault.statusStore;

/// index local/remote/deleted
final sdbMediaStatusLocalRemoteDeletedIndex =
    syncedMediaSdbStoresDefault.statusIndex;

/// All media stores (media, status and its index).
final sdbMediaSchemaStores = syncedMediaSdbStoresDefault.schemaStores;

/// All synced stores for media and their content
final syncedSdbMediaSchemaStores = [
  ...sdbMediaSchemaStores,
  ...syncedSdbMetaSchema.stores,
];

/// Media database for Festenao, using SDB for metadata and the file system for
/// media storage (see `SyncedMediaSdb`).
class FestenaoMediaSdb extends SyncedMediaSdb {
  /// Media part
  static String mediaPart = 'media';

  /// Google storage path
  static List<String> projectStorageParts(String projectId) => [
    'project',
    projectId,
  ];

  /// Constructor for FestenaoMediaDb, requiring an SDB database and a file
  /// system.
  FestenaoMediaSdb({required super.fs, required super.database});

  /// Fix missing uploaded
  Future<SdbFestenaoMediaFile?> fixMediaFileRecord(String fileId) async {
    var record = await sdbMediaStore.record(fileId).get(database);
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
        await record.put(database);
      }
    }
    return record;
  }

  /// Write media file bytes.
  Future<void> writeMediaFileBytes(
    FestenaoMediaFileRef ref,
    Uint8List bytes,
  ) async {
    var fsFile = localFile(ref.path);
    await fsFile.parent.create(recursive: true);
    await fsFile.writeAsBytes(bytes);
  }

  /// Delete media file bytes
  Future<void> deleteMediaFileBytes(FestenaoMediaFileRef ref) =>
      deleteContentAt(ref.path);
}

/// Extension for [SdbFestenaoMediaFile] to provide status helpers.
///
/// Same as `SdbSyncedMediaFileExt`, do not import both.
extension SdbFestenaoMediaFileExt on SdbFestenaoMediaFile {
  /// Whether the file is marked as deleted.
  bool get isDeleted => deleted.v ?? false;

  /// Whether the file has been uploaded.
  bool get isUploaded => uploaded.v ?? false;
}
