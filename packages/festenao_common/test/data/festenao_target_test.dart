import 'package:festenao_common/data/festenao_target.dart';
import 'package:test/test.dart';

void main() {
  group('festenao_target', () {
    test('api', () async {
      expect(
          [devTarget, stagingTarget, prodTarget], ['dev', 'staging', 'prod']);
    });
  });
}
