import 'package:festenao_common/festenao_quizz.dart';

/// A display name, capitalized (`P` when empty).
String quizzFixDisplayNameString(String displayName) {
  displayName = displayName.trim();
  if (displayName.isEmpty) {
    return 'P';
  }
  displayName =
      '${displayName.substring(0, 1).toUpperCase()}${displayName.substring(1)}';
  return displayName;
}

/// A hidden display name: its first letter followed by an ellipsis.
String quizzHideDisplayNameString(String displayName) {
  var sb = StringBuffer();
  displayName = displayName.trim();
  if (displayName.isEmpty) {
    return 'P…';
  }
  sb.write(displayName.substring(0, 1).toUpperCase());
  if (displayName.length > 1) {
    sb.write('…');
  }
  return sb.toString();
}

/// The display name of a player, hidden until validated.
String quizzGetPlayerDisplayName(FsQuizPlayer? player) {
  var displayName = player?.username.v ?? '';
  if (player?.validity.v == quizPlayerValidityValid) {
    return quizzFixDisplayNameString(displayName);
  } else {
    return quizzHideDisplayNameString(displayName);
  }
}
