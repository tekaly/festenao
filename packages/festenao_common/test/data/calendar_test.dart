import 'package:festenao_common/data/src/festenao/calendar/calendar.dart';
import 'package:test/test.dart';

void main() {
  group('time', () {
    test('time compat', () {
      var time = CalendarTimeCompat(seconds: 123456);
      expect(time.toString(), '10:17');
    });
    test('time', () {
      var time = CalendarTime(seconds: 123456);
      expect(time.text, '34:17:36');
      expect(time.toString(), 'Time(34:17:36)');

      time = CalendarTime(text: '10:00');
      expect(time.text, '10:00');
      expect(time.toString(), 'Time(10:00)');
      time = CalendarTime(text: '1000');
      expect(time.text, '10:00');
      time = CalendarTime(text: '10');
      expect(time.text, '10:00');
      time = CalendarTime(text: '24:00');
      expect(time.text, '24:00');
      time = CalendarTime(text: '26:00');
      expect(time.text, '26:00');
      expect(time.toInputString(), '26:00');
      time = CalendarTime(text: '-2:00');
      expect(time.text, '-02:00');
    });
    test('day', () {
      var day = CalendarDay(text: '2012-01-23');
      expect(day.text, '2012-01-23');
      expect(day.toString(), 'Day(2012-01-23)');

      day = CalendarDay(text: '20120123');
      expect(day.text, '2012-01-23');
    });
    test('toDayTime', () {
      var day = CalendarDay(text: '2023-07-25');
      var time = CalendarTime(text: '10:00');
      expect(
        day.toDateTime(time).toIso8601String(),
        '2023-07-25T10:00:00.000Z',
      );
      time = CalendarTime(text: '24:00');
      expect(
        day.toDateTime(time).toIso8601String(),
        '2023-07-26T00:00:00.000Z',
      );
      time = CalendarTime(text: '49:00');
      expect(
        day.toDateTime(time).toIso8601String(),
        '2023-07-27T01:00:00.000Z',
      );
      // The minutes are kept.
      time = CalendarTime(text: '10:30');
      expect(
        day.toDateTime(time).toIso8601String(),
        '2023-07-25T10:30:00.000Z',
      );
      time = CalendarTime(text: '24:45');
      expect(
        day.toDateTime(time).toIso8601String(),
        '2023-07-26T00:45:00.000Z',
      );
      expect(day.toDateTime(time, isLocal: true), DateTime(2023, 7, 26, 0, 45));
    });
    test('toDayTime compat', () {
      var day = CalendarDayCompat(text: '2023-07-25');
      var time = CalendarTimeCompat(text: '10:30');
      expect(
        day.toDateTime(time).toIso8601String(),
        '2023-07-25T10:30:00.000Z',
      );
      time = CalendarTimeCompat(text: '24:45');
      expect(
        day.toDateTime(time).toIso8601String(),
        '2023-07-26T00:45:00.000Z',
      );
    });
    test('toDateTime matches dayTimeToDateTime', () {
      var day = CalendarDay(text: '2023-07-25');
      for (var text in [
        '10:00',
        '10:00:30',
        '24:45',
        '49:00',
        '-2:00',
        '-0:30',
      ]) {
        var time = CalendarTime(text: text);
        expect(
          day.toDateTime(time),
          dayTimeToDateTime(day, time),
          reason: text,
        );
        expect(
          day.toDateTime(time, isLocal: true),
          dayTimeToLocalDateTime(day, time),
          reason: text,
        );
      }
      // A negative time is on the previous day.
      expect(
        day.toDateTime(CalendarTime(text: '-2:00')).toIso8601String(),
        '2023-07-24T22:00:00.000Z',
      );
      expect(
        day.toDateTime(CalendarTime(text: '-0:30'), isLocal: true),
        DateTime(2023, 7, 24, 23, 30),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
    test('local toDateTime is the wall clock time on a DST night', () {
      // Wrong by one hour in a time zone changing on these nights (run with
      // TZ=Europe/Paris), whatever the zone the expectation is the same.
      var time = CalendarTime(text: '27:00');
      expect(
        CalendarDay(text: '2026-03-28').toDateTime(time, isLocal: true),
        DateTime(2026, 3, 29, 3),
      );
      expect(
        CalendarDay(text: '2026-10-24').toDateTime(time, isLocal: true),
        DateTime(2026, 10, 25, 3),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
    test('toDateTime compat matches dayTimeToDateTime', () {
      var day = CalendarDayCompat(text: '2023-07-25');
      for (var text in ['10:00', '10:00:30', '24:45', '49:00']) {
        var time = CalendarTimeCompat(text: text);
        var expected = CalendarTime(seconds: time.seconds);
        var expectedDay = CalendarDay(text: '2023-07-25');
        expect(
          day.toDateTime(time),
          dayTimeToDateTime(expectedDay, expected),
          reason: text,
        );
        expect(
          day.toDateTime(time, isLocal: true),
          dayTimeToLocalDateTime(expectedDay, expected),
          reason: text,
        );
      }
      var time = CalendarTimeCompat(seconds: -7200);
      expect(
        day.toDateTime(time).toIso8601String(),
        '2023-07-24T22:00:00.000Z',
      );
      expect(
        CalendarDayCompat(
          text: '2026-03-28',
        ).toDateTime(CalendarTimeCompat(text: '27:00'), isLocal: true),
        DateTime(2026, 3, 29, 3),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
    test('toInputString of a negative time', () {
      expect(CalendarTime(text: '-0:30').toInputString(), '-00:30');
      expect(CalendarTime(text: '-2:15').toInputString(), '-02:15');
      expect(CalendarTime(text: '26:00').toInputString(), '26:00');
      expect(CalendarTimeCompat(seconds: -1800).toInputString(), '-00:30');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
