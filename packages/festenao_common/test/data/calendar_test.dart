import 'package:festenao_common/data/src/festenao/calendar/calendar.dart';
import 'package:test/test.dart';

void main() {
  group('time', () {
    test('time', () {
      var time = CalendarTime(seconds: 123456);
      expect(time.toString(), '10:17');

      time = CalendarTime(text: '10:00');
      expect(time.toString(), '10:00');
      time = CalendarTime(text: '1000');
      expect(time.toString(), '10:00');
      time = CalendarTime(text: '10');
      expect(time.toString(), '10:00');
      time = CalendarTime(text: '24:00');
      expect(time.toString(), '00:00');
      time = CalendarTime(text: '26:00');
      expect(time.toString(), '02:00');
      expect(time.toInputString(), '26:00');
    });
    test('day', () {
      var day = CalendarDay(text: '2012-01-23');
      expect(day.toString(), '2012-01-23');

      day = CalendarDay(text: '20120123');
      expect(day.toString(), '2012-01-23');
    });
    test('toDayTime', () {
      var day = CalendarDay(text: '2023-07-25');
      var time = CalendarTime(text: '10:00');
      expect(
          day.toDateTime(time).toIso8601String(), '2023-07-25T10:00:00.000Z');
      time = CalendarTime(text: '24:00');
      expect(
          day.toDateTime(time).toIso8601String(), '2023-07-26T00:00:00.000Z');
      time = CalendarTime(text: '49:00');
      expect(
          day.toDateTime(time).toIso8601String(), '2023-07-27T01:00:00.000Z');
    });
  });
}