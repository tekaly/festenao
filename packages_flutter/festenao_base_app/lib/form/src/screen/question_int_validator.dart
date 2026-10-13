import 'package:tekartik_common_utils/string_utils.dart';

/// Validates the text of an int question: a number between [min] and [max]
/// (inclusive), empty only if [emptyAllowed]. Returns the error message or
/// null when valid.
String? formQuestionIntValidator(
  String? value, {
  required bool emptyAllowed,
  int? min,
  int? max,
}) {
  var rawText = value?.trimmedNonEmpty();

  if (rawText == null) {
    if (emptyAllowed) {
      return null;
    }
    return 'Veuillez saisir une valeur';
  }
  var intValue = int.tryParse(rawText);
  if (intValue == null) {
    return 'Veuillez saisir un nombre';
  }
  if (min != null && intValue < min) {
    return 'Minimum $min';
  }
  if (max != null && intValue > max) {
    return 'Maximum $max';
  }
  return null;
}
