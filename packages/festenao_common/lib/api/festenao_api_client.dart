import 'package:path/path.dart';
import 'package:tekartik_app_http/app_http.dart';
import 'package:tkcms_common/tkcms_api.dart';

/// The AMP development function name.
var functionFestenaoAmpDev = 'ampdev';

/// The AMP production function name.
var functionFestenaoAmpProd = 'amp';

/// Service for interacting with AMP pages.
class FestenaoAmpService {
  /// HTTP client factory used for requests.
  final HttpClientFactory httpClientFactory;

  /// The base HTTPS AMP URI.
  final Uri httpsAmpUri;

  /// The base path for AMP requests.
  late final basePath = httpsAmpUri.path;

  /// The HTTP client instance.
  Client get client => _client;
  late final Client _client;

  /// Create a [FestenaoAmpService] with the given [httpsAmpUri] and optional [httpClientFactory].
  FestenaoAmpService({
    HttpClientFactory? httpClientFactory,
    required this.httpsAmpUri,
  }) : httpClientFactory = httpClientFactory ?? httpClientFactoryUniversal;

  /// Initialize the HTTP client.
  Future<void> initClient() async {
    _client = httpClientFactory.newClient();
  }

  /// Build a URI for the given [path] relative to the base AMP URI.
  Uri pathUri(String path) =>
      httpsAmpUri.replace(path: url.join(basePath, path));

  /// Read the content at the given [path] from the AMP service.
  Future<String> read(String path) {
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    return _client.read(pathUri(path));
  }

  /// Close the HTTP client.
  Future<void> close() async {
    try {
      _client.close();
    } catch (_) {}
    // keep local server on
  }
}

/// Festenao API service for CMS operations.
class FestenaoApiService extends TkCmsApiServiceBaseV2 {
  /// Create a [FestenaoApiService] with optional [httpClientFactory], [httpsApiUri], [callableApi], and [app].
  FestenaoApiService({
    HttpClientFactory? httpClientFactory,
    super.httpsApiUri,
    super.callableApi,
    super.app,
  }) : super(
         apiVersion: apiVersion2,
         httpClientFactory: httpClientFactory ?? httpClientFactoryUniversal,
       );
}

/// Represents a request to the AMP API.
abstract class AmpRequest {
  /// The path for the request.
  String get path;
}

/// Ensures all fields in [model] (or [fields] if provided) are present and non-null.
///
/// Throws [ArgumentError] if any field is missing or null.
void festenaoEnsureFields(CvModel model, {CvFields? fields}) {
  fields ??= model.fields;
  for (var field in fields) {
    if (model.field(field.name)?.isNull ?? true) {
      throw ArgumentError('field \\${field.name} missing or null in $model');
    }
  }
}
