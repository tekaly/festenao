import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as gd;
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

  Future<Object> _getFile(String fileId) async {
    var file = await gdrive.driveApi.files.get(
      fileId,
      $fields: 'files(id,name,mimeType,size)',
    );
    return file;
  }

  @override
  Future<ObjectStorageListResponse> list(
    String path, {
    String? pageToken,
    int? maxResults,
  }) async {
    await gdrive.ready;
    var folderId = path;
    var fileList = await gdrive.driveApi.files.list(
      pageSize: maxResults ?? 100,
      q: "'$folderId' in parents and trashed = false",
      pageToken: pageToken,
      $fields: 'nextPageToken,files(id,name,mimeType,size)',
    );
    var items = (fileList.files ?? []).map((f) {
      var isFolder = f.mimeType == GDrive.folderMimeType;
      return _GdriveMeta(
        name: f.name!,
        path: folderId,
        size: isFolder ? null : int.tryParse(f.size ?? ''),
        mimeType: isFolder ? null : f.mimeType,
        isLocation: isFolder,
      );
    }).toList();
    return _GdriveListResponse(
      items: items,
      nextPageToken: fileList.nextPageToken,
    );
  }

  @override
  Future<ObjectStorageMeta> getItem(String path) async {
    await gdrive.ready;
    var object = await _getFile(path);
    if (object is gd.File) {
      return _toMeta(object);
    }
    throw Exception('Item not found: $path');
  }

  ObjectStorageMeta _toMeta(gd.File file) {
    var isLocation = file.mimeType == GDrive.folderMimeType;
    return _GdriveMeta(
      name: file.name!,
      path: file.id!,
      size: int.tryParse(file.size ?? ''),
      mimeType: file.mimeType,
      isLocation: isLocation,
    );
  }

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
  Future<void> delete(String path) async {
    await gdrive.ready;
    var fileId = path;
    var file = await _getFile(fileId);
    if (file is gd.File) {
      await gdrive.deleteFile(fileId);
    }
  }
}
