import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:tekartik_app_http/app_http.dart';

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
  ///
  /// Streamed from the [getDownloadUrl] of the object when
  /// [supportDownloadUrl], through [downloadPart] otherwise (see
  /// [objectStorageDownloadStreamHelper]).
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

  /// A url to download the object directly, null when the storage has none.
  ///
  /// Whether the url works for a given client is the storage's business: for
  /// google drive it is the file `webContentLink`, which only serves whoever
  /// may read the file (anyone, for a public file).
  Future<String?> getDownloadUrl(String path) async => null;

  /// Internal: whether [getDownloadUrl] returns a url the content can be
  /// fetched from directly (google drive).
  ///
  /// [downloadStream] then streams from that url — one http request, a
  /// `Range` one for a part — instead of going through [downloadPart], and
  /// falls back to [downloadPart] when the url is null.
  bool get supportDownloadUrl => false;

  /// Internal: the http client factory [downloadStream] fetches a download url
  /// with, the platform one by default (a mock in tests).
  HttpClientFactory get downloadHttpClientFactory => httpClientFactory;
}

/// Helper to implement [ObjectStorage.downloadStream].
///
/// Streams from the download url of the object when the storage
/// [ObjectStorage.supportDownloadUrl] (and has one for [path]), see
/// [objectStorageDownloadUrlStream]; through [ObjectStorage.downloadPart]
/// otherwise, [chunkSize] (1MB by default) bytes at a time.
Stream<Uint8List> objectStorageDownloadStreamHelper(
  ObjectStorage storage,
  String path, {
  int? start,
  int? size,
  int? chunkSize,
}) async* {
  if (storage.supportDownloadUrl) {
    var url = await storage.getDownloadUrl(path);
    if (url != null) {
      yield* objectStorageDownloadUrlStream(
        url,
        httpClientFactory: storage.downloadHttpClientFactory,
        start: start,
        size: size,
        chunkSize: chunkSize,
      );
      return;
    }
  }
  var currentStart = start ?? 0;
  var remaining = size;
  var chunkLimit = chunkSize ?? objectStorageDefaultChunkSize;

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

/// The chunk size of the download streams when none is asked (1MB).
const objectStorageDefaultChunkSize = 1024 * 1024;

/// Streams the content at [url], in chunks of at most [chunkSize] (1MB by
/// default).
///
/// One http request: a `Range` one when [start] or [size] is given. A server
/// that ignores the range (a 200 with the whole content) is handled, the
/// bytes outside the part are dropped. Any other non 2xx status throws.
Stream<Uint8List> objectStorageDownloadUrlStream(
  String url, {
  required HttpClientFactory httpClientFactory,
  int? start,
  int? size,
  int? chunkSize,
}) async* {
  var chunkLimit = chunkSize ?? objectStorageDefaultChunkSize;
  var rangeStart = start ?? 0;
  var partial = rangeStart > 0 || size != null;
  var client = httpClientFactory.newClient();
  try {
    var request = http.Request('GET', Uri.parse(url));
    if (partial) {
      var rangeEnd = size == null ? '' : '${rangeStart + size - 1}';
      request.headers['Range'] = 'bytes=$rangeStart-$rangeEnd';
    }
    var response = await client.send(request);
    var statusCode = response.statusCode;
    if (statusCode < 200 || statusCode >= 300) {
      var body = await response.stream.bytesToString();
      throw Exception(
        'Download of $url failed (HTTP $statusCode'
        '${body.isEmpty ? '' : ': $body'})',
      );
    }
    // The range was ignored (200, the whole content): drop the bytes before
    // the part. A 206 starts at the part.
    var toSkip = partial && statusCode != 206 ? rangeStart : 0;
    var remaining = size;
    var pending = BytesBuilder(copy: false);
    await for (var data in response.stream) {
      var bytes = data is Uint8List ? data : Uint8List.fromList(data);
      if (toSkip > 0) {
        if (bytes.length <= toSkip) {
          toSkip -= bytes.length;
          continue;
        }
        bytes = Uint8List.sublistView(bytes, toSkip);
        toSkip = 0;
      }
      if (remaining != null) {
        if (bytes.length > remaining) {
          bytes = Uint8List.sublistView(bytes, 0, remaining);
        }
        remaining -= bytes.length;
      }
      pending.add(bytes);
      if (pending.length >= chunkLimit) {
        var all = pending.takeBytes();
        var offset = 0;
        while (all.length - offset >= chunkLimit) {
          yield Uint8List.sublistView(all, offset, offset + chunkLimit);
          offset += chunkLimit;
        }
        if (offset < all.length) {
          pending.add(Uint8List.sublistView(all, offset));
        }
      }
      if (remaining == 0) {
        break;
      }
    }
    if (pending.isNotEmpty) {
      yield pending.takeBytes();
    }
  } finally {
    client.close();
  }
}
