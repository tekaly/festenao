import 'package:festenao_youtube_player/yt_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseClockDuration', () {
    test('m:ss', () {
      expect(
        parseClockDuration('3:55'),
        const Duration(minutes: 3, seconds: 55),
      );
      expect(parseClockDuration('0:07'), const Duration(seconds: 7));
    });

    test('h:mm:ss', () {
      expect(
        parseClockDuration('1:02:03'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
    });

    test('rejects anything else', () {
      expect(parseClockDuration('LIVE'), isNull);
      expect(parseClockDuration('12'), isNull);
      expect(parseClockDuration('1:2:3:4'), isNull);
      expect(parseClockDuration('a:bb'), isNull);
    });
  });
}
