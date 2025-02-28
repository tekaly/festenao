import 'package:festenao_common/data/src/festenao/cv_import.dart';

@Deprecated('Use from tk')
abstract class ApiRequest extends CvModelBase {
  final method = CvField<String>('method');
  CvField get data;

  @override
  List<CvField> get fields => [method, data];
}

@Deprecated('Use from tk')
class ApiPingRequest extends ApiRequest {
  static const String methodName = 'ping';
  ApiPingRequest() {
    method.v = methodName;
  }
  final _data = CvField<dynamic>('data');
  @override
  CvField get data => _data;
}
