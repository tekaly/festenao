import 'package:festenao_common/data/src/festenao/cv_import.dart';

@Deprecated('Use from tk')
/// Base API request model (deprecated).
///
/// Contains a method name and data payload field used by legacy APIs.
abstract class _ApiRequest extends CvModelBase {
  /// The API method name.
  final method = CvField<String>('method');

  /// The request data payload field (subclasses must provide concrete type).
  CvField get data;

  @override
  List<CvField> get fields => [method, data];
}

@Deprecated('Use from tk')
/// Simple ping API request for legacy systems.
class ApiPingRequest extends _ApiRequest {
  /// The ping method name constant.
  static const String methodName = 'ping';

  /// Constructs a new [ApiPingRequest] and sets the method name.
  ApiPingRequest() {
    method.v = methodName;
  }

  final _data = CvField<dynamic>('data');
  @override
  CvField get data => _data;
}
