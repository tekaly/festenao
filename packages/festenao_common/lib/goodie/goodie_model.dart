import 'package:festenao_common/data/festenao_firestore.dart';

/// Initializes Firestore goodie builders.
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

/// Default mode for daily goodies.
const modeDaily = 'daily';

/// Mode for once-only goodies.
const modeOnce = 'once';

/// Firestore document for goodies configuration.
class FsGoodiesConfig extends CvFirestoreDocumentBase {
  /// The mode of the goodies (e.g., daily or once).
  late final mode = CvField<String>('mode');

  /// List of goodie configurations.
  late final goodies = CvModelListField<CvGoodieConfig>('goodies');

  /// Winning chance as a number between 0 and 1.
  late final winningChance = CvField<num>('winningChance');

  /// Start of day time offset in hour/min format.
  late final startOfDayTimeOffset = CvField<String>('startOfDayTimeOffset');

  @override
  CvFields get fields => [mode, goodies, winningChance, startOfDayTimeOffset];
}

/// Extension for [FsGoodiesConfig] to provide mode checks.
extension FsGoodiesConfigExt on FsGoodiesConfig {
  String get _mode => mode.v ?? modeDaily;

  /// True if the mode is daily.
  bool get isModeDaily => _mode == modeDaily;

  /// True if the mode is once.
  bool get isModeOnce => _mode == modeOnce;
}

/// Localized text for goodies.
class CvGoodieLocalizedText extends CvModelBase {
  /// English text.
  late final en = CvField<String>('en');

  /// French text.
  late final fr = CvField<String>('fr');

  @override
  late final fields = [en, fr];
}

/// Configuration for a single goodie.
class CvGoodieConfig extends CvModelBase {
  /// Unique identifier for the goodie.
  late final id = CvField<String>('id');

  /// Localized text for the goodie.
  late final text = CvModelField<CvGoodieLocalizedText>('text');

  /// Quantity of the goodie available.
  late final quantity = CvField<int>('quantity');

  @override
  late final fields = [id, text, quantity];
}

/// Model for goodie configuration.
final fsGdGoodieConfigModel = CvGoodieConfig();

/// Firestore document for a goodie player.
class FsGameGoodiePlayer extends CvFirestoreDocumentBase
    with WithServerTimestampMixin {
  /// Local device ID of the player.
  late final localDeviceId = CvField<String>('localDeviceId');

  /// Score of the player.
  late final score = CvField<int>('score');

  /// Elapsed time in milliseconds.
  late final elapsedMs = CvField<int>('elapsedMs');

  /// Day of the game.
  late final day = CvField<String>('day');

  /// Local start time of the player.
  late final localTimestamp = CvField<Timestamp>('localTimestamp');

  /// Won status.
  late final won = CvField<String>('won');

  /// Optional game ID if organized by game.
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

/// Model for goodie player.
final fsGameGoodiePlayerModel = FsGameGoodiePlayer();

/// State of a goodie.
class CvGoodieState extends CvModelBase {
  /// Unique identifier for the goodie.
  late final id = CvField<String>('id');

  /// Total count of the goodie.
  late final count = CvField<int>('count');

  /// Number of times the goodie has been used.
  late final used = CvField<int>('used');

  /// Remaining count of the goodie.
  int get remainingCount => (count.v ?? 0) - (used.v ?? 0);

  @override
  CvFields get fields => [id, count, used];
}

/// Firestore document for goodies state.
class FsGoodiesState extends CvFirestoreDocumentBase {
  /// List of goodie states.
  late final goodies = CvModelListField<CvGoodieState>('goodies');

  @override
  CvFields get fields => [goodies];
}

/// Firestore document for a goodie session.
class FsGoodieSession extends CvFirestoreDocumentBase {
  /// Name of the session.
  late final name = CvField<String>('name');

  /// Active game ID.
  late final activeGameId = CvField<String>('activeGameId');

  @override
  List<CvField<Object?>> get fields => [name, activeGameId];
}

/// Model for goodie session.
final fsGoodieSessionModel = FsGoodieSession();

/// Main session ID.
const sessionIdMain = '_main';

/// Test session ID.
const sessionIdTest = '_test';
