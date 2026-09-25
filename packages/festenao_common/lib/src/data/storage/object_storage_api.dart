import 'dart:convert';

import 'package:festenao_common/data/object_storage.dart';
import 'package:festenao_common/festenao_http.dart';
import 'package:festenao_common/src/data/storage/gdrive_api_service.dart';
import 'package:tekartik_firebase_functions_call_rest/functions_call_rest.dart'
    show FirebaseFunctionsCallable;

/// Client implementation of [ObjectStorageMeta].
class _ObjectStorageApiMeta implements ObjectStorageMeta {
  final GdriveApiItem _item;

  _ObjectStorageApiMeta(this._item);

  /// Name
  @override
  String get name => _item.name.v!;
  @override
  bool get isLocation => _item.isLocation.v ?? false;

  @override
  String? get mimeType => _item.mimeType.v;

  @override
  String get path => _item.path.v!;

  @override
  int? get size => _item.size.v;
}

/// Client implementation of [ObjectStorageListResponse].
class _ObjectStorageApiListResponse implements ObjectStorageListResponse {
  final GdriveApiListResult _result;

  _ObjectStorageApiListResponse(this._result);

  @override
  List<ObjectStorageMeta> get items =>
      _result.items.v?.map((item) => _ObjectStorageApiMeta(item)).toList() ??
      <ObjectStorageMeta>[];

  @override
  String? get nextPageToken => _result.nextPageToken.v;
}

/// [ObjectStorage] implementation that communicates with a remote API.
class ObjectStorageApiClient extends ObjectStorage {
  late final GdriveApiService _api;
  final HttpClientFactory? _httpClientFactory;

  /// Constructor.
  ///
  /// [httpClientFactory] is what the api is called with, and what a download
  /// url is fetched with as well: the api hands out urls of its own (a
  /// server reachable through the memory client only, in a test, hands out
  /// urls only that client reaches). The platform one when null.
  ///
  /// [callableApi] (the callable function of the same server) sends the
  /// commands with the signed in user, the https endpoint without: a server
  /// requiring a user for some commands needs it.
  ObjectStorageApiClient({
    HttpClientFactory? httpClientFactory,
    required Uri httpsUri,
    FirebaseFunctionsCallable? callableApi,
  }) : _httpClientFactory = httpClientFactory {
    _api = GdriveApiService(
      httpsApiUri: httpsUri,
      httpClientFactory: httpClientFactory,
      callableApi: callableApi,
    );
  }

  @override
  HttpClientFactory get downloadHttpClientFactory =>
      _httpClientFactory ?? super.downloadHttpClientFactory;

  @override
  Future<void> delete(String path) async {
    await _api.delete(GdriveApiDeleteQuery()..path.v = path);
  }

  @override
  Future<Uint8List> download(String path) async {
    var result = await _api.download(GdriveApiDownloadQuery()..path.v = path);
    return Uint8List.fromList(base64Decode(result.content.v!));
  }

  @override
  Future<Uint8List> downloadPart(String path, int start, int size) async {
    var result = await _api.download(
      GdriveApiDownloadQuery()
        ..path.v = path
        ..start.v = start
        ..size.v = size,
    );
    return Uint8List.fromList(base64Decode(result.content.v!));
  }

  @override
  Future<String?> getDownloadUrl(String path) async {
    var result = await _api.getDownloadUrl(
      GdriveApiGetDownloadUrlQuery()..path.v = path,
    );
    return result.url.v;
  }

  @override
  Future<ObjectStorageMeta> getItem(String path) async {
    var result = await _api.getItem(GdriveApiGetItemQuery()..path.v = path);
    return _ObjectStorageApiMeta(result.item.v!);
  }

  @override
  Future<ObjectStorageListResponse> list(
    String path, {
    String? pageToken,
    int? maxResults,
  }) async {
    var result = await _api.list(
      GdriveApiListQuery()
        ..path.v = path
        ..pageToken.v = pageToken
        ..maxResults.v = maxResults,
    );
    return _ObjectStorageApiListResponse(result);
  }

  @override
  Future<ObjectStorageMeta> upload(
    String path, {
    required String name,
    required Uint8List data,
    required String mimeType,
  }) async {
    var result = await _api.upload(
      GdriveApiUploadQuery()
        ..mimeType.v = mimeType
        ..name.v = name
        ..path.v = path
        ..content.v = base64Encode(data),
    );
    return _ObjectStorageApiMeta(result.item.v!);
  }
}
