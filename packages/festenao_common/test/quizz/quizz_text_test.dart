import 'package:festenao_common/festenao_quizz.dart';
import 'package:test/test.dart';

void main() {
  test('quizzFormatRemainingMsTime', () {
    var values = {
      for (var ms in [-5, 0, 1, 999, 1000, 1001, 59000, 59500, 60000, 61000])
        ms: quizzFormatRemainingMsTime(ms),
    };
    expect(values, {
      -5: '00:00',
      0: '00:00',
      1: '00:01',
      999: '00:01',
      1000: '00:01',
      1001: '00:02',
      59000: '00:59',
      59500: '01:00',
      60000: '01:00',
      61000: '01:01',
    });
    // Bounded to 99 minutes.
    expect(quizzFormatRemainingMsTime(200 * 60000), '99:59');
  }, timeout: const Timeout(Duration(seconds: 10)));
}
