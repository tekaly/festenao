import 'dart:typed_data';
import 'package:fs_shim/fs.dart';
import 'package:path/path.dart' as p;

import 'object_storage.dart';

class _FsMeta implements ObjectStorageMeta {
  @override
  final String name;

  @override
  final String path;

  @override
  final int? size;

  @override
  final String? mimeType;

  @override
  final bool isLocation;

  _FsMeta({
    required this.name,
    required this.path,
    this.size,
    this.mimeType,
    required this.isLocation,
  });
}

class _FsListResponse implements ObjectStorageListResponse {
  @override
  final List<ObjectStorageMeta> items;

  @override
  final String? nextPageToken;

  _FsListResponse({required this.items}) : nextPageToken = null;
}

/// File system implementation of [ObjectStorage] using `fs_shim`.
class ObjectStorageFs extends ObjectStorage {
  /// The underlying file system.
  final FileSystem fileSystem;

  /// The root path of the storage.
  final String rootPath;

  /// Create a new [ObjectStorageFs] instance.
  ObjectStorageFs({required this.fileSystem, required this.rootPath});

  String _toFsPath(String posixPath) {
    var parts = p.posix.split(posixPath);
    var filteredParts = parts
        .where((part) => part.isNotEmpty && part != '.' && part != '..')
        .toList();
    return fileSystem.path.joinAll([rootPath, ...filteredParts]);
  }

  String? _mimeTypeFromPath(String path) {
    var ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.txt':
        return 'text/plain';
      case '.bin':
        return 'application/octet-stream';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.json':
        return 'application/json';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Future<void> delete(String path) async {
    var fsPath = _toFsPath(path);

    var file = fileSystem.file(fsPath);
    if (await file.exists()) {
      await file.delete();
      return;
    }

    var dir = fileSystem.directory(fsPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      return;
    }
  }

  @override
  Future<Uint8List> download(String path) async {
    var fsPath = _toFsPath(path);
    var file = fileSystem.file(fsPath);
    if (!await file.exists()) {
      throw Exception('File not found: $path');
    }
    return Uint8List.fromList(await file.readAsBytes());
  }

  @override
  Future<Uint8List> downloadPart(String path, int start, int size) async {
    var fsPath = _toFsPath(path);
    var file = fileSystem.file(fsPath);
    if (!await file.exists()) {
      throw Exception('File not found: $path');
    }
    try {
      var stream = file.openRead(start, start + size);
      var bytes = <int>[];
      await for (var chunk in stream) {
        bytes.addAll(chunk);
      }
      return Uint8List.fromList(bytes);
    } catch (_) {
      var allBytes = await file.readAsBytes();
      var end = start + size;
      if (end > allBytes.length) {
        end = allBytes.length;
      }
      return Uint8List.fromList(allBytes.sublist(start, end));
    }
  }

  @override
  Stream<Uint8List> downloadStream(
    String path, {
    int? start,
    int? size,
    int? chunkSize,
  }) {
    var fsPath = _toFsPath(path);
    var file = fileSystem.file(fsPath);
    int? end;
    if (size != null) {
      end = (start ?? 0) + size;
    }
    return file.openRead(start, end).map(Uint8List.fromList);
  }

  @override
  Future<ObjectStorageMeta> getItem(String path) async {
    var fsPath = _toFsPath(path);

    var file = fileSystem.file(fsPath);
    if (await file.exists()) {
      var stat = await file.stat();
      return _FsMeta(
        name: fileSystem.path.basename(fsPath),
        path: path,
        size: stat.size,
        mimeType: _mimeTypeFromPath(path),
        isLocation: false,
      );
    }

    var dir = fileSystem.directory(fsPath);
    if (await dir.exists()) {
      return _FsMeta(
        name: fileSystem.path.basename(fsPath),
        path: path,
        size: null,
        mimeType: null,
        isLocation: true,
      );
    }

    throw Exception('Object not found: $path');
  }

  @override
  Future<ObjectStorageListResponse> list(
    String path, {
    String? pageToken,
    int? maxResults,
  }) async {
    var fsPath = _toFsPath(path);
    var dir = fileSystem.directory(fsPath);

    if (!await dir.exists()) {
      return _FsListResponse(items: []);
    }

    var list = await dir.list(recursive: false).toList();
    var items = <ObjectStorageMeta>[];

    for (var entity in list) {
      var name = fileSystem.path.basename(entity.path);
      var posixPath = p.posix.join(path, name);

      if (entity is File) {
        var stat = await entity.stat();
        items.add(
          _FsMeta(
            name: name,
            path: posixPath,
            size: stat.size,
            mimeType: _mimeTypeFromPath(posixPath),
            isLocation: false,
          ),
        );
      } else if (entity is Directory) {
        items.add(
          _FsMeta(
            name: name,
            path: posixPath,
            size: null,
            mimeType: null,
            isLocation: true,
          ),
        );
      }
    }

    items.sort((a, b) => a.name.compareTo(b.name));

    return _FsListResponse(items: items);
  }

  @override
  Future<ObjectStorageMeta> upload(
    String path, {
    required String name,
    required Uint8List data,
    required String mimeType,
  }) async {
    var filePosixPath = p.posix.join(path, name);
    var fsPath = _toFsPath(filePosixPath);

    var file = fileSystem.file(fsPath);
    var parentDir = file.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    await file.writeAsBytes(data);

    return _FsMeta(
      name: name,
      path: filePosixPath,
      size: data.length,
      mimeType: mimeType,
      isLocation: false,
    );
  }
}
