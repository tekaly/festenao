import 'dart:async' show unawaited;
import 'dart:typed_data';
import 'object_storage.dart';
import 'object_storage_sdb.dart';

class _CachedListResponse implements ObjectStorageListResponse {
  @override
  final List<ObjectStorageMeta> items;

  @override
  final String? nextPageToken;

  _CachedListResponse({required this.items}) : nextPageToken = null;
}

/// A cached implementation of [ObjectStorage] that delegates to another
/// [ObjectStorage] and caches results in an [ObjectStorageSdb] local database.
class ObjectStorageSdbCached extends ObjectStorage {
  /// The source of truth storage delegate.
  final ObjectStorage delegate;

  /// The SDB cache storage.
  final ObjectStorageSdb cache;

  /// Create a new [ObjectStorageSdbCached] instance.
  ObjectStorageSdbCached({required this.delegate, required this.cache});

  String _getMarkerPath(String path) {
    if (path.isEmpty) return '.directory_cached';
    return path.endsWith('/')
        ? '$path.directory_cached'
        : '$path/.directory_cached';
  }

  @override
  Future<void> delete(String path) async {
    await delegate.delete(path);
    await cache.delete(path);
  }

  @override
  Future<Uint8List> download(String path) async {
    if (await cache.hasLocalContent(path)) {
      unawaited(() async {
        try {
          await _refreshDownload(path);
        } catch (_) {}
      }());
      return await cache.download(path);
    } else {
      return await _refreshDownload(path);
    }
  }

  @override
  Future<Uint8List> downloadPart(String path, int start, int size) async {
    if (await cache.hasLocalContent(path)) {
      unawaited(() async {
        try {
          await _refreshDownload(path);
        } catch (_) {}
      }());
      return await cache.downloadPart(path, start, size);
    } else {
      return await delegate.downloadPart(path, start, size);
    }
  }

  @override
  Stream<Uint8List> downloadStream(
    String path, {
    int? start,
    int? size,
    int? chunkSize,
  }) async* {
    if (await cache.hasLocalContent(path)) {
      unawaited(() async {
        try {
          await _refreshDownload(path);
        } catch (_) {}
      }());
      yield* cache.downloadStream(
        path,
        start: start,
        size: size,
        chunkSize: chunkSize,
      );
    } else {
      yield* delegate.downloadStream(
        path,
        start: start,
        size: size,
        chunkSize: chunkSize,
      );
    }
  }

  Future<Uint8List> _refreshDownload(String path) async {
    try {
      var data = await delegate.download(path);
      var meta = await delegate.getItem(path);

      await cache.cacheWrite(
        path,
        name: meta.name,
        size: data.length,
        mimeType: meta.mimeType ?? 'application/octet-stream',
        data: data,
      );
      return data;
    } catch (e) {
      await cache.delete(path);
      rethrow;
    }
  }

  @override
  Future<ObjectStorageMeta> getItem(String path) async {
    var isCached = false;
    ObjectStorageMeta? cachedMeta;
    try {
      cachedMeta = await cache.getItem(path);
      isCached = true;
    } catch (_) {}

    if (isCached && cachedMeta != null) {
      unawaited(() async {
        try {
          await _refreshItem(path);
        } catch (_) {}
      }());
      return cachedMeta;
    } else {
      return await _refreshItem(path);
    }
  }

  Future<ObjectStorageMeta> _refreshItem(String path) async {
    try {
      var item = await delegate.getItem(path);

      if (!item.isLocation) {
        await cache.cacheWrite(
          path,
          name: item.name,
          size: item.size ?? 0,
          mimeType: item.mimeType ?? 'application/octet-stream',
        );
      }
      return item;
    } catch (e) {
      await cache.delete(path);
      rethrow;
    }
  }

  @override
  Future<ObjectStorageListResponse> list(
    String path, {
    String? pageToken,
    int? maxResults,
  }) async {
    var marker = _getMarkerPath(path);

    var isCached = false;
    try {
      await cache.getItem(marker);
      isCached = true;
    } catch (_) {}

    if (isCached) {
      var cachedResponse = await cache.list(
        path,
        pageToken: pageToken,
        maxResults: maxResults,
      );
      var filteredItems = cachedResponse.items
          .where((item) => !item.name.endsWith('.directory_cached'))
          .toList();
      var response = _CachedListResponse(items: filteredItems);

      unawaited(() async {
        try {
          await _refreshList(
            path,
            pageToken: pageToken,
            maxResults: maxResults,
          );
        } catch (_) {}
      }());

      return response;
    } else {
      return await _refreshList(
        path,
        pageToken: pageToken,
        maxResults: maxResults,
      );
    }
  }

  Future<ObjectStorageListResponse> _refreshList(
    String path, {
    String? pageToken,
    int? maxResults,
  }) async {
    try {
      var delegateResponse = await delegate.list(
        path,
        pageToken: pageToken,
        maxResults: maxResults,
      );

      var currentCachedResponse = await cache.list(path);
      var currentCachedPaths = currentCachedResponse.items
          .where((item) => !item.name.endsWith('.directory_cached'))
          .map((item) => item.path)
          .toSet();

      var newPaths = <String>{};

      for (var item in delegateResponse.items) {
        newPaths.add(item.path);

        if (!item.isLocation) {
          await cache.cacheWrite(
            item.path,
            name: item.name,
            size: item.size ?? 0,
            mimeType: item.mimeType ?? 'application/octet-stream',
          );
        }
      }

      for (var oldPath in currentCachedPaths) {
        if (!newPaths.contains(oldPath)) {
          await cache.delete(oldPath);
        }
      }

      await cache.upload(
        path,
        name: '.directory_cached',
        data: Uint8List(0),
        mimeType: 'application/octet-stream',
      );

      return delegateResponse;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ObjectStorageMeta> upload(
    String path, {
    required String name,
    required Uint8List data,
    required String mimeType,
  }) async {
    var meta = await delegate.upload(
      path,
      name: name,
      data: data,
      mimeType: mimeType,
    );
    await cache.upload(path, name: name, data: data, mimeType: mimeType);
    return meta;
  }
}
