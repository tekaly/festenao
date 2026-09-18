import 'import.dart';
import 'model/quizz_fs_models.dart';

/// Formats a time as `hh:mm:ss`.
String quizzFormatTime(DateTime dateTime) =>
    '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';

/// Formats a duration as `hh:mm:ss.mmm` (or the default `toString` above a
/// day).
String quizzFormatDuration(Duration duration) {
  if (duration < const Duration(days: 1)) {
    return '${duration.inHours.toString().padLeft(2, '0')}:${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}.${duration.inMilliseconds.remainder(1000).toString().padLeft(3, '0')}';
  }
  return duration.toString();
}

/// Formats a duration in milliseconds, see [quizzFormatDuration].
String quizzFormatMs(int ms) => quizzFormatDuration(Duration(milliseconds: ms));

/// Formats a date time as `yyyy-mm-dd hh:mm:ss` (local time).
String quizzFormatDateTime(DateTime dateTime) {
  var local = dateTime.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${quizzFormatTime(local)}';
}

/// Formats a remaining time as `mm:ss`, rounded up to the next second.
String quizzFormatRemainingMsTime(int ms) {
  ms = ms.boundedMin(0);
  int seconds;
  var mn = (ms ~/ 60000).bounded(0, 99);
  if (ms == 0) {
    seconds = 0;
  } else {
    seconds = (ms % 60000) ~/ 1000 + 1;
  }
  return '${mn.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// The trimmed value, null if empty.
String? quizzNonEmptyTrimmed(String? value) {
  return stringNonEmpty(value?.trim());
}

/// Localized text helpers.
extension CvLocalizedTextExt on CvLocalizedText {
  /// The french text, null if empty.
  String? get frText => quizzNonEmptyTrimmed(fr.v);

  /// The english text, null if empty.
  String? get enText => quizzNonEmptyTrimmed(en.v);

  /// The english text, or the french one.
  String? get defaultText => enText ?? frText;

  /// The text for a language code (`en`, `fr`), falling back to
  /// [defaultText].
  String? textForLanguageCode(String? languageCode) {
    switch (languageCode) {
      case 'fr':
        return frText ?? enText;
      case 'en':
        return enText ?? frText;
      default:
        return defaultText;
    }
  }

  /// True if at least one language is set.
  bool isValid() {
    return frText != null || enText != null;
  }
}
