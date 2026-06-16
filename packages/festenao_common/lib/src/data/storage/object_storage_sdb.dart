import 'dart:typed_data';
import 'package:fs_shim/fs_memory.dart';
import 'package:path/path.dart' as p;
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';

import 'object_storage.dart';

/// SDB record for stored objects metadata.
class SdbObjectRecord extends ScvStringRecordBase {
  /// Name of the object.
  final name = CvField<String>('name');

  /// POSIX path of the object.
  final path = CvField<String>('path');

  /// Size in bytes.
  final size = CvField<int>('size');

  /// MIME type.
  final mimeType = CvField<String>('mimeType');

  @override
  CvFields get fields => [name, path, size, mimeType];
}

final _sdbObjectModel = SdbObjectRecord();

/// Initialize constructors for SDB object storage records.
void initSdbObjectBuilders() {
  cvAddConstructors([SdbObjectRecord.new]);
}

/// Default SDB filename.
const objectStorageSdbName = 'object_storage_v1.db';

/// SDB store for object records.
final sdbObjectStore = scvStringStoreFactory.store<SdbObjectRecord>('object');

class _SdbMeta implements ObjectStorageMeta {
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

  _SdbMeta({
    required this.name,
    required this.path,
    this.size,
    this.mimeType,
    required this.isLocation,
  });
}

class _SdbListResponse implements ObjectStorageListResponse {
  @override
  final List<ObjectStorageMeta> items;

  @override
  final String? nextPageToken;

  _SdbListResponse({required this.items}) : nextPageToken = null;
}

/// SDB implementation of [ObjectStorage] storing content on a [FileSystem].
class ObjectStorageSdb extends ObjectStorage {
  /// The database factory.
  final SdbFactory factory;

  /// The underlying file system.
  final FileSystem fileSystem;

  /// The root directory for the files.
  final String rootPath;

  /// The database name.
  final String? name;

  /// The database instance.
  late final SdbDatabase db;

  /// Future completing when the SDB is ready.
  late final Future<void> ready = () async {
    db = await factory.openDatabase(
      name ?? objectStorageSdbName,
      options: SdbOpenDatabaseOptions(
        version: 1,
        schema: SdbDatabaseSchema(stores: [sdbObjectStore.schema()]),
      ),
    );
    initSdbObjectBuilders();
  }();

  /// Create a new [ObjectStorageSdb] instance.
  ObjectStorageSdb({
    required this.factory,
    required this.fileSystem,
    this.name,
    this.rootPath = '/',
  });

  /// Create a new in-memory [ObjectStorageSdb] instance.
  ObjectStorageSdb.inMemory()
    : factory = sdbFactoryMemory,
      fileSystem = newFileSystemMemory(),
      rootPath = '/root',
      name = 'in_memory';

  /// Close the database.
  Future<void> close() async {
    await ready;
    await db.close();
  }

  String _toFsPath(String posixPath) {
    var parts = p.posix.split(posixPath);
    var filteredParts = parts
        .where((part) => part.isNotEmpty && part != '.' && part != '..')
        .toList();
    return fileSystem.path.joinAll([rootPath, ...filteredParts]);
  }

  /// Checks if the local database record exists and the file is present in the filesystem.
  Future<bool> hasLocalContent(String path) async {
    await ready;
    var record = await sdbObjectStore.record(path).get(db);
    if (record == null) return false;
    var file = fileSystem.file(_toFsPath(path));
    return await file.exists();
  }

  /// Writes directly to the SDB store and filesystem (used by cached client).
  Future<void> cacheWrite(
    String path, {
    required String name,
    required int size,
    required String mimeType,
    Uint8List? data,
  }) async {
    await ready;
    var record = SdbObjectRecord()
      ..name.v = name
      ..path.v = path
      ..size.v = size
      ..mimeType.v = mimeType;
    await sdbObjectStore.record(path).put(db, record);

    if (data != null) {
      var fsPath = _toFsPath(path);
      var file = fileSystem.file(fsPath);
      var parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
      await file.writeAsBytes(data);
    }
  }

  @override
  Future<void> delete(String path) async {
    await ready;

    var record = await sdbObjectStore.record(path).get(db);
    if (record != null) {
      await sdbObjectStore.record(path).delete(db);
      var fsPath = _toFsPath(path);
      var file = fileSystem.file(fsPath);
      if (await file.exists()) {
        await file.delete();
      }
      return;
    }

    var prefix = path.endsWith('/') ? path : '$path/';
    var records = await sdbObjectStore.findRecords(
      db,
      options: SdbFindOptions(
        filter: SdbFilter.custom((record) {
          var pathValue = record[_sdbObjectModel.path.name] as String?;
          return pathValue != null && pathValue.startsWith(prefix);
        }),
      ),
    );

    for (var r in records) {
      var fsPath = _toFsPath(r.path.v!);
      var file = fileSystem.file(fsPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await sdbObjectStore.rawRef.delete(
      db,
      options: SdbFindOptions(
        filter: SdbFilter.custom((record) {
          var pathValue = record[_sdbObjectModel.path.name] as String?;
          return pathValue != null && pathValue.startsWith(prefix);
        }),
      ),
    );

    var fsPath = _toFsPath(path);
    var dir = fileSystem.directory(fsPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<Uint8List> download(String path) async {
    await ready;
    var record = await sdbObjectStore.record(path).get(db);
    if (record == null) {
      throw Exception('File not found: $path');
    }
    var fsPath = _toFsPath(path);
    var file = fileSystem.file(fsPath);
    if (!await file.exists()) {
      throw Exception('File content not found: $path');
    }
    return Uint8List.fromList(await file.readAsBytes());
  }

  @override
  Future<ObjectStorageMeta> getItem(String path) async {
    await ready;

    var record = await sdbObjectStore.record(path).get(db);
    if (record != null) {
      return _SdbMeta(
        name: record.name.v!,
        path: record.path.v!,
        size: record.size.v,
        mimeType: record.mimeType.v,
        isLocation: false,
      );
    }

    var prefix = path.endsWith('/') ? path : '$path/';
    var count = await sdbObjectStore.count(
      db,
      options: SdbFindOptions(
        filter: SdbFilter.custom((record) {
          var pathValue = record[_sdbObjectModel.path.name] as String?;
          return pathValue != null && pathValue.startsWith(prefix);
        }),
      ),
    );

    if (count > 0) {
      var name = path
          .split('/')
          .lastWhere((part) => part.isNotEmpty, orElse: () => '');
      return _SdbMeta(
        name: name,
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
    await ready;

    var prefix = path.isEmpty ? '' : (path.endsWith('/') ? path : '$path/');
    var records = await sdbObjectStore.findRecords(
      db,
      options: SdbFindOptions(
        filter: SdbFilter.custom((record) {
          var pathValue = record[_sdbObjectModel.path.name] as String?;
          return pathValue != null && pathValue.startsWith(prefix);
        }),
      ),
    );

    var items = <ObjectStorageMeta>[];
    var seenLocations = <String>{};

    for (var file in records) {
      var filePath = file.path.v!;
      var relativePath = filePath.substring(prefix.length);
      if (relativePath.isEmpty) continue;

      var parts = relativePath.split('/');
      if (parts.length > 1) {
        var dirName = parts.first;
        var dirPosixPath = prefix.isEmpty ? dirName : '$prefix$dirName';

        if (seenLocations.add(dirPosixPath)) {
          items.add(
            _SdbMeta(
              name: dirName,
              path: dirPosixPath,
              size: null,
              mimeType: null,
              isLocation: true,
            ),
          );
        }
      } else {
        items.add(
          _SdbMeta(
            name: file.name.v!,
            path: filePath,
            size: file.size.v,
            mimeType: file.mimeType.v,
            isLocation: false,
          ),
        );
      }
    }

    items.sort((a, b) => a.name.compareTo(b.name));

    return _SdbListResponse(items: items);
  }

  @override
  Future<ObjectStorageMeta> upload(
    String path, {
    required String name,
    required Uint8List data,
    required String mimeType,
  }) async {
    await ready;

    var filePosixPath = path.isEmpty
        ? name
        : (path.endsWith('/') ? '$path$name' : '$path/$name');

    // 1. Put metadata
    var record = SdbObjectRecord()
      ..name.v = name
      ..path.v = filePosixPath
      ..size.v = data.length
      ..mimeType.v = mimeType;

    await sdbObjectStore.record(filePosixPath).put(db, record);

    // 2. Put content in FileSystem
    var fsPath = _toFsPath(filePosixPath);
    var file = fileSystem.file(fsPath);
    var parentDir = file.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }
    await file.writeAsBytes(data);

    return _SdbMeta(
      name: name,
      path: filePosixPath,
      size: data.length,
      mimeType: mimeType,
      isLocation: false,
    );
  }
}
