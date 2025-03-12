import 'package:festenao_common/data/festenao_firestore.dart';

void initFsGoodieBuilders() {
  cvAddConstructors([
    FsGoodiesConfig.new,
    CvGoodieConfig.new,
    CvGoodieState.new,
    CvGoodieLocalizedText.new,
    FsGameGoodiePlayer.new,
    FsGoodiesState.new,
  ]);
}

/// Default (daily)
const modeDaily = 'daily';

/// Once
const modeOnce = 'once';

/// In session/{sessionId}/infos/goodiesConfig
class FsGoodiesConfig extends CvFirestoreDocumentBase {
  late final mode = CvField<String>('mode');
  late final goodies = CvModelListField<CvGoodieConfig>('goodies');
  late final winningChance = CvField<num>('winningChance'); // between 0 and 1
  late final startOfDayTimeOffset = CvField<String>(
    'startOfDayTimeOffset',
  ); // in hour/mn
  @override
  CvFields get fields => [mode, goodies, winningChance, startOfDayTimeOffset];
}

extension FsGoodiesConfigExt on FsGoodiesConfig {
  String get _mode => mode.v ?? modeDaily;

  /// Default behavior is daily
  bool get isModeDaily => _mode == modeDaily;
  bool get isModeOnce => _mode == modeOnce;
}

class CvGoodieLocalizedText extends CvModelBase {
  late final en = CvField<String>('en');
  late final fr = CvField<String>('fr');

  @override
  late final fields = [en, fr];
}

/// In session/{sessionId}/goodies/{goodieId}
class CvGoodieConfig extends CvModelBase {
  late final id = CvField<String>('id');
  late final text = CvModelField<CvGoodieLocalizedText>('text');
  late final quantity = CvField<int>('quantity');

  @override
  late final fields = [id, text, quantity];
}

final fsGdGoodieConfigModel = CvGoodieConfig();

/// In session/{sessionId}/players/{playerId}
class FsGameGoodiePlayer extends CvFirestoreDocumentBase
    with WithServerTimestampMixin {
  late final localDeviceId = CvField<String>('localDeviceId');
  late final score = CvField<int>('score');
  late final elapsedMs = CvField<int>('elapsedMs');
  late final day = CvField<String>('day');

  /// local start time of the player
  late final localTimestamp = CvField<Timestamp>('localTimestamp');

  /// Won status
  late final won = CvField<String>('won');

  /// Optional gameId if organized by game
  late final gameId = CvField<String>('game');

  @override
  late final fields = [
    localDeviceId,
    score,
    elapsedMs,
    gameId,
    localTimestamp,
    won,
    day,
    ...timedMixinFields,
  ];
}

final fsGameGoodiePlayerModel = FsGameGoodiePlayer();

class CvGoodieState extends CvModelBase {
  late final id = CvField<String>('id');
  late final count = CvField<int>('count');
  late final used = CvField<int>('used');

  int get remainingCount => (count.v ?? 0) - (used.v ?? 0);

  @override
  CvFields get fields => [id, count, used];
}

/// In session/{sessionId}/goodie_state/{day}
/// or (soon)
/// In session/{sessionId}/goodie_info/state
class FsGoodiesState extends CvFirestoreDocumentBase {
  late final goodies = CvModelListField<CvGoodieState>('goodies');

  @override
  CvFields get fields => [goodies];
}

/// in sessions/{id}
class FsGoodieSession extends CvFirestoreDocumentBase {
  late final name = CvField<String>('name');
  late final activeGameId = CvField<String>('activeGameId');

  @override
  List<CvField<Object?>> get fields => [name, activeGameId];
}

final fsGoodieSessionModel = FsGoodieSession();

const sessionIdMain = '_main';
const sessionIdTest = '_test';
