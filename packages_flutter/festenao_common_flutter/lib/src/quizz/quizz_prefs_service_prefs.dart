import 'package:cv/cv_json.dart';
import 'package:festenao_common/festenao_quizz.dart';
import 'package:tekartik_app_prefs/app_prefs.dart';

const _quizIdKey = 'quizId';
const _quizLocalStatusKey = 'quizLocalStatus';
const _quizLocalCopyKey = 'quizLocalCopy';
const _deviceIdKey = 'deviceId';
const _lastUsernameKey = 'lastUsername';
const _lastTimeOffsetMsKey = 'lastTimeOffsetMs';

/// The device id of the app install, generated once and kept in [prefs].
String quizzPrefsGetOrCreateDeviceId(Prefs prefs) {
  var deviceId = prefs.getString(_deviceIdKey);
  if (deviceId == null || deviceId.isEmpty) {
    deviceId = quizzGenerateDeviceId();
    prefs.setString(_deviceIdKey, deviceId);
  }
  return deviceId;
}

/// A [QuizzPrefsService] persisted in [Prefs], keyed by the current quiz id:
/// the status and copy of another quiz are discarded when the quiz changes.
class QuizzPrefsServicePrefs implements QuizzPrefsService {
  /// The prefs.
  final Prefs prefs;

  /// Creates the service.
  QuizzPrefsServicePrefs({required this.prefs}) {
    initQuizzPrefsBuilders();
  }

  String? _prefsQuizId;

  /// The current quiz id.
  String? prefsGetQuizId() => _prefsQuizId ??= prefs.getString(_quizIdKey);

  /// Sets the current quiz id, discarding the status and copy of another
  /// quiz.
  void prefsSetQuizId(String? quizId) {
    if (quizId != prefsGetQuizId()) {
      prefsSetQuizLocalStatus(null);
      prefsSetQuizLocalCopy(null);
    }
    prefs.setString(_quizIdKey, _prefsQuizId = quizId);
  }

  /// The last username used.
  String? prefsGetLastUsername() => prefs.getString(_lastUsernameKey);

  /// Sets the last username used.
  void prefsSetLastUsername(String? username) =>
      prefs.setString(_lastUsernameKey, username);

  /// The last time offset with the server, see [QuizzTimeService].
  int? prefsGetLastTimeOffsetMs() => prefs.getInt(_lastTimeOffsetMsKey);

  /// Sets the last time offset with the server.
  void prefsSetLastTimeOffsetMs(int? ms) =>
      prefs.setInt(_lastTimeOffsetMsKey, ms);

  PrefsQuizLocalStatus? _prefsQuizLocalStatus;
  PrefsQuizLocalCopy? _prefsQuizLocalCopy;

  @override
  PrefsQuizLocalStatus? prefsGetQuizLocalStatus() {
    var localStatus = _prefsQuizLocalStatus ??= prefs
        .getString(_quizLocalStatusKey)
        ?.cv<PrefsQuizLocalStatus>();
    if (localStatus != null && localStatus.quizId.v != prefsGetQuizId()) {
      prefsSetQuizLocalStatus(null);
      prefsSetQuizLocalCopy(null);
      return null;
    }
    return localStatus;
  }

  @override
  PrefsQuizLocalCopy? prefsGetQuizLocalCopy() {
    var localCopy = _prefsQuizLocalCopy ??= prefs
        .getString(_quizLocalCopyKey)
        ?.cv<PrefsQuizLocalCopy>();
    if (localCopy != null && localCopy.quizId.v != prefsGetQuizId()) {
      prefsSetQuizLocalCopy(null);
      prefsSetQuizLocalStatus(null);
      return null;
    }
    return localCopy;
  }

  @override
  void prefsSetQuizLocalStatus(PrefsQuizLocalStatus? quizLocalStatus) =>
      prefs.setString(
        _quizLocalStatusKey,
        (_prefsQuizLocalStatus = quizLocalStatus)?.toJson(),
      );

  @override
  void prefsSetQuizLocalCopy(PrefsQuizLocalCopy? quizCopy) => prefs.setString(
    _quizLocalCopyKey,
    (_prefsQuizLocalCopy = quizCopy)?.toJson(),
  );
}
