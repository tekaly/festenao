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

/// True when [error] says the object does not exist (rather than a network
/// or a permission error), from what the stores answer: a firebase storage
/// `StorageException(StorageExceptionType.notFound)`, a google drive 404
/// (`File not found: ...`), a file system or sdb store `... not found: ...`.
bool _isNotFoundError(Object error) {
  var text = '$error'.toLowerCase();
  return text.contains('not found') || text.contains('notfound');
}

/// A cached implementation of [ObjectStorage] that delegates to another
/// [ObjectStorage] and caches results in an [ObjectStorageSdb] local database.
///
/// What is cached is served from the cache (and refreshed in the background),
/// also when the delegate cannot be reached: an entry leaves the cache only
/// when the delegate says the object no longer exists.
class ObjectStorageSdbCached extends ObjectStorage {
  /// The source of truth storage delegate.
  final ObjectStorage delegate;

  /// The SDB cache storage.
  final ObjectStorageSdb cache;

  /// Create a new [ObjectStorageSdbCached] instance.
  ObjectStorageSdbCached({required this.delegate, required this.cache});

  /// Marker file of a cached directory listing.
  static const _listedMarkerName = '.directory_cached';

  /// Marker file of a directory known from a parent listing (the cache only
  /// derives its directories from the files below them).
  static const _locationMarkerName = '.directory_location';

  /// The most pages read to cache a whole listing.
  static const _maxListPages = 1000;

  String _getMarkerPath(String path) => _markerPath(path, _listedMarkerName);

  String _markerPath(String path, String markerName) {
    if (path.isEmpty) return markerName;
    return path.endsWith('/') ? '$path$markerName' : '$path/$markerName';
  }

  /// True for the cache own marker files.
  bool _isMarker(ObjectStorageMeta item) =>
      item.name.endsWith(_listedMarkerName) ||
      item.name.endsWith(_locationMarkerName);

  /// Runs [action] in the background, its errors ignored.
  void _background(Future<void> Function() action) {
    unawaited(() async {
      try {
        await action();
      } catch (_) {}
    }());
  }

  /// Removes [path] from the cache when [error] says it no longer exists.
  Future<void> _onRefreshError(String path, Object error) async {
    if (_isNotFoundError(error)) {
      await cache.delete(path);
    }
  }

  @override
  Future<void> delete(String path) async {
    await delegate.delete(path);
    await cache.delete(path);
  }

  @override
  Future<Uint8List> download(String path) async {
    if (await cache.hasLocalContent(path)) {
      _background(() => _refreshDownload(path));
      return await cache.download(path);
    } else {
      return await _refreshDownload(path);
    }
  }

  @override
  Future<Uint8List> downloadPart(String path, int start, int size) async {
    if (await cache.hasLocalContent(path)) {
      _background(() => _refreshDownload(path));
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
      _background(() => _refreshDownload(path));
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
        modified: meta.modified,
        data: data,
      );
      return data;
    } catch (e, st) {
      await _onRefreshError(path, e);
      Error.throwWithStackTrace(e, st);
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
      _background(() => _refreshItem(path));
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
          modified: item.modified,
        );
      }
      return item;
    } catch (e, st) {
      // Gone from the delegate (a folder with what was below it): gone from
      // the cache. Any other error (offline) keeps the cache as it is.
      await _onRefreshError(path, e);
      Error.throwWithStackTrace(e, st);
    }
  }

  /// A listing is served from the cache only once a whole listing of [path]
  /// was cached (and only for a first page, [pageToken] null): a page of the
  /// delegate never prunes nor marks the cached listing.
  @override
  Future<ObjectStorageListResponse> list(
    String path, {
    String? pageToken,
    int? maxResults,
  }) async {
    if (pageToken == null && await _isListed(path)) {
      var cachedResponse = await cache.list(path);
      var filteredItems = cachedResponse.items
          .where((item) => !_isMarker(item))
          .toList();
      _background(() => _refreshFullList(path));
      return _CachedListResponse(items: filteredItems);
    }
    return await _refreshList(
      path,
      pageToken: pageToken,
      maxResults: maxResults,
    );
  }

  Future<bool> _isListed(String path) async {
    try {
      await cache.getItem(_getMarkerPath(path));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// One page of the delegate, its items cached. A first page that is the
  /// whole listing also sets the cached listing; a first page with more
  /// pages after it caches the whole listing in the background.
  Future<ObjectStorageListResponse> _refreshList(
    String path, {
    String? pageToken,
    int? maxResults,
  }) async {
    var delegateResponse = await delegate.list(
      path,
      pageToken: pageToken,
      maxResults: maxResults,
    );
    await _cacheItems(delegateResponse.items);
    if (pageToken == null) {
      if (delegateResponse.nextPageToken == null) {
        await _setListed(path, delegateResponse.items);
      } else {
        _background(() => _refreshFullList(path));
      }
    }
    return delegateResponse;
  }

  /// Reads every page of the listing of [path] and sets the cached listing.
  ///
  /// A listing of more than [_maxListPages] pages leaves the cache as it is.
  Future<void> _refreshFullList(String path) async {
    var items = <ObjectStorageMeta>[];
    String? pageToken;
    var pages = 0;
    do {
      if (pages++ >= _maxListPages) {
        return;
      }
      var response = await delegate.list(path, pageToken: pageToken);
      items.addAll(response.items);
      pageToken = response.nextPageToken;
    } while (pageToken != null);
    await _cacheItems(items);
    await _setListed(path, items);
  }

  Future<void> _cacheItems(List<ObjectStorageMeta> items) async {
    for (var item in items) {
      if (!item.isLocation) {
        await cache.cacheWrite(
          item.path,
          name: item.name,
          size: item.size ?? 0,
          mimeType: item.mimeType ?? 'application/octet-stream',
          modified: item.modified,
        );
      } else {
        // So that the cached listing shows the sub directory.
        await cache.cacheWrite(
          _markerPath(item.path, _locationMarkerName),
          name: _locationMarkerName,
          size: 0,
          mimeType: 'application/octet-stream',
        );
      }
    }
  }

  /// [items] being the whole listing of [path]: the cached entries that are
  /// not in it are removed, the listing is marked as cached.
  Future<void> _setListed(String path, List<ObjectStorageMeta> items) async {
    var currentCachedResponse = await cache.list(path);
    var currentCachedPaths = currentCachedResponse.items
        .where((item) => !_isMarker(item))
        .map((item) => item.path)
        .toSet();
    var newPaths = items.map((item) => item.path).toSet();
    for (var oldPath in currentCachedPaths) {
      if (!newPaths.contains(oldPath)) {
        await cache.delete(oldPath);
      }
    }

    await cache.upload(
      path,
      name: _listedMarkerName,
      data: Uint8List(0),
      mimeType: 'application/octet-stream',
    );
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
