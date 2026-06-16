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

  /// Download a part of the file content (start, size).
  Future<Uint8List> downloadPart(String path, int start, int size);

  /// Download a file (or part of it) as a stream of chunks.
  Stream<Uint8List> downloadStream(
    String path, {
    int? start,
    int? size,
    int? chunkSize,
  }) {
    return objectStorageDownloadStreamHelper(
      this,
      path,
      start: start,
      size: size,
      chunkSize: chunkSize,
    );
  }

  /// Delete an object.
  Future<void> delete(String path);
}

/// Helper to implement downloadStream using downloadPart.
Stream<Uint8List> objectStorageDownloadStreamHelper(
  ObjectStorage storage,
  String path, {
  int? start,
  int? size,
  int? chunkSize,
}) async* {
  var currentStart = start ?? 0;
  var remaining = size;
  var chunkLimit = chunkSize ?? 1024 * 1024; // Default to 1MB chunks

  while (remaining == null || remaining > 0) {
    var nextSize = chunkLimit;
    if (remaining != null && nextSize > remaining) {
      nextSize = remaining;
    }

    Uint8List chunk;
    try {
      chunk = await storage.downloadPart(path, currentStart, nextSize);
    } catch (e) {
      if (remaining == null && currentStart > 0) {
        break;
      }
      rethrow;
    }

    if (chunk.isEmpty) {
      break;
    }

    yield chunk;

    currentStart += chunk.length;
    if (remaining != null) {
      remaining -= chunk.length;
    }

    if (chunk.length < nextSize) {
      break;
    }
  }
}
