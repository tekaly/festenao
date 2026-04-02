import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as gd;
import 'package:tekartik_gdrive_api_utils/gdrive.dart';

import 'object_storage.dart';

/// Google Drive implementation of [ObjectStorageMeta].
class _GdriveMeta implements ObjectStorageMeta {
  @override
  final String path;
  @override
  final int? size;
  @override
  final String? mimeType;
  @override
  final bool isLocation;

  _GdriveMeta({
    required this.path,
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
/// Files are stored under [rootFolderId]. Paths like `"images/photo.jpg"`
/// map to a folder named `"images"` containing a file named `"photo.jpg"`.
class ObjectStorageGdrive extends ObjectStorage {
  /// The GDrive helper instance.
  final GDrive gdrive;

  /// The Google Drive folder ID used as the root of the storage hierarchy.
  final String rootFolderId;

  /// Constructor
  ObjectStorageGdrive({required this.gdrive, required this.rootFolderId});

  List<String> _splitPath(String path) =>
      path.split('/').where((p) => p.isNotEmpty).toList();

  Future<String?> _findFolderId(List<String> parts, String parentId) async {
    if (parts.isEmpty) return parentId;
    var name = parts.first;
    var fileList = await gdrive.driveApi.files.list(
      pageSize: 10,
      q: "'$parentId' in parents and name='$name' and mimeType='${GDrive.folderMimeType}' and trashed = false",
      $fields: 'files(id)',
    );
    var folder = fileList.files?.firstOrNull;
    if (folder?.id == null) return null;
    return _findFolderId(parts.sublist(1), folder!.id!);
  }

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

  Future<gd.File?> _findFile(String path) async {
    var parts = _splitPath(path);
    if (parts.isEmpty) return null;
    var fileName = parts.last;
    var parentId = await _findFolderId(
      parts.sublist(0, parts.length - 1),
      rootFolderId,
    );
    if (parentId == null) return null;
    var fileList = await gdrive.driveApi.files.list(
      pageSize: 10,
      q: "'$parentId' in parents and name='$fileName' and trashed = false",
      $fields: 'files(id,name,mimeType,size)',
    );
    return fileList.files?.firstOrNull;
  }

  @override
  Future<ObjectStorageListResponse> list(
    String path, {
    String? pageToken,
    int? maxResults,
  }) async {
    var parts = _splitPath(path);
    var folderId = await _findFolderId(parts, rootFolderId);
    if (folderId == null) {
      return _GdriveListResponse(items: []);
    }
    var fileList = await gdrive.driveApi.files.list(
      pageSize: maxResults ?? 100,
      q: "'$folderId' in parents and trashed = false",
      pageToken: pageToken,
      $fields: 'nextPageToken,files(id,name,mimeType,size)',
    );
    var basePath = parts.isEmpty ? '' : '${parts.join('/')}/';
    var items = (fileList.files ?? []).map((f) {
      var isFolder = f.mimeType == GDrive.folderMimeType;
      return _GdriveMeta(
        path: '$basePath${f.name}',
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
  Future<ObjectStorageMeta> getMeta(String path) async {
    var file = await _findFile(path);
    if (file == null) throw Exception('File not found: $path');
    return _GdriveMeta(
      path: path,
      size: int.tryParse(file.size ?? ''),
      mimeType: file.mimeType,
      isLocation: false,
    );
  }

  @override
  Future<ObjectStorageMeta> upload(String path, Uint8List data) async {
    var parts = _splitPath(path);
    if (parts.isEmpty) throw ArgumentError('Invalid path: $path');
    var fileName = parts.last;
    var parentId = await _getOrCreateFolderId(
      parts.sublist(0, parts.length - 1),
      rootFolderId,
    );

    var existing = await gdrive.driveApi.files.list(
      pageSize: 10,
      q: "'$parentId' in parents and name='$fileName' and trashed = false",
      $fields: 'files(id)',
    );
    var existingId = existing.files?.firstOrNull?.id;
    var media = gd.Media(Stream.value(data), data.length);

    gd.File result;
    if (existingId != null) {
      result = await gdrive.driveApi.files.update(
        gd.File()..name = fileName,
        existingId,
        uploadMedia: media,
        $fields: 'id,name,mimeType,size',
      );
    } else {
      result = await gdrive.driveApi.files.create(
        gd.File()
          ..name = fileName
          ..parents = [parentId],
        uploadMedia: media,
        enforceSingleParent: true,
        $fields: 'id,name,mimeType,size',
      );
    }

    return _GdriveMeta(
      path: path,
      size: int.tryParse(result.size ?? ''),
      mimeType: result.mimeType,
      isLocation: false,
    );
  }

  @override
  Future<Uint8List> download(String path) async {
    var file = await _findFile(path);
    if (file == null) throw Exception('File not found: $path');
    var media =
        await gdrive.driveApi.files.get(
              file.id!,
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
    var file = await _findFile(path);
    if (file == null) throw Exception('File not found: $path');
    await gdrive.deleteFile(file.id!);
  }
}
