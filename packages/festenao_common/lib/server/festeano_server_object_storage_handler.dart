import 'package:festenao_common/data/object_storage.dart';
import 'package:tekartik_app_media/mime_type.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tkcms_common/tkcms_server.dart';

import '../src/data/storage/gdrive_api_service.dart';

/// Options for Object storage handler.
class FestenaoObjectStorageHandlerOptions {
  /// The delegate
  final ObjectStorage objectStorage;

  /// Creates a new [FestenaoObjectStorageHandlerOptions] with [objectStorage] delegate.
  const FestenaoObjectStorageHandlerOptions({required this.objectStorage});
}

/// Handler for Festenao object storage commands.
class FestenaoObjectStorageHandler {
  /// Options for the handler.
  final FestenaoObjectStorageHandlerOptions options;

  ObjectStorage get _objectStorage => options.objectStorage;

  /// Creates a new [FestenaoObjectStorageHandler] with the given [options].
  FestenaoObjectStorageHandler({required this.options});

  /// Handles the command if it's an object storage command, otherwise returns null.
  Future<ApiResult?> onCommandOrNull(ApiRequest apiRequest) async {
    var command = apiRequest.command.v!;
    switch (command) {
      case GdriveApiService.listCommand:
        return await onListCommand(apiRequest);
      case GdriveApiService.getItemCommand:
        return await onGetItemCommand(apiRequest);
      case GdriveApiService.uploadCommand:
        return await onUploadCommand(apiRequest);
      case GdriveApiService.downloadCommand:
        return await onDownloadCommand(apiRequest);
      case GdriveApiService.deleteCommand:
        return await onDeleteCommand(apiRequest);
    }

    return null;
  }

  GdriveApiItem _toApiItem(ObjectStorageMeta meta) {
    return GdriveApiItem()
      ..name.v = meta.name
      ..path.v = meta.path
      ..size.v = meta.size
      ..mimeType.v = meta.mimeType
      ..isLocation.v = meta.isLocation;
  }

  /// Handles the list command.
  Future<ApiResult> onListCommand(ApiRequest apiRequest) async {
    var query = apiRequest.query<GdriveApiListQuery>();
    var response = await _objectStorage.list(
      query.path.v!,
      pageToken: query.pageToken.v,
      maxResults: query.maxResults.v,
    );
    return GdriveApiListResult()
      ..items.v = response.items.map(_toApiItem).toList()
      ..nextPageToken.v = response.nextPageToken;
  }

  /// Handles the get item command.
  Future<ApiResult> onGetItemCommand(ApiRequest apiRequest) async {
    var query = apiRequest.query<GdriveApiGetItemQuery>();
    var meta = await _objectStorage.getItem(query.path.v!);
    return GdriveApiGetItemResult()..item.v = _toApiItem(meta);
  }

  /// Handles the upload command.
  Future<ApiResult> onUploadCommand(ApiRequest apiRequest) async {
    var query = apiRequest.query<GdriveApiUploadQuery>();
    var data = Uint8List.fromList(base64Decode(query.content.v!));
    var mimeType = query.mimeType.v;
    var meta = await _objectStorage.upload(
      query.path.v!,
      name: query.name.v!,
      data: data,
      mimeType: mimeType ?? mimeTypeOctetStream,
    );
    return GdriveApiUploadResult()..item.v = _toApiItem(meta);
  }

  /// Handles the download command.
  Future<ApiResult> onDownloadCommand(ApiRequest apiRequest) async {
    var query = apiRequest.query<GdriveApiDownloadQuery>();
    var data = await _objectStorage.download(query.path.v!);
    return GdriveApiDownloadResult()..content.v = base64Encode(data);
  }

  /// Handles the delete command.
  Future<ApiResult> onDeleteCommand(ApiRequest apiRequest) async {
    var query = apiRequest.query<GdriveApiDeleteQuery>();
    await _objectStorage.delete(query.path.v!);
    return GdriveApiDeleteResult();
  }
}
