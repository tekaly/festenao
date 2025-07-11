import 'package:path/path.dart';
import 'package:tekartik_app_http/app_http.dart';
import 'package:tkcms_common/tkcms_api.dart';

var functionFestenaoAmpDev = 'ampdev';
var functionFestenaoAmpProd = 'amp';

/// Amp page service
class FestenaoAmpService {
  final HttpClientFactory httpClientFactory;
  final Uri httpsAmpUri;

  late final basePath = httpsAmpUri.path;
  Client get client => _client;
  late final Client _client;
  FestenaoAmpService({
    HttpClientFactory? httpClientFactory,
    required this.httpsAmpUri,
  }) : httpClientFactory = httpClientFactory ?? httpClientFactoryUniversal;

  Future<void> initClient() async {
    _client = httpClientFactory.newClient();
  }

  Uri pathUri(String path) =>
      httpsAmpUri.replace(path: url.join(basePath, path));
  Future<String> read(String path) {
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    return _client.read(pathUri(path));
  }

  Future<void> close() async {
    try {
      _client.close();
    } catch (_) {}
    // keep local server on
  }
}

class FestenaoApiService extends TkCmsApiServiceBaseV2 {
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

abstract class AmpRequest {
  String get path;
}

/// All fields must be present and non null
void festenaoEnsureFields(CvModel model, {CvFields? fields}) {
  fields ??= model.fields;
  for (var field in fields) {
    if (model.field(field.name)?.isNull ?? true) {
      throw ArgumentError('field ${field.name} missing or null in $model');
    }
  }
}
