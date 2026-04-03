import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:tekartik_firebase_storage/storage.dart';

import 'object_storage.dart';

/// Firebase implementation of [ObjectStorageMeta].
class _FirebaseMeta implements ObjectStorageMeta {
  @override
  String get name => url.basename(path);
  @override
  final String path;
  final FileMetadata? _meta;
  @override
  final bool isLocation;

  _FirebaseMeta({
    required this.path,
    FileMetadata? meta,
    required this.isLocation,
  }) : _meta = meta;

  @override
  int? get size => _meta?.size;

  @override
  String? get mimeType => _meta?.contentType;
}

/// Firebase implementation of [ObjectStorageListResponse].
class _FirebaseListResponse implements ObjectStorageListResponse {
  @override
  final List<ObjectStorageMeta> items;
  @override
  final String? nextPageToken;

  _FirebaseListResponse({required this.items, this.nextPageToken});
}

/// Firebase Storage implementation of [ObjectStorage].
class ObjectStorageFirebase extends ObjectStorage {
  /// The firebase storage service.
  final FirebaseStorage storage;

  /// The bucket used for operations.
  final Bucket bucket;

  /// Create a new [ObjectStorageFirebase] instance.
  ObjectStorageFirebase({required this.storage, Bucket? bucket})
    : bucket = bucket ?? storage.bucket();

  _FirebaseMeta _fileMetadataToStorageMeta(String path, FileMetadata meta) {
    return _FirebaseMeta(path: path, meta: meta, isLocation: false);
  }

  @override
  Future<ObjectStorageListResponse> list(
    String path, {
    String? pageToken,
    int? maxResults,
  }) async {
    var prefix = path.isEmpty ? null : (path.endsWith('/') ? path : '$path/');
    var response = await bucket.getFiles(
      GetFilesOptions(
        prefix: prefix,
        autoPaginate: false,
        pageToken: pageToken,
        maxResults: maxResults,
      ),
    );

    var items = response.files
        .map((f) => _fileMetadataToStorageMeta(f.name, f.metadata!))
        .toList();

    return _FirebaseListResponse(
      items: items,
      nextPageToken: response.nextQuery?.pageToken,
    );
  }

  @override
  Future<ObjectStorageMeta> getItem(String path) async {
    var file = bucket.file(path);
    var meta = await file.getMetadata();
    return _fileMetadataToStorageMeta(path, meta);
  }

  @override
  Future<ObjectStorageMeta> upload(
    String path, {
    required String name,
    required Uint8List data,
    required String mimeType,
  }) async {
    var filePath = url.join(path, name);
    var file = bucket.file(filePath);
    await file.upload(
      data,
      options: StorageUploadFileOptions(contentType: mimeType),
    );
    var meta = await file.getMetadata();
    return _fileMetadataToStorageMeta(filePath, meta);
  }

  @override
  Future<Uint8List> download(String path) {
    return bucket.file(path).readAsBytes();
  }

  @override
  Future<void> delete(String path) {
    return bucket.file(path).delete();
  }
}
