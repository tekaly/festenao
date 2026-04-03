import 'dart:typed_data';

/// Abstract storage location.
abstract class ObjectStorageLocation {
  /// The path of the location.
  String get path;
}

/// Abstract storage object metadata.
abstract class ObjectStorageMeta {
  /// The name of the object.
  String get name;

  /// The path of the object.
  String get path;

  /// The size of the object in bytes.
  int? get size;

  /// The mime type of the object.
  String? get mimeType;

  /// True if this represents a directory/location rather than a file.
  bool get isLocation;
}

/// Result of a listing operation.
abstract class ObjectStorageListResponse {
  /// List of objects (files and locations).
  List<ObjectStorageMeta> get items;

  /// Token for the next page if truncated.
  String? get nextPageToken;
}

/// Abstract storage API for object operations.
///
/// Can be implemented for Firebase Storage, S3, Google Drive, or local storage.
abstract class ObjectStorage {
  /// List objects in a given location (non-recursive).
  Future<ObjectStorageListResponse> list(
    String path, {
    String? pageToken,
    int? maxResults,
  });

  /// Get metadata for a single object.
  Future<ObjectStorageMeta> getItem(String path);

  /// Upload data to a path.
  Future<ObjectStorageMeta> upload(
    String path, {
    required String name,
    required Uint8List data,
    required String mimeType,
  });

  /// Download data from a path.
  Future<Uint8List> download(String path);

  /// Delete an object.
  Future<void> delete(String path);
}
