import 'dart:typed_data';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';

import 'object_storage.dart';

/// SDB record for stored objects.
class SdbObjectRecord extends ScvStringRecordBase {
  /// Name of the object.
  final name = CvField<String>('name');

  /// POSIX path of the object.
  final path = CvField<String>('path');

  /// Size in bytes.
  final size = CvField<int>('size');

  /// MIME type.
  final mimeType = CvField<String>('mimeType');

  /// Content data.
  final data = CvField<Uint8List>('data');

  @override
  CvFields get fields => [name, path, size, mimeType, data];
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

/// SDB implementation of [ObjectStorage].
class ObjectStorageSdb extends ObjectStorage {
  /// The database factory.
  final SdbFactory factory;

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
  ObjectStorageSdb({required this.factory, this.name});

  /// Create a new in-memory [ObjectStorageSdb] instance.
  ObjectStorageSdb.inMemory()
    : this(factory: sdbFactoryMemory, name: 'in_memory');

  /// Close the database.
  Future<void> close() async {
    await ready;
    await db.close();
  }

  @override
  Future<void> delete(String path) async {
    await ready;

    var exists = await sdbObjectStore.record(path).get(db) != null;
    if (exists) {
      await sdbObjectStore.record(path).delete(db);
      return;
    }

    var prefix = path.endsWith('/') ? path : '$path/';
    await sdbObjectStore.rawRef.delete(
      db,
      options: SdbFindOptions(
        filter: SdbFilter.custom((record) {
          var pathValue = record[_sdbObjectModel.path.name] as String?;
          return pathValue != null && pathValue.startsWith(prefix);
        }),
      ),
    );
  }

  @override
  Future<Uint8List> download(String path) async {
    await ready;
    var record = await sdbObjectStore.record(path).get(db);
    if (record == null) {
      throw Exception('File not found: $path');
    }
    return record.data.v!;
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

    var record = SdbObjectRecord()
      ..name.v = name
      ..path.v = filePosixPath
      ..size.v = data.length
      ..mimeType.v = mimeType
      ..data.v = data;

    await sdbObjectStore.record(filePosixPath).put(db, record);

    return _SdbMeta(
      name: name,
      path: filePosixPath,
      size: data.length,
      mimeType: mimeType,
      isLocation: false,
    );
  }
}
