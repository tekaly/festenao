import 'package:festenao_common/festenao_api.dart';

/// GDrive API location.
class GdriveApiItem extends CvModelBase {
  /// Name.
  late final name = CvField<String>('name');

  /// Path.
  late final path = CvField<String>('path');

  /// Size.
  late final size = CvField<int>('size');

  /// Mime type.
  late final mimeType = CvField<String>('mimeType');

  /// True if it is a folder.
  late final isLocation = CvField<bool>('isLocation');

  @override
  late final CvFields fields = [name, path, size, mimeType, isLocation];
}

/// GDrive delete query.
class GdriveApiDeleteQuery extends ApiQuery {
  /// Path to delete.
  late final path = CvField<String>('path');

  @override
  late final CvFields fields = [path];
}

/// GDrive delete result.
class GdriveApiDeleteResult extends ApiResult {}

/// GDrive list query.
class GdriveApiListQuery extends ApiQuery {
  /// Path to list.
  late final path = CvField<String>('path');

  /// Page token.
  late final pageToken = CvField<String>('pageToken');

  /// Max results.
  late final maxResults = CvField<int>('maxResults');

  @override
  late final CvFields fields = [path, pageToken, maxResults];
}

/// GDrive list result.
class GdriveApiListResult extends ApiResult {
  /// Items.
  late final items = CvModelListField<GdriveApiItem>('items');

  /// Next page token.
  late final nextPageToken = CvField<String>('nextPageToken');

  @override
  late final CvFields fields = [items, nextPageToken];
}

/// GDrive get item query.
class GdriveApiGetItemQuery extends ApiQuery {
  /// Path.
  late final path = CvField<String>('path');

  @override
  late final CvFields fields = [path];
}

/// GDrive get item result.
class GdriveApiGetItemResult extends ApiResult {
  /// Item.
  late final item = CvModelField<GdriveApiItem>('item');

  @override
  late final CvFields fields = [item];
}

/// GDrive upload query.
class GdriveApiUploadQuery extends ApiQuery {
  /// Name.
  late final name = CvField<String>('name');

  /// Path.
  late final path = CvField<String>('path');

  /// Content base64.
  late final content = CvField<String>('content');

  /// Mime type
  late final mimeType = CvField<String>('mimeType');

  @override
  late final CvFields fields = [name, path, content, mimeType];
}

/// GDrive upload result.
class GdriveApiUploadResult extends ApiResult {
  /// Item.
  late final item = CvModelField<GdriveApiItem>('item');

  @override
  late final CvFields fields = [item];
}

/// GDrive download query.
class GdriveApiDownloadQuery extends ApiQuery {
  /// Path.
  late final path = CvField<String>('path');

  @override
  late final CvFields fields = [path];
}

/// GDrive download result.
class GdriveApiDownloadResult extends ApiResult {
  /// Content base64.
  late final content = CvField<String>('content');

  @override
  late final CvFields fields = [content];
}

bool _gdriveApiBuildersInitialized = false;

/// Init GDrive API builders.
void initGdriveApiBuilders() {
  if (!_gdriveApiBuildersInitialized) {
    _gdriveApiBuildersInitialized = true;
    initTkCmsApiBuilders();
    cvAddConstructors([
      GdriveApiItem.new,
      GdriveApiDeleteQuery.new,
      GdriveApiDeleteResult.new,
      GdriveApiListQuery.new,
      GdriveApiListResult.new,
      GdriveApiGetItemQuery.new,
      GdriveApiGetItemResult.new,
      GdriveApiUploadQuery.new,
      GdriveApiUploadResult.new,
      GdriveApiDownloadQuery.new,
      GdriveApiDownloadResult.new,
    ]);
  }
}

/// GDrive API service.
class GdriveApiService extends FestenaoApiService {
  /// List command.
  static const listCommand = 'gdrive/list';

  /// Get item command.
  static const getItemCommand = 'gdrive/getItem';

  /// Upload command.
  static const uploadCommand = 'gdrive/upload';

  /// Download command.
  static const downloadCommand = 'gdrive/download';

  /// Delete command.
  static const deleteCommand = 'gdrive/delete';

  /// Constructor.
  GdriveApiService({super.httpClientFactory, required super.httpsApiUri}) {
    initGdriveApiBuilders();
  }

  /// List files.
  Future<GdriveApiListResult> list(GdriveApiListQuery query) =>
      getApiResult<GdriveApiListResult>(query.request(listCommand));

  /// Get item.
  Future<GdriveApiGetItemResult> getItem(GdriveApiGetItemQuery query) =>
      getApiResult<GdriveApiGetItemResult>(query.request(getItemCommand));

  /// Upload file.
  Future<GdriveApiUploadResult> upload(GdriveApiUploadQuery query) =>
      getApiResult<GdriveApiUploadResult>(query.request(uploadCommand));

  /// Download file.
  Future<GdriveApiDownloadResult> download(GdriveApiDownloadQuery query) =>
      getApiResult<GdriveApiDownloadResult>(query.request(downloadCommand));

  /// Delete file.
  Future<GdriveApiDeleteResult> delete(GdriveApiDeleteQuery query) =>
      getApiResult<GdriveApiDeleteResult>(query.request(deleteCommand));
}
