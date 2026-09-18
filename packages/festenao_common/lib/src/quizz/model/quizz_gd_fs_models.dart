import '../import.dart';
import 'quizz_fs_models.dart';

var _builderInitialized = false;

/// Registers the gd (general knowledge) quizz models (idempotent).
void initQuizzGdFsBuilders() {
  if (_builderInitialized) {
    return;
  }
  _builderInitialized = true;
  initQuizzFsBuilders();
  cvAddConstructors([CvGdGoodieConfig.new, CvGdGoodieState.new]);
  cvAddConstructors([
    FsGdGoodiesState.new,
    FsGdGoodiesConfig.new,
    FsGdQuizPlayer.new,
  ]);
}

/// A gd player in `sessions/{sessionId}/players/{playerId}`.
class FsGdQuizPlayer extends CvFirestoreDocumentBase
    with WithServerTimestampMixin {
  /// The local device id.
  late final localDeviceId = CvField<String>('localDeviceId');

  /// The score.
  late final score = CvField<int>('score');

  /// The elapsed time for the correct answers.
  late final elapsedMs = CvField<int>('elapsedMs');

  /// The day.
  late final day = CvField<String>('day');

  /// Local start time of the player.
  late final localTimestamp = CvField<Timestamp>('localTimestamp');

  /// The goodie id won, if any.
  late final won = CvField<String>('won');

  /// Optional quiz id if organized by quiz.
  late final quizId = CvField<String>('quizId');

  @override
  late final fields = [
    localDeviceId,
    score,
    elapsedMs,
    quizId,
    localTimestamp,
    won,
    day,
    ...timedMixinFields,
  ];
}

/// Field names holder.
final fsGdQuizPlayerModel = FsGdQuizPlayer();

/// The daily state of a goodie.
class CvGdGoodieState extends CvModelBase {
  /// The goodie id.
  late final id = CvField<String>('id');

  /// The daily count.
  late final count = CvField<int>('count');

  /// The used count.
  late final used = CvField<int>('used');

  /// The remaining count.
  int get remainingCount => (count.v ?? 0) - (used.v ?? 0);

  @override
  CvFields get fields => [id, count, used];
}

/// The daily goodies state in `sessions/{sessionId}/goodiesStates/{day}`.
class FsGdGoodiesState extends CvFirestoreDocumentBase {
  /// The goodies states.
  late final goodies = CvModelListField<CvGdGoodieState>('goodies');

  @override
  CvFields get fields => [goodies];
}

/// The goodies config in `sessions/{sessionId}/infos/goodiesConfig`.
class FsGdGoodiesConfig extends CvFirestoreDocumentBase {
  /// The goodies.
  late final goodies = CvModelListField<CvGdGoodieConfig>('goodies');

  /// The winning chance, between 0 and 1.
  late final winningChance = CvField<num>('winningChance');

  /// The start of day time offset (`hh:mm`).
  late final startOfDayTimeOffset = CvField<String>('startOfDayTimeOffset');
  @override
  CvFields get fields => [goodies, winningChance, startOfDayTimeOffset];
}

/// A goodie config.
class CvGdGoodieConfig extends CvModelBase {
  /// The goodie id.
  late final id = CvField<String>('id');

  /// The goodie text.
  late final text = CvModelField<CvLocalizedText>('text');

  /// The daily quantity.
  late final dailyQuantity = CvField<int>('dailyQuantity');

  @override
  late final fields = [id, text, dailyQuantity];
}

/// Field names holder.
final cvGdGoodieConfigModel = CvGdGoodieConfig();
