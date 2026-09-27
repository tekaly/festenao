import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as gd;
import 'package:meta/meta.dart';
import 'package:tekartik_common_utils/env_utils.dart';
import 'package:tekartik_gdrive_api_utils/gdrive.dart';

import 'object_storage.dart';

/// Google Drive implementation of [ObjectStorageMeta].
class _GdriveMeta implements ObjectStorageMeta {
  @override
  final String name;
  @override
  final String path; // id
  @override
  final int? size;
  @override
  final String? mimeType;
  @override
  final bool isLocation;

  _GdriveMeta({
    required this.name,
    required this.path, // id
    this.size,
    this.mimeType,
    required this.isLocation,
  });
}

/// The mime type of a drive shortcut (a link to a file or a folder kept
/// elsewhere, "Add shortcut to Drive").
const gdriveShortcutMimeType = 'application/vnd.google-apps.shortcut';

/// The file fields read: a shortcut comes with its target.
const _fileFields =
    'id,name,mimeType,size,shortcutDetails(targetId,targetMimeType)';

/// The meta of a drive [file]; a shortcut is its target — its id, mime type,
/// folder or not — under the name of the shortcut: listed, read or
/// downloaded as if it were there (drive refuses to download a shortcut
/// itself, "Only files with binary content can be downloaded").
@visibleForTesting
ObjectStorageMeta gdriveObjectStorageMeta(gd.File file) {
  var id = file.id!;
  var mimeType = file.mimeType;
  var size = int.tryParse(file.size ?? '');
  var target = file.shortcutDetails;
  if (mimeType == gdriveShortcutMimeType && target?.targetId != null) {
    id = target!.targetId!;
    mimeType = target.targetMimeType;
    // The size is the target's, not listed with the shortcut.
    size = null;
  }
  var isLocation = mimeType == GDrive.folderMimeType;
  return _GdriveMeta(
    name: file.name!,
    path: id,
    size: isLocation ? null : size,
    mimeType: mimeType,
    isLocation: isLocation,
  );
}

/// Google Drive implementation of [ObjectStorageListResponse].
class _GdriveListResponse implements ObjectStorageListResponse {
  @override
  final List<ObjectStorageMeta> items;
  @override
  final String? nextPageToken;

  _GdriveListResponse({required this.items, this.nextPageToken});
}

/// ObjectStorage implementation backed by Google Drive.
///
/// map to a folder named `"images"` containing a file named `"photo.jpg"`.
class ObjectStorageGdrive extends ObjectStorage {
  /// The GDrive helper instance.
  final GDrive gdrive;

  /// Constructor
  ObjectStorageGdrive({required this.gdrive});

  /// The `webContentLink` of a file serves its content: a download stream
  /// fetches it in one request rather than through [downloadPart] (which
  /// downloads the whole file for each part). It only works for whoever may
  /// read the file, anyone for a public one.
  @override
  bool get supportDownloadUrl => true;
  /*
  Future<String> _getOrCreateFolderId(
    List<String> parts,
    String parentId,
  ) async {
    if (parts.isEmpty) return parentId;
    var name = parts.first;
    var fileList = await gdrive.driveApi.files.list(
      pageSize: 10,
      q: "'$parentId' in parents and name='$name' and mimeType='${GDrive.folderMimeType}' and trashed = false",
      $fields: 'files(id)',
    );
    var folderId = fileList.files?.firstOrNull?.id;
    if (folderId == null) {
      var newFolder = gd.File()
        ..name = name
        ..mimeType = GDrive.folderMimeType
        ..parents = [parentId];
      var created = await gdrive.driveApi.files.create(
        newFolder,
        $fields: 'id',
      );
      folderId = created.id!;
    }
    return _getOrCreateFolderId(parts.sublist(1), folderId);
  }

  Future<gd.File?> _findFile(String parentId, String name) async {
    var fileList = await gdrive.driveApi.files.list(
      pageSize: 10,
      q: "'$parentId' in parents and name='$name' and trashed = false",
      $fields: 'files(id,name,mimeType,size)',
    );
    return fileList.files?.firstOrNull;
  }*/

  Future<gd.File> _getFile(String fileId) async {
    var file = await gdrive.driveApi.files.get(fileId, $fields: _fileFields);
    return file as gd.File;
  }

  String _folderIdFromPath(String path) {
    return path;
  }

  @override
  Future<ObjectStorageListResponse> list(
    String path, {
    String? pageToken,
    int? maxResults,
  }) async {
    await gdrive.ready;
    var folderId = _folderIdFromPath(path);

    var fileList = await gdrive.driveApi.files.list(
      pageSize: maxResults ?? 100,
      q: "'$folderId' in parents and trashed = false",
      pageToken: pageToken,
      $fields: 'nextPageToken,files($_fileFields)',
    );
    var items = (fileList.files ?? []).map(gdriveObjectStorageMeta).toList();
    return _GdriveListResponse(
      items: items,
      nextPageToken: fileList.nextPageToken,
    );
  }

  @override
  Future<String?> getDownloadUrl(String path) async {
    await gdrive.ready;
    var file =
        await gdrive.driveApi.files.get(path, $fields: 'webContentLink')
            as gd.File;
    return file.webContentLink;
  }

  /// A shortcut is read as its target (see [gdriveObjectStorageMeta]), its
  /// size included.
  @override
  Future<ObjectStorageMeta> getItem(String path) async {
    await gdrive.ready;
    var object = await _getFile(path);
    var meta = gdriveObjectStorageMeta(object);
    if (meta.path != object.id && !meta.isLocation) {
      var target = gdriveObjectStorageMeta(await _getFile(meta.path));
      return _GdriveMeta(
        name: meta.name,
        path: target.path,
        size: target.size,
        mimeType: target.mimeType,
        isLocation: false,
      );
    }
    return meta;
  }

  ObjectStorageMeta _toMeta(gd.File file) => gdriveObjectStorageMeta(file);

  @override
  Future<ObjectStorageMeta> upload(
    String path, {
    required String name,
    required Uint8List data,
    required String mimeType,
  }) async {
    await gdrive.ready;
    var parentId = path;

    var existing = await gdrive.driveApi.files.list(
      pageSize: 10,
      q: "'$parentId' in parents and name='$name' and trashed = false",
      $fields: 'files(id)',
    );
    var existingId = existing.files?.firstOrNull?.id;
    var media = gd.Media(Stream.value(data), data.length);

    gd.File result;
    if (existingId != null) {
      result = await gdrive.driveApi.files.update(
        gd.File()
          ..name = name
          ..mimeType = mimeType,
        existingId,
        uploadMedia: media,
        $fields: 'id,name,mimeType,size',
      );
    } else {
      result = await gdrive.driveApi.files.create(
        gd.File()
          ..name = name
          ..mimeType = mimeType
          ..parents = [parentId],
        uploadMedia: media,
        enforceSingleParent: true,
        $fields: 'id,name,mimeType,size',
      );
    }

    return _toMeta(result);
  }

  @override
  Future<Uint8List> download(String path) async {
    await gdrive.ready;
    var fileId = path;
    var media =
        await gdrive.driveApi.files.get(
              fileId,
              downloadOptions: gd.DownloadOptions.fullMedia,
            )
            as gd.Media;
    var bytes = <int>[];
    await for (var chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List> downloadPart(String path, int start, int size) async {
    var allBytes = await download(path);
    var end = start + size;
    if (end > allBytes.length) {
      end = allBytes.length;
    }
    return Uint8List.fromList(allBytes.sublist(start, end));
  }

  @override
  Future<void> delete(String path) async {
    await gdrive.ready;
    var fileId = path;
    try {
      await _getFile(fileId);
      await gdrive.deleteFile(fileId);
    } catch (e) {
      if (isDebug) {
        _log('Error getting file for deletion: $e');
      }
    }
  }
}

void _log(Object? message) {
  // ignore: avoid_print
  print(message);
}
