import 'package:festenao_common/data/calendar.dart';
import 'package:tekartik_common_utils/date_time_utils.dart';
import 'package:tekartik_common_utils/int_utils.dart';
export 'package:tekartik_app_date/calendar_day.dart';
export 'package:tekartik_app_date/calendar_time.dart';

/// Data offset.
var dataOffset = const Duration(minutes: -60);

/// For start-end format
CalendarTime parseStartCalendarTimeOrThrow(String text) {
  return CalendarTime(text: text.split('-').first);
}

/// Used by apps
CalendarDay parseCalendarDayOrThrow(String text) {
  return CalendarDay(text: text);
}

/// Compatibility extension on [CalendarTime].
extension CalendarTimeCompatExt on CalendarTime {
  /// Converts to input string format.
  String toInputString() {
    var hours = (seconds ~/ 3600);
    var minutes = (seconds ~/ 60) % 60;
    return '${from2Digits(hours)}:${from2Digits(minutes)}';
  }

  /// Return a time in the even timezone as UTC
  DateTime toDateTime(CalendarDay day, {bool? isLocal = false}) {
    var year = day.dateTime.year;
    var month = day.dateTime.month;
    var monthDay = day.dateTime.day;
    var hours = (seconds ~/ 3600) % 24;
    var minutes = seconds % 60;

    DateTime dateTime;
    if (isLocal ?? false) {
      dateTime = DateTime(year, month, monthDay, hours, minutes);
    } else {
      dateTime = DateTime.utc(year, month, monthDay, hours, minutes);
    }
    dateTime = dateTime.add(Duration(hours: totalDays * 24));
    return dateTime;
  }

  /// Total hours.
  int get totalHours => seconds ~/ 3600;

  /// Total days.
  int get totalDays => totalHours ~/ 24;
}

/// Compatibility extension on [CalendarDay].
extension CalendarDayCompatExt on CalendarDay {
  /// UTC is the default
  DateTime toDateTime(CalendarTime time, {bool? isLocal = false}) {
    return time.toDateTime(this, isLocal: isLocal);
  }
}

/// Formats a 2-digit number.
String from2Digits(int value) {
  var sb = StringBuffer();
  value %= 100;

  sb.write(value ~/ 10);
  sb.write(value % 10);
  return sb.toString();
}

/// Compatibility [CalendarTime] class.
class CalendarTimeCompat implements Comparable<CalendarTimeCompat> {
  late int _seconds; // in seconds from midnight
  /// Seconds from midnight.
  int get seconds => _seconds;

  /// Handle 11:00 and 1100
  CalendarTimeCompat({String? text, int? seconds}) {
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
  int compareTo(CalendarTimeCompat other) => _seconds - other._seconds;

  @override
  String toString() {
    var hours = (_seconds ~/ 3600) % 24;
    var minutes = (_seconds ~/ 60) % 60;
    return '${from2Digits(hours)}:${from2Digits(minutes)}';
  }

  /// Converts to input string format.
  String toInputString() {
    var hours = (_seconds ~/ 3600);
    var minutes = (_seconds ~/ 60) % 60;
    return '${from2Digits(hours)}:${from2Digits(minutes)}';
  }

  /// Return a time in the even timezone as UTC
  DateTime toDateTime(CalendarDayCompat day, {bool? isLocal = false}) {
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

  /// Total hours.
  int get totalHours => _seconds ~/ 3600;

  /// Total days.
  int get totalDays => totalHours ~/ 24;
}

/// Returns a 2-digit number string.
String twoDigitNumber(int number) {
  return (number < 10) ? '0$number' : '$number';
}

// 25:00 => 1:00
/// Converts seconds to time string.
String secondsToTimeString(int seconds) {
  var hours = seconds ~/ 3600;
  var minutes = (seconds - hours * 3600) ~/ 60;
  if (hours >= 24) {
    hours -= 24;
  }
  return '${twoDigitNumber(hours)}:${twoDigitNumber(minutes)}';
}

/// Parses calendar day or null.
CalendarDayCompat? parseCalendarDayOrNullCompat(String? text) {
  if (text == null) {
    return null;
  }
  return parseCalendarDayCompat(text);
}

/// Parses calendar day.
CalendarDayCompat? parseCalendarDayCompat(String text) {
  try {
    return CalendarDayCompat(text: text);
  } catch (_) {
    return null;
  }
}

/// Parses calendar day or throws.
CalendarDayCompat parseCalendarDayOrThrowCompat(String text) {
  return CalendarDayCompat(text: text);
}

/// For start-end format
CalendarTimeCompat? parseStartCalendarTimeCompat(String text) {
  try {
    return parseStartCalendarTimeOrThrowCompat(text);
  } catch (_) {
    return null;
  }
}

/// For start-end format
CalendarTimeCompat parseStartCalendarTimeOrThrowCompat(String text) {
  return CalendarTimeCompat(text: text.split('-').first);
}

/// For start-end format
CalendarTimeCompat? parseEndCalendarTime(String text) {
  try {
    return CalendarTimeCompat(text: text.split('-')[1]);
  } catch (_) {
    return null;
  }
}

/// Compatibility [CalendarDay] class.
class CalendarDayCompat implements Comparable<CalendarDayCompat> {
  late final DateTime _dateTime;

  /// Use either, [dateTime] takes precedence
  CalendarDayCompat({String? text, DateTime? dateTime}) {
    dateTime ??= parseDateTime(text);
    if (dateTime != null) {
      _dateTime = DateTime.utc(dateTime.year, dateTime.month, dateTime.day);
    } else {
      throw ArgumentError('$text $_dateTime');
    }
  }

  /// The date time.
  DateTime get dateTime => _dateTime;

  @override
  int compareTo(CalendarDayCompat other) =>
      _dateTime.millisecondsSinceEpoch - other._dateTime.millisecondsSinceEpoch;

  @override
  String toString() => _dateTime.toIso8601String().substring(0, 10);

  @override
  int get hashCode => _dateTime.millisecondsSinceEpoch;

  @override
  bool operator ==(other) {
    if (other is CalendarDayCompat) {
      return _dateTime.millisecondsSinceEpoch ==
          other._dateTime.millisecondsSinceEpoch;
    }
    return false;
  }

  /// UTC is the default
  DateTime toDateTime(CalendarTimeCompat time, {bool? isLocal = false}) {
    return time.toDateTime(this, isLocal: isLocal);
  }
}

/// Formats week day in French.
String dateFormatWeekDayFr(DateTime dateTime) {
  return dayOfWeekFr[dateTime.weekday]!;
}

/// Formats short week day in French.
String dateFormatWeekDayFrShort(DateTime dateTime) =>
    dateFormatWeekDayFr(dateTime).substring(0, 3);

/// Day of week in French.
var dayOfWeekFr = {
  DateTime.monday: 'Lundi',
  DateTime.tuesday: 'Mardi',
  DateTime.wednesday: 'Mercredi',
  DateTime.thursday: 'Jeudi',
  DateTime.friday: 'Vendredi',
  DateTime.saturday: 'Samedi',
  DateTime.sunday: 'Dimanche',
};
