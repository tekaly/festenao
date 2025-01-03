import 'package:tekartik_common_utils/date_time_utils.dart';
import 'package:tekartik_common_utils/int_utils.dart';

var dataOffset = const Duration(minutes: -60);

String from2Digits(int value) {
  var sb = StringBuffer();
  value %= 100;

  sb.write(value ~/ 10);
  sb.write(value % 10);
  return sb.toString();
}

class CalendarTime implements Comparable<CalendarTime> {
  late int _seconds; // in seconds from midnight
  int get seconds => _seconds;

  // Handle 11:00 and 1100
  CalendarTime({String? text, int? seconds}) {
    if (seconds != null) {
      _seconds = seconds;
    } else if (text != null) {
      try {
        List<String> parts;
        if (text.length == 4) {
          parts = [text.substring(0, 2), text.substring(2, 4)];
        } else {
          parts = text.split(':');
        }
        _seconds = parseInt(parts[0])! * 60 * 60;
        if (parts.length > 1) {
          _seconds += parseInt(parts[1])! * 60;
          if (parts.length > 2) {
            _seconds += parseInt(parts[2])!;
          }
        }
      } catch (e) {
        throw ArgumentError.value('invalid $text $e');
      }
    } else {
      throw ArgumentError.notNull('text and seconds');
    }
  }

  @override
  int compareTo(CalendarTime other) => _seconds - other._seconds;

  @override
  String toString() {
    var hours = (_seconds ~/ 3600) % 24;
    var minutes = (_seconds ~/ 60) % 60;
    return '${from2Digits(hours)}:${from2Digits(minutes)}';
  }

  String toInputString() {
    var hours = (_seconds ~/ 3600);
    var minutes = (_seconds ~/ 60) % 60;
    return '${from2Digits(hours)}:${from2Digits(minutes)}';
  }

  // Return a time in the even timezone as UTC
  DateTime toDateTime(CalendarDay day, {bool? isLocal = false}) {
    var year = day.dateTime.year;
    var month = day.dateTime.month;
    var monthDay = day.dateTime.day;
    var hours = (_seconds ~/ 3600) % 24;
    var minutes = _seconds % 60;

    DateTime dateTime;
    if (isLocal ?? false) {
      dateTime = DateTime(year, month, monthDay, hours, minutes);
    } else {
      dateTime = DateTime.utc(year, month, monthDay, hours, minutes);
    }
    dateTime = dateTime.add(Duration(hours: totalDays * 24));
    return dateTime;
  }

  int get totalHours => _seconds ~/ 3600;
  int get totalDays => totalHours ~/ 24;
}

String twoDigitNumber(int number) {
  return (number < 10) ? '0$number' : '$number';
}

// 25:00 => 1:00
String secondsToTimeString(int seconds) {
  var hours = seconds ~/ 3600;
  var minutes = (seconds - hours * 3600) ~/ 60;
  if (hours >= 24) {
    hours -= 24;
  }
  return '${twoDigitNumber(hours)}:${twoDigitNumber(minutes)}';
}

CalendarDay? parseCalendarDayOrNull(String? text) {
  if (text == null) {
    return null;
  }
  return parseCalendarDay(text);
}

CalendarDay? parseCalendarDay(String text) {
  try {
    return CalendarDay(text: text);
  } catch (_) {
    return null;
  }
}

CalendarDay parseCalendarDayOrThrow(String text) {
  return CalendarDay(text: text);
}

/// For start-end format
CalendarTime? parseStartCalendarTime(String text) {
  try {
    return parseStartCalendarTimeOrThrow(text);
  } catch (_) {
    return null;
  }
}

/// For start-end format
CalendarTime parseStartCalendarTimeOrThrow(String text) {
  return CalendarTime(text: text.split('-').first);
}

/// For start-end format
CalendarTime? parseEndCalendarTime(String text) {
  try {
    return CalendarTime(text: text.split('-')[1]);
  } catch (_) {
    return null;
  }
}

class CalendarDay implements Comparable<CalendarDay> {
  late final DateTime _dateTime;

  /// Use either, [dateTime] takes precedence
  CalendarDay({String? text, DateTime? dateTime}) {
    dateTime ??= parseDateTime(text);
    if (dateTime != null) {
      _dateTime = DateTime.utc(dateTime.year, dateTime.month, dateTime.day);
    } else {
      throw ArgumentError('$text $_dateTime');
    }
  }

  DateTime get dateTime => _dateTime;

  @override
  int compareTo(CalendarDay other) =>
      _dateTime.millisecondsSinceEpoch - other._dateTime.millisecondsSinceEpoch;

  @override
  String toString() => _dateTime.toIso8601String().substring(0, 10);

  @override
  int get hashCode => _dateTime.millisecondsSinceEpoch;

  @override
  bool operator ==(other) {
    if (other is CalendarDay) {
      return _dateTime.millisecondsSinceEpoch ==
          other._dateTime.millisecondsSinceEpoch;
    }
    return false;
  }

  /// UTC is the default
  DateTime toDateTime(CalendarTime time, {bool? isLocal = false}) {
    return time.toDateTime(this, isLocal: isLocal);
  }
}

String dateFormatWeekDayFr(DateTime dateTime) {
  return dayOfWeekFr[dateTime.weekday]!;
}

String dateFormatWeekDayFrShort(DateTime dateTime) =>
    dateFormatWeekDayFr(dateTime).substring(0, 3);

var dayOfWeekFr = {
  DateTime.monday: 'Lundi',
  DateTime.tuesday: 'Mardi',
  DateTime.wednesday: 'Mercredi',
  DateTime.thursday: 'Jeudi',
  DateTime.friday: 'Vendredi',
  DateTime.saturday: 'Samedi',
  DateTime.sunday: 'Dimanche'
};
