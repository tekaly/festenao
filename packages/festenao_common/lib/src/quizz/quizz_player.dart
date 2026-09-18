import 'dart:math';

import 'import.dart';
import 'model/quizz_api_models.dart';
import 'model/quizz_fs_models.dart';
import 'model/quizz_prefs_models.dart';
import 'quizz_api_client.dart';
import 'quizz_avatar.dart';
import 'quizz_constant.dart';
import 'quizz_firestore_database.dart';
import 'quizz_prefs_service.dart';
import 'quizz_progress_controller.dart';
import 'quizz_time_service.dart';

/// The state cache of a gd quiz.
class QuizRunnerStateCacheGd extends QuizRunnerStateCache {
  /// Creates the cache.
  QuizRunnerStateCacheGd({required super.quiz});
}

/// The state cache of a tv quiz.
class QuizRunnerStateCacheTv extends QuizRunnerStateCache {
  /// Creates the cache.
  QuizRunnerStateCacheTv({required super.quiz});
}

/// The timing of a quiz (question starts), computed once from the quiz
/// config, to recreate when the quiz changes.
abstract class QuizRunnerStateCache {
  /// The quiz.
  final FsQuiz quiz;

  /// The question starts in ms from the quiz start, the last one being the
  /// end of the last question.
  late final List<int> questionMsStarts;

  /// Start of the post step.
  int get postMsStart => questionMsStarts.last;

  /// End of the pre step.
  int get preMsEnd => questionMsStarts.first;

  /// The answer delay.
  int get answerDelayMs =>
      quiz.answerDelayMs.v ?? quizConfigAnswerDelayMsDefault;

  /// The pause delay.
  int get pauseDelayMs => quiz.pauseDelayMs.v ?? quizConfigPauseDelayMsDefault;

  /// The question count.
  int get questionCount => quiz.questions.v?.length ?? 0;

  /// The cache of a quiz, gd or tv.
  factory QuizRunnerStateCache.typed({required FsQuiz quiz, bool? isTypeGd}) {
    isTypeGd ??= quiz.isTypeGd;
    if (isTypeGd) {
      return QuizRunnerStateCacheGd(quiz: quiz);
    } else {
      return QuizRunnerStateCacheTv(quiz: quiz);
    }
  }

  /// Creates the cache.
  QuizRunnerStateCache({required this.quiz}) {
    questionMsStarts = <int>[];

    var preDelayMs = quiz.preDelayMs.v ?? quizConfigPreDelayMsDefault;

    var questionDurationMs = answerDelayMs + pauseDelayMs;
    var ms = preDelayMs;
    questionMsStarts.add(ms);

    for (var i = 0; i < questionCount; i++) {
      if (i < questionCount - 1) {
        ms += questionDurationMs;
      } else {
        ms += answerDelayMs;
      }
      questionMsStarts.add(ms);
    }
  }

  /// True if the quiz exists.
  bool get quizExists => quiz.exists;

  /// True if [ms] is in the pre step.
  bool isPre(int ms) {
    return quizExists && ms < questionMsStarts.first;
  }

  /// True if [ms] is in the post step.
  bool isPost(int ms) {
    return quizExists && ms >= questionMsStarts.last;
  }

  /// True if expired (30mn after post).
  bool isExpired(int ms) => isPost(ms - quizAutoCancelDelayMs);

  /// Only if isPost, ms after the end.
  int getPostMs(int ms) {
    return ms - questionMsStarts.last;
  }

  /// Only if isPre, ms before the first question.
  int getRemainingPreMs(int ms) {
    return questionMsStarts.first - ms;
  }

  /// The elapsed pre ms.
  int getElapsedPreMs(int ms) {
    return ms;
  }

  /// The pre duration.
  int getPreDurationMs() {
    return questionMsStarts.first;
  }

  /// The question index at [ms], null if not in a question.
  int? questionIndex(int ms) {
    if (!quizExists || isPre(ms) || isPost(ms)) {
      return null;
    }
    for (var i = 1; i < questionMsStarts.length; i++) {
      if (ms < questionMsStarts[i]) {
        return i - 1;
      }
    }
    return null;
  }

  /// The answer duration of a question.
  int getQuestionAnswerDurationMs(int index) {
    return answerDelayMs;
  }

  /// The pause duration after a question (none after the last one).
  int getQuestionPauseDurationMs(int index) {
    if (index != questionCount - 1) {
      return pauseDelayMs;
    }
    return 0;
  }

  /// The remaining answer time, negative during the pause.
  int getQuestionAnswerRemainingMs(int index, int ms) {
    return getQuestionAnswerDurationMs(index) -
        getQuestionAnswerElapsedMs(index, ms);
  }

  /// The elapsed time since the question start.
  int getQuestionAnswerElapsedMs(int index, int ms) {
    return ms - getQuestionStartMs(index);
  }

  /// The question start in ms from the quiz start.
  int getQuestionStartMs(int index) {
    return questionMsStarts[index];
  }

  /// The remaining pause time after a question.
  int getQuestionPauseRemainingMs(int index, int ms) {
    var durationMs = questionMsStarts[index + 1] - ms;
    return getQuestionPauseDurationMs(index) - durationMs;
  }

  @override
  String toString() {
    return 'QuizRunnerStateCache(quiz: ${quiz.id} ${quiz.type.v})';
  }
}

/// The state of a gd quiz: the quiz and the local status/copy.
class QuizRunnerStateGd extends QuizRunnerState {
  /// The local status.
  PrefsQuizLocalStatus get localStatus => localStatusOrNull!;

  /// The local status, if any.
  PrefsQuizLocalStatus? localStatusOrNull;

  /// The local copy, if any.
  PrefsQuizLocalCopy? localCopyOrNull;

  @override
  bool get isValid =>
      (localCopyOrNull?.questions.isNotNull ?? false) &&
      (localStatusOrNull?.answers.isNotNull ?? false) &&
      (localCopy.quizId.v == localStatus.quizId.v);

  /// The local copy.
  PrefsQuizLocalCopy get localCopy => localCopyOrNull!;

  /// Creates the state.
  QuizRunnerStateGd(
    super.cache,
    super.status, {
    PrefsQuizLocalStatus? localStatus,
    PrefsQuizLocalCopy? localCopy,
  }) : localStatusOrNull = localStatus,
       localCopyOrNull = localCopy;

  /// The answers.
  List<CvPrefsQuizPlayerAnswer> get answers => localStatus.answers.v!;

  @override
  List<CvQuizEncodedQuestion> get questions => localCopy.questions.v!;

  @override
  int get questionCount => questions.length;

  /// The question index to answer, null if all done.
  int? get questionIndex {
    for (var i = 0; i < questionCount; i++) {
      var answer = answers[i];
      if (answer.answerId.isNull) {
        return i;
      }
    }
    return null;
  }

  @override
  QuizPlayerStateNow now(DateTime now) {
    return QuizPlayerStateNowGd(state: this, now: now);
  }
}

/// The state of a tv quiz: the quiz and its status.
class QuizRunnerStateTv extends QuizRunnerState {
  /// Creates the state.
  QuizRunnerStateTv(super.cache, super.status);

  @override
  QuizPlayerStateNow now(DateTime now) {
    return QuizPlayerStateNowTv(state: this, now: now);
  }

  /// Sometimes the status is created in memory when controlling it (tv, admin)
  @override
  bool get isValid => statusExists && quizExists;

  @override
  List<CvQuizEncodedQuestion> get questions => cache.quiz.questions.v!;
}

/// The state of a quiz (quiz + status), to recreate on every change; [now]
/// gives the time dependent view.
abstract class QuizRunnerState {
  /// The timing cache.
  final QuizRunnerStateCache cache;

  /// The status.
  final FsQuizStatus status;

  /// True if the status exists.
  bool get statusExists => status.exists;

  /// True if the quiz exists.
  bool get quizExists => cache.quizExists;

  /// Valid state for gd or tv
  bool get isValid;

  /// Creates the state.
  QuizRunnerState(this.cache, this.status);

  /// The state of a quiz, gd or tv.
  factory QuizRunnerState.typed(
    QuizRunnerStateCache cache,
    FsQuizStatus status, {
    bool? isTypeGd,
  }) {
    isTypeGd ??= cache.quiz.isTypeGd;
    if (isTypeGd) {
      return QuizRunnerStateGd(cache, status);
    } else {
      return QuizRunnerStateTv(cache, status);
    }
  }

  /// True if cancelled.
  bool get isCancelled => status.status.v == quizStatusCancelled;

  /// True if idle.
  bool get isIdle => status.status.v == quizStatusIdle;

  /// True if done.
  bool get isDone => status.status.v == quizStatusDone;

  /// True if archived.
  bool get isArchived => status.isArchived;

  /// True if done or archived.
  bool get isDoneOrArchived => status.isDoneOrArchived;

  /// The question count (the wished one bounded by the actual one).
  int get questionCount => min(_wishedQuestionCount, _actualQuestionCount);

  int get _wishedQuestionCount => _quiz.questionCount.v ?? _actualQuestionCount;

  int get _actualQuestionCount => _quiz.questions.v?.length ?? 0;

  /// True for a gd quiz.
  bool get isTypeGd => _quiz.isTypeGd;

  /// The questions.
  List<CvQuizEncodedQuestion> get questions;

  /// The time dependent view at [now].
  QuizPlayerStateNow now(DateTime now);

  /// The quiz.
  FsQuiz get quiz => cache.quiz;

  FsQuiz get _quiz => cache.quiz;

  @override
  String toString() => '${isTypeGd ? 'GD ' : 'TV '}$status $_quiz';
}

/// The time dependent view of a tv quiz.
class QuizPlayerStateNowTv extends QuizPlayerStateNow {
  /// Creates the view.
  QuizPlayerStateNowTv({required super.state, required super.now});

  @override
  int get questionCount => cache.quiz.questions.v?.length ?? 0;

  @override
  CvQuizEncodedQuestion getQuestionAt(int questionIndex) =>
      cache.quiz.questions.v![questionIndex];

  @override
  bool get isPost => isValidNotCancelled && !isCancelled && cache.isPost(ms);

  @override
  bool get isPre => isValidNotCancelled && cache.isPre(ms);

  /// The ms in the quiz (only for status playing or paused).
  @override
  late final int ms = () {
    switch (status.status.v!) {
      case quizStatusDone:
      case quizStatusArchived:
      case quizStatusPlaying:
        return now
            .difference(status.startTimestamp.v!.toDateTime())
            .inMilliseconds;
      case quizStatusPaused:
        return status.pausedStartTimestamp.v!
            .toDateTime()
            .difference(
              (status.startTimestamp.v ?? status.pausedStartTimestamp.v)!
                  .toDateTime(),
            )
            .inMilliseconds;
      case quizStatusIdle:
        return 0;
      case quizStatusCancelled:
        return cache.postMsStart;
      default:
        throw StateError('invalid status');
    }
  }();

  @override
  int getQuestionStartTimestampMs(int index) =>
      startTimestampMs + getQuestionStartMs(index);
}

/// Nullable view helpers.
extension QuizPlayerStateNowOrNullExt on QuizPlayerStateNow? {
  /// True if non null and valid.
  bool get isNonNullValid => this?.isValid ?? false;
}

/// The time dependent view of a quiz: pre, question index, post, progress.
abstract class QuizPlayerStateNow {
  /// The state.
  final QuizRunnerState state;

  /// The time.
  final DateTime now;

  /// The status.
  FsQuizStatus get status => state.status;

  /// The timing cache.
  QuizRunnerStateCache get cache => state.cache;

  /// The ms in the quiz (only for status playing or paused).
  int get ms;

  /// True if paused.
  bool get isPaused => status.status.v == quizStatusPaused;

  /// True if playing or paused.
  bool get isPlayingOrPaused {
    return isValid &&
        (status.status.v == quizStatusPlaying ||
            status.status.v == quizStatusPaused);
  }

  /// True if the status exists.
  bool get statusExists => state.statusExists;

  /// True if the quiz exists.
  bool get quizExists => state.quizExists;

  /// True if valid.
  bool get isValid => state.isValid;

  /// True if cancelled (means not valid too).
  bool get isCancelled => state.isCancelled;

  /// True if in the pre step.
  bool get isPre;

  /// True if valid and not cancelled.
  bool get isValidNotCancelled => isValid && !isCancelled;

  /// The pre progress (0 to 1).
  double get preProgress =>
      cache.getElapsedPreMs(ms) / cache.questionMsStarts.first;

  /// True if in the post step.
  bool get isPost;

  /// True if done (ranks computed too).
  bool get isDone => state.isDone;

  /// True if done or archived.
  bool get isDoneOrArchived => state.isDoneOrArchived;

  /// True if not started yet.
  bool get isIdle => state.isIdle;

  /// True if expired.
  bool get isExpired => isPost && cache.isExpired(ms);

  /// True if in the last question.
  bool get isLastQuestion => questionIndex == cache.questionCount - 1;

  /// The start in epoch ms, if paused or playing.
  int get startTimestampMs => status.startTimestamp.v!.millisecondsSinceEpoch;

  bool get _hasStartTimestamp => status.startTimestamp.v != null;

  /// The pre step progress controller.
  QuizProgressController get preProgressController {
    if (isIdle || !_hasStartTimestamp) {
      return QuizProgressController(startMs: null, endMs: null);
    }
    var startMs = startTimestampMs;
    var endMs = startMs + getPreDurationMs();
    return QuizProgressController(
      startMs: startMs,
      endMs: endMs,
      pausedMs: isPaused
          ? status.pausedStartTimestamp.v!.millisecondsSinceEpoch
          : null,
    );
  }

  /// The quiz id.
  String get quizId => cache.quiz.id;

  /// True for a gd quiz.
  bool get isTypeGd => cache.quiz.isTypeGd;

  /// The progress controller of a question.
  QuizProgressController getQuestionProgressController(int questionIndex) {
    var startMs = getQuestionStartTimestampMs(questionIndex);
    var durationMs = getQuestionAnswerDurationMs(questionIndex);
    var endMs = startMs + durationMs;
    return QuizProgressController(
      startMs: startMs,
      endMs: endMs,
      pausedMs: isPaused
          ? status.pausedStartTimestamp.v!.millisecondsSinceEpoch
          : null,
    );
  }

  /// The progress controller of the pause after a question.
  QuizProgressController getQuestionPostProgressController(int questionIndex) {
    var startMs = getQuestionEndTimestampMs(questionIndex);
    var durationMs = getQuestionPauseDurationMs(questionIndex);
    var endMs = startMs + durationMs;
    return QuizProgressController(
      startMs: startMs,
      endMs: endMs,
      pausedMs: isPaused
          ? status.pausedStartTimestamp.v!.millisecondsSinceEpoch
          : null,
    );
  }

  /// The progress (0 to 1) of a question.
  double getQuestionProgress(int index) {
    var total = getQuestionAnswerDurationMs(index);
    var progress = getQuestionAnswerElapsedMs(index);
    return progress / total;
  }

  /// Only if isPost, ms after the end.
  int getPostMs() => cache.getPostMs(ms);

  /// Only if isPre, ms before the first question.
  int getRemainingPreMs() => cache.getRemainingPreMs(ms);

  /// The elapsed pre ms.
  int getElapsedPreMs() => cache.getElapsedPreMs(ms);

  /// The pre duration.
  int getPreDurationMs() => cache.getPreDurationMs();

  /// The answer duration of a question.
  int getQuestionAnswerDurationMs(int index) {
    return cache.getQuestionAnswerDurationMs(index);
  }

  /// The answer plus pause duration of a question.
  int getQuestionTotalDurationMs(int index) {
    return cache.getQuestionAnswerDurationMs(index) +
        cache.getQuestionPauseDurationMs(index);
  }

  /// The remaining answer plus pause time of a question.
  int getQuestionTotalRemainingMs(int index) {
    return getQuestionTotalDurationMs(index) -
        getQuestionAnswerElapsedMs(index);
  }

  /// The pause duration after a question.
  int getQuestionPauseDurationMs(int index) {
    return cache.getQuestionPauseDurationMs(index);
  }

  /// The remaining answer time, negative during the pause.
  int getQuestionAnswerRemainingMs(int index) {
    return cache.getQuestionAnswerRemainingMs(index, ms);
  }

  /// The elapsed time since the question start.
  int getQuestionAnswerElapsedMs(int index) {
    return cache.getQuestionAnswerElapsedMs(index, ms);
  }

  /// The remaining pause time after a question.
  int getQuestionPauseRemainingMs(int index) {
    return cache.getQuestionPauseRemainingMs(index, ms);
  }

  /// The question index, null if not in a question.
  int? get questionIndex =>
      isValidNotCancelled ? cache.questionIndex(ms) : null;

  /// Creates the view.
  QuizPlayerStateNow({required this.state, required this.now});

  @override
  String toString() {
    if (isPre) {
      return 'pre ${getRemainingPreMs()}';
    } else if (isPost) {
      return 'post ${getPostMs()}';
    } else if (isCancelled) {
      return 'cancelled';
    } else {
      return 'index $questionIndex';
    }
  }

  /// The question start in ms from the quiz start.
  int getQuestionStartMs(int index) => cache.getQuestionStartMs(index);

  /// The question start in epoch ms.
  int getQuestionStartTimestampMs(int index);

  /// The question end in epoch ms.
  int getQuestionEndTimestampMs(int index) =>
      getQuestionStartTimestampMs(index) + getQuestionAnswerDurationMs(index);

  /// The current question (if [questionIndex] is not null).
  CvQuizEncodedQuestion getQuestion() => getQuestionAt(questionIndex!);

  /// The question count.
  int get questionCount;

  /// The question at [questionIndex].
  CvQuizEncodedQuestion getQuestionAt(int questionIndex);
}

/// The time dependent view of a gd quiz.
class QuizPlayerStateNowGd extends QuizPlayerStateNow {
  /// The gd state.
  QuizRunnerStateGd get stateGd => state as QuizRunnerStateGd;

  /// Creates the view.
  QuizPlayerStateNowGd({required super.state, required super.now});

  @override
  int? get questionIndex => stateGd.questionIndex;

  @override
  int get questionCount => stateGd.questionCount;

  @override
  CvQuizEncodedQuestion getQuestionAt(int questionIndex) =>
      stateGd.questions[questionIndex];

  @override
  bool get isPost => questionIndex == null;

  @override
  bool get isExpired => !isValid;

  /// The ms in the quiz (only for status playing or paused).
  @override
  late final int ms = () {
    if (stateGd.localStatus.startTimestamp.isNull) {
      return 0;
    }
    return now
        .difference(
          Timestamp.parse(stateGd.localStatus.startTimestamp.v!).toDateTime(),
        )
        .inMilliseconds;
  }();

  @override
  int getQuestionStartTimestampMs(int index) =>
      stateGd.localStatus
          .findAnswerByQuestionId(
            stateGd.localCopy.questions.v![index].questionId.v!,
          )
          ?.startMs
          .v ??
      Timestamp.tryAnyAsTimestamp(
        stateGd.localStatus.startTimestamp.v,
      )!.millisecondsSinceEpoch;

  @override
  bool get isPre => false;
}

/// The admin (controller) side of a quiz.
class AdminQuizPlayerController extends QuizPlayerController {
  /// Creates the controller.
  AdminQuizPlayerController({
    required super.databaseService,
    required super.quizId,
    required super.prefs,
    required super.controllerId,
    super.apiClient,
    super.timeService,
    super.avatars,
  });
}

/// The state of the score computation at the end of a quiz.
class ScoreComputerControllerState {
  /// True once no new player is received.
  final bool? waitingForNewPlayersDone;

  /// True once the validation delay is over.
  final bool? waitingForValidationDone;

  /// The last time a score was received.
  final DateTime? lastReceivedScoreDateTime;

  /// The last player count.
  final int? lastReceivedPlayerCount;

  /// Creates the state.
  ScoreComputerControllerState({
    this.lastReceivedPlayerCount,
    this.lastReceivedScoreDateTime,
    this.waitingForNewPlayersDone,
    this.waitingForValidationDone,
  });

  /// Copies the state.
  ScoreComputerControllerState copyWith({
    int? lastReceivedPlayerCount,
    DateTime? lastReceivedScoreDateTime,
    bool? waitingForNewPlayersDone,
    bool? waitingForValidationDone,
  }) => ScoreComputerControllerState(
    lastReceivedPlayerCount:
        lastReceivedPlayerCount ?? this.lastReceivedPlayerCount,
    lastReceivedScoreDateTime:
        lastReceivedScoreDateTime ?? this.lastReceivedScoreDateTime,
    waitingForNewPlayersDone:
        waitingForNewPlayersDone ?? this.waitingForNewPlayersDone,
    waitingForValidationDone:
        waitingForValidationDone ?? this.waitingForValidationDone,
  );

  @override
  String toString() => {
    if (lastReceivedPlayerCount != null)
      'lastReceivedPlayerCount': lastReceivedPlayerCount,
    if (lastReceivedScoreDateTime != null)
      'lastReceivedScoreDateTime': lastReceivedScoreDateTime,
    if (waitingForNewPlayersDone != null)
      'waitingForNewPlayersDone': waitingForNewPlayersDone,
    if (waitingForValidationDone != null)
      'waitingForValidationDone': waitingForValidationDone,
  }.toString();
}

/// The rank of the player once computed (tv).
class SendResultControllerStateRank extends SendResultControllerState {
  /// The rank.
  final int rank;

  /// The player count.
  final int count;

  /// Creates the state.
  SendResultControllerStateRank(this.rank, this.count);

  @override
  String toString() => 'rank: $rank, count: $count';
}

/// What a gd player won.
class WonData {
  /// The goodie id, null if nothing.
  final String? won;

  /// The goodie text.
  final CvLocalizedText? wonText;

  /// When.
  final Timestamp wonTimestamp;

  /// Creates the data.
  WonData(this.won, this.wonText, this.wonTimestamp);

  @override
  String toString() =>
      'WonData{won: $won ($wonText), wonTimestamp: $wonTimestamp}';
}

/// The goodie result of the player (gd).
class SendResultControllerStateWon extends SendResultControllerState {
  /// The data.
  final WonData wonData;

  /// Creates the state.
  SendResultControllerStateWon(this.wonData);

  @override
  String toString() => 'won: $wonData';
}

/// The state of the result sending.
abstract class SendResultControllerState {}

/// The result has been sent.
class SendResultControllerStateInitial extends SendResultControllerState {
  /// The player id.
  final String playerId;

  /// Creates the state.
  SendResultControllerStateInitial({required this.playerId});

  @override
  String toString() => 'playerId: $playerId';
}

/// Sends the player result and follows its rank (tv) or goodie (gd).
class SendResultController {
  /// The database.
  QuizzFirestoreDatabase get databaseService =>
      quizPlayerController.databaseService;

  /// The player controller.
  final QuizPlayerController quizPlayerController;
  final _state = BehaviorSubject<SendResultControllerState>();

  /// The state.
  ValueStream<SendResultControllerState> get state => _state.stream;

  QuizzTimeService get _timeService => quizPlayerController.timeService;

  /// The quiz id.
  String get quizId => quizPlayerController.quizId;

  /// Creates the controller.
  SendResultController(this.quizPlayerController);

  StreamSubscription? _playerSubscription;

  String? _playerSubscriptionId;

  // Set when sending results
  String? _quizType;
  late String _sessionId;

  /// Disposes the controller.
  void dispose() {
    _playerSubscription?.cancel();
    _state.close();
  }

  void _subscribePlayer(String? playerId) {
    if (playerId == null) {
      _playerSubscriptionId = null;
      _playerSubscription?.cancel();
    } else {
      if (playerId != _playerSubscriptionId) {
        _playerSubscription?.cancel();
      }
      _playerSubscriptionId = playerId;

      if (_quizType == quizTypeGd) {
        var options = TrackChangesPullOptions(
          refreshDelay: const Duration(seconds: 1),
        );
        _playerSubscription =
            streamJoin2(
              databaseService
                  .fsSessionGoodiesConfig(_sessionId)
                  .onSnapshotSupport(
                    quizPlayerController.firestore,
                    options: options,
                  ),
              databaseService
                  .fsGdQuizPlayer(_sessionId, playerId)
                  .onSnapshotSupport(
                    quizPlayerController.firestore,
                    options: options,
                  ),
            ).listen((event) {
              var config = event.$1;
              var player = event.$2;
              var quizPlayer = player;
              if (quizPlayer.exists) {
                /// won is set right away
                var won = quizPlayer.won.v;
                var wonTimestamp = quizPlayer.timestamp.v ?? Timestamp.now();
                var wonData = WonData(
                  won,
                  config.goodies.v
                      ?.where((element) => element.id.v == won)
                      .firstOrNull
                      ?.text
                      .v,
                  wonTimestamp,
                );

                quizPlayerController.prefs.prefsUpdateQuizLocalStatus((
                  localStatus,
                ) {
                  localStatus.won.v = won;
                  localStatus.wonTimestamp.v = quizPlayer.timestamp.v!
                      .toIso8601String();
                });
                _state.add(SendResultControllerStateWon(wonData));
                _playerSubscription?.cancel();
              }
            });
      } else {
        _playerSubscription =
            streamJoin2(
              quizPlayerController.databaseService
                  .fsQuizPlayer(quizId, playerId)
                  .onSnapshot(quizPlayerController.firestore),
              quizPlayerController.databaseService
                  .fsQuizInfoStatus(quizId)
                  .onSnapshot(quizPlayerController.firestore),
            ).listen((event) {
              var quizPlayer = event.$1;
              var status = event.$2;

              if (quizPlayer.exists && status.exists) {
                var rank = quizPlayer.rank.v;
                var count = status.playersCount.v;
                var validity = quizPlayer.validity.v;

                // If valid, this should no longer works as ranking is only
                // computer for the first 3 players
                if (rank != null && count != null) {
                  if (validity != quizPlayerValidityInvalid) {
                    quizPlayerController.prefs.prefsUpdateQuizLocalStatus((
                      current,
                    ) {
                      current.rank.v = rank;
                      current.playerCount.v = count;
                    });
                    _state.add(SendResultControllerStateRank(rank, count));
                  }
                }
              }
            });
      }
    }
  }

  /// Sends the results if not sent yet (or [force]d), then follows the
  /// player document.
  Future<void> sendResults({bool force = false}) async {
    var current = quizPlayerController.prefs.prefsGetQuizLocalStatus();
    if (current != null) {
      bool shouldSendResult() {
        return force ||
            (current?.quizId.v == quizId &&
                current?.resultsSentPlayerId.v == null);
      }

      if (shouldSendResult()) {
        await _playerScoreLock.synchronized(() async {
          current = quizPlayerController.prefs.prefsGetQuizLocalStatus();
          if (shouldSendResult()) {
            var stateNow = quizPlayerController.stateValue.now(
              _timeService.timestamp,
            );
            // Check timing, tool late if resuts computation is done
            _quizType = current?.quizType.v;
            _sessionId = current?.sessionId.v ?? sessionIdMain;

            if (force ||
                (!stateNow.isDone &&
                    (stateNow.isPost || stateNow.isLastQuestion))) {
              // Try for 30s only
              if (force || stateNow.getPostMs() < 30000) {
                var playerId = await doSendResults(current!);
                if (playerId != null) {
                  _state.add(
                    SendResultControllerStateInitial(playerId: playerId),
                  );
                }

                quizPlayerController.prefs.prefsUpdateQuizLocalStatus((status) {
                  status.resultsSentPlayerId.v = playerId;
                });
                if (playerId != null) {
                  _subscribePlayer(playerId);
                }
              }
            }
          }
        });
      } else {
        var playerId = current.resultsSentPlayerId.v;
        _quizType = current.quizType.v;
        _sessionId = current.sessionId.v ?? sessionIdMain;
        if (playerId != null) {
          _state.add(SendResultControllerStateInitial(playerId: playerId));

          if (current.rank.isNull) {
            _subscribePlayer(current.resultsSentPlayerId.v);
          }
        }
      }
    }
  }

  /// The api query of a local status.
  ApiQuizzSendResultQuery resultFromLocalStatus(PrefsQuizLocalStatus status) {
    var quizType = status.quizType.v;
    var resultRequest = ApiQuizzSendResultQuery()
      ..quizType.v = quizType
      // TV
      ..username.setValue(status.username.v)
      ..avatar.setValue(status.avatar.v)
      // GD only
      ..localDeviceId.setValue(status.deviceId.v)
      // Common
      ..quizId.v = status.quizId.v
      ..sessionId.v = status.sessionId.v
      ..answers.v = status.toApiAnswers()
      ..localTimestamp.v = _timeService.timestamp.toIso8601String()
      ..localDeviceId.v = status.deviceId.v;

    if (quizType == quizTypeGd) {
      resultRequest.winningCount.setValue(status.winningCount.v);
    }
    return resultRequest;
  }

  /// Sends the results through the api, returning the player id.
  @protected
  Future<String?> doSendResults(PrefsQuizLocalStatus status) async {
    await _timeService.fixedOnce;
    var resultRequest = resultFromLocalStatus(status);

    var response = await quizPlayerController.apiClient.sendQuizResult(
      resultRequest,
    );

    var playerId = response.playerId.v ?? status.resultsSentPlayerId.v;
    status.resultsSentPlayerId.v = playerId;
    return playerId;
  }
}

/// Waits for the players results and their validation at the end of a quiz.
class ScoreComputerController {
  /// The database.
  final QuizzFirestoreDatabase databaseService;

  /// The controller id.
  final String controllerId;

  /// The state.
  ValueStream<ScoreComputerControllerState> get stateValueStream =>
      _stateValueSubject;
  final _stateValueSubject =
      BehaviorSubject<ScoreComputerControllerState>.seeded(
        ScoreComputerControllerState(
          lastReceivedScoreDateTime: null,
          waitingForNewPlayersDone: null,
        ),
      );

  /// Creates the controller.
  ScoreComputerController(this.databaseService, {required this.controllerId});

  /// Waits for [noNewPlayerDuration] (5s) without a new player, or
  /// [noPlayerDuration] (30s) without any player.
  Future<void> waitForPlayerResults({
    required String quizId,
    Duration? noNewPlayerDuration,
    Duration? noPlayerDuration,
    int? sleepStepMs,
  }) async {
    noNewPlayerDuration ??= const Duration(seconds: 5);
    noPlayerDuration ??= const Duration(seconds: 30);
    sleepStepMs ??= 1000;
    var sw = Stopwatch()..start();
    int? lastReadPlayerMs;
    int? lastReadPlayerCount;

    while (true) {
      await sleep(min(sleepStepMs, noNewPlayerDuration.inMilliseconds));
      try {
        var startNowMs = sw.elapsedMilliseconds;
        if (isDebug) {
          // ignore: avoid_print
          print(
            'waiting for new players $startNowMs / $lastReadPlayerMs${lastReadPlayerCount != null ? ', participants ${lastReadPlayerCount.toString()}' : ''}',
          );
        }

        await databaseService.writeAndWaitControllerOnline(
          quizId: quizId,
          controllerId: controllerId,
        );
        var playerCount = await databaseService.quizCountPlayers(quizId);
        var nowMs = sw.elapsedMilliseconds;

        if (lastReadPlayerMs == null || (lastReadPlayerCount != playerCount)) {
          lastReadPlayerCount = playerCount;
          lastReadPlayerMs = nowMs; // Take the latest

          _stateValueSubject.add(
            _stateValueSubject.value.copyWith(
              lastReceivedPlayerCount: lastReadPlayerCount,
              lastReceivedScoreDateTime: DateTime.now(),
            ),
          );

          continue;
        } else {
          var elapsed = startNowMs - lastReadPlayerMs;
          if (elapsed >
              (playerCount == 0
                  ? noPlayerDuration.inMilliseconds
                  : noNewPlayerDuration.inMilliseconds)) {
            // Ok
            break;
          }
        }
      } catch (e) {
        // ignore: avoid_print
        print('error $e waiting for new players');
      }
    }
    if (!disposed) {
      _stateValueSubject.add(
        _stateValueSubject.value.copyWith(waitingForNewPlayersDone: true),
      );
    }
  }

  /// Waits for the 3 first players to be validated, at most [timeout] (30s).
  Future<void> waitForPlayersValidation({
    required String quizId,
    Duration? timeout,
  }) async {
    try {
      timeout ??= const Duration(seconds: 30);
      var sw = Stopwatch()..start();
      var valid = false;
      while (sw.elapsed.compareTo(timeout) < 0) {
        await sleep(min(1000, timeout.inMilliseconds));
        var limit = 3;
        var players = await databaseService.getOrderedPlayers(
          quizId: quizId,
          limit: limit,
        );
        valid = true;
        for (var player in players) {
          if (player.validity.v != quizPlayerValidityValid) {
            valid = false;
            break;
          }
        }
        if (valid) {
          break;
        }
      }
      if (!disposed) {
        _stateValueSubject.add(
          _stateValueSubject.value.copyWith(waitingForValidationDone: true),
        );
        if (!valid) {
          throw TimeoutException('Not all players are valid in $timeout');
        }
      }
    } catch (e) {
      if (isDebug) {
        // ignore: avoid_print
        print('Waiting for validation error $e');
      }
      rethrow;
    }
  }

  /// True once disposed.
  var disposed = false;

  /// Disposes the controller.
  void dispose() {
    disposed = true;
    _stateValueSubject.close();
  }
}

/// The player side of a quiz, in memory prefs (preview).
class UserQuizPlayerPreviewController extends UserQuizPlayerController {
  /// Creates the controller.
  UserQuizPlayerPreviewController({
    required super.databaseService,
    required super.controllerId,
    required super.quizId,
    super.timeService,
  }) : super(apiClient: null, prefs: QuizzPrefsServiceMemory());
}

/// The player side of a quiz.
class UserQuizPlayerController extends QuizPlayerController {
  /// Creates the controller.
  UserQuizPlayerController({
    required super.databaseService,
    required super.controllerId,
    required super.quizId,
    required super.apiClient,
    required super.prefs,
    super.timeService,
  });
}

/// The tv (display) side of a quiz.
class TvQuizPlayerController extends QuizPlayerController {
  /// Creates the controller.
  TvQuizPlayerController({
    required super.databaseService,
    required super.quizId,
    required super.apiClient,
    required super.controllerId,
    super.avatars,
    super.timeService,
  }) : super(prefs: QuizzPrefsServiceMemory());
}

/// The live state of a quiz on a device: follows the quiz and its status in
/// firestore, exposes [stateValueStream], and drives it (start, pause, next,
/// score computation) or plays it (send result).
class QuizPlayerController {
  /// The database.
  late final QuizzFirestoreDatabase databaseService;

  /// The api client if any.
  final QuizzApiClient? apiClientOrNull;

  /// The api client.
  QuizzApiClient get apiClient => apiClientOrNull!;

  /// The local prefs.
  final QuizzPrefsService prefs;

  /// The avatars if any.
  final Avatars? avatars;

  /// Test only: fake players sent when computing the scores.
  int? fakePlayersCount;

  /// The controller id (device id).
  final String controllerId;

  /// The firestore.
  Firestore get firestore => databaseService.firestore;

  /// The quiz id.
  final String quizId;

  /// The question count.
  int get questionCount => _cache!.quiz.questions.v!.length;

  /// The quiz.
  FsQuiz get quiz => _cache!.quiz;
  StreamSubscription? _subscription;
  StreamSubscription? _statusSubscription;
  QuizRunnerStateCache? _cache;
  FsQuizStatus? _status;

  /// The time service, local when none is given.
  final QuizzTimeService timeService;
  final _stateController = BehaviorSubject<QuizRunnerState>();

  /// The state stream.
  ValueStream<QuizRunnerState> get stateValueStream => _stateController.stream;

  /// The current state.
  QuizRunnerState get stateValue => _stateController.value;

  /// The current state, null if none yet.
  QuizRunnerState? get stateValueOrNull => _stateController.valueOrNull;

  /// The time dependent view of the current state, null if none yet.
  QuizPlayerStateNow? get stateNowOrNull =>
      stateValueOrNull?.now(timeService.timestamp);

  var _initialStateDone = false;
  var _isTypeGd = false;

  void _updateState() {
    if (_cache == null || _status == null) {
      return;
    }

    if (!_initialStateDone) {
      _initialStateDone = true;
      var quiz = _cache!.quiz;

      _isTypeGd = quiz.isTypeGd;
      if (_isTypeGd) {
        var localStatus = prefs.prefsGetOrCreateQuizLocalStatus(quizId: quizId);
        var localCopy = prefs.prefsGetOrCreateQuizLocalCopy(quizId: quizId);
        // Init
        if (localCopy.questions.isNull || localStatus.startTimestamp.isNull) {
          var questions = List<CvQuizEncodedQuestion>.from(quiz.questions.v!);

          /// Pick random questions
          var questionCount = min(
            quiz.questionCount.v ?? quizConfigQuestionCountDefault,
            questions.length,
          );
          questions = (questions..shuffle()).take(questionCount).toList();

          prefs.prefsUpdateQuizLocalStatus((status) {
            status
              ..sessionId.v = quiz.sessionId.v
              ..deviceId.v = controllerId;
            status.quizType.v = quiz.type.v;
            // Never null
            status.winningCount.v =
                quiz.questionWinningCount.v ?? questionCount;
            status.startTimestamp.v ??= timeService.timestamp.toIso8601String();
            status.answers.v = List<CvPrefsQuizPlayerAnswer>.generate(
              questionCount,
              (i) =>
                  CvPrefsQuizPlayerAnswer()
                    ..questionId.v = questions[i].questionId.v,
            );
          });

          prefs.prefsUpdateQuizLocalCopy((localCopy) {
            localCopy.questions.v = questions;
            localCopy.quizType.v = quiz.type.v;
            localCopy.uid.v = quiz.uid.v;
          });
        }
        // Only read once for gd
        _statusSubscription?.cancel();
        _statusSubscription = null;
      }
    } else {
      var localStatus = prefs.prefsGetOrCreateQuizLocalStatus(quizId: quizId);
      if (localStatus.sessionId.isNull) {
        // Copy from firestore to prefs
        prefs.prefsUpdateQuizLocalStatus((status) {
          status
            ..sessionId.v = quiz.sessionId.v
            ..deviceId.v = controllerId
            ..quizType.v = quiz.type.v;
        });
      }
    }

    var state = _isTypeGd
        ? QuizRunnerStateGd(
            _cache!,
            _status!,
            localStatus: prefs.prefsGetQuizLocalStatus(),
            localCopy: prefs.prefsGetQuizLocalCopy(),
          )
        : QuizRunnerStateTv(_cache!, _status!);

    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  /// Creates the controller and starts following the quiz.
  QuizPlayerController({
    required QuizzFirestoreDatabase? databaseService,
    required this.controllerId,
    required QuizzApiClient? apiClient,
    QuizzTimeService? timeService,
    required this.quizId,
    required this.prefs,
    this.avatars,
  }) : apiClientOrNull = apiClient,
       timeService = timeService ?? QuizzTimeService.local() {
    initQuizzApiBuilders();
    if (databaseService != null) {
      this.databaseService = databaseService;

      // Look in prefs first for gd
      var localCopy = prefs.prefsGetQuizLocalCopy();
      var localStatus = prefs.prefsGetQuizLocalStatus();
      if (localCopy?.quizId.v == quizId &&
          localStatus?.quizId.v == quizId &&
          localStatus!.quizType.v == localCopy!.quizType.v) {
        // No firestore needed here
        var quizType = localStatus.quizType.v;
        if (quizType == quizTypeGd) {
          _isTypeGd = true;
          _cache = QuizRunnerStateCacheGd(quiz: FsQuiz()..type.v = quizType);
          _status = FsQuizStatus();
          _updateState();
          return;
        }
      }

      _subscription = databaseService
          .fsQuiz(quizId)
          .onSnapshotSupport(
            firestore,
            options: TrackChangesPullOptions(
              refreshDelay: const Duration(milliseconds: 10000),
            ),
          )
          .listen((quiz) {
            _cache = QuizRunnerStateCache.typed(quiz: quiz);
            _updateState();
          });
      _statusSubscription = databaseService
          .fsQuizInfoStatus(quizId)
          .onSnapshotSupport(
            firestore,
            options: TrackChangesPullOptions(
              refreshDelay: const Duration(milliseconds: 3000),
            ),
          )
          .listen((quizStatus) {
            _status = quizStatus;
            _updateState();
          });
    }
  }

  /// Disposes the controller.
  void dispose() {
    _subscription?.cancel();
    _statusSubscription?.cancel();
    _scoreComputerController?.dispose();
    _sendResultController?.dispose();
    _stateController.close();
  }

  ScoreComputerController? _scoreComputerController;
  SendResultController? _sendResultController;

  /// The score computation state, once started.
  ValueStream<ScoreComputerControllerState>?
  get scoreComputerStateValueStream =>
      _scoreComputerController?.stateValueStream;

  /// The result sending state, once started.
  ValueStream<SendResultControllerState>? get sendResultStateValueStream =>
      _sendResultController?.state;

  /// Test: sends a random player result.
  Future<void> sendRandomPlayer() async {
    var randomPlayer = generateRandomPlayer(quiz: quiz);
    await apiClient.sendQuizResult(randomPlayer);
  }

  /// Waits for the results (and their validation unless [auto]) then
  /// computes the ranks and marks the quiz as done. [force] skips the waits.
  ValueStream<ScoreComputerControllerState> waitAndComputePlayerRanks(
    DateTime now, {
    bool auto = false,
    bool force = false,
  }) {
    if (_scoreComputerController != null && !force) {
      return _scoreComputerController!.stateValueStream;
    }
    var controller = _scoreComputerController = ScoreComputerController(
      databaseService,
      controllerId: controllerId,
    );

    () async {
      // Test only, add fake players
      if (fakePlayersCount != null) {
        () async {
          // Wait for quiz to be fetched once
          await stateValueStream.first;

          var count = fakePlayersCount!;
          var randomPlayers = generateRandomPlayers(
            count,
            quiz: quiz,
            avatars: avatars?.avatars.toList(),
          );
          var index = 0;

          for (var chunk in listChunk(randomPlayers, 10)) {
            var futures = <Future<Object?>>[];
            for (var player in chunk) {
              if (isDebug) {
                // ignore: avoid_print
                print('sending fake player ${++index} ${player.username.v}');
              }
              var future = apiClient.sendQuizResult(player);
              futures.add(future);
            }
            await Future.wait(futures);
          }
        }().unawait();
      }
      await _computeScoreLock.synchronized(() async {
        var status = await databaseService
            .fsQuizInfoStatus(quizId)
            .get(firestore);
        if (status.isDoneOrArchived) {
          if (!force) {
            return;
          }
        }
        if (!force) {
          await controller.waitForPlayerResults(
            quizId: quizId,
            noNewPlayerDuration: const Duration(seconds: 5),
          );
        }

        if (!auto && !force) {
          var validationDelayMs =
              quiz.validationDelayMs.v ?? quizConfigValidationDelayMsDefault;

          try {
            await controller.waitForPlayersValidation(
              quizId: quizId,
              timeout: Duration(milliseconds: validationDelayMs),
            );
          } catch (e) {
            if (isDebug) {
              // ignore: avoid_print
              print('Error in waiting for players validation');
            }
          }

          // If not main controller, pause
          if (!force && !auto) {
            var waitMs = isDebug ? 5000 : 30000;
            if (controller.controllerId != status.controllerId.v) {
              await sleep(waitMs);
            }
          }
        }

        var count = await controller.databaseService.computePlayersRanks(
          quizId: quizId,
        );
        await databaseService.quizUpdatePlayerCountAndMarkAsDone(quizId, count);
      });
    }();

    return controller.stateValueStream;
  }

  /// Cancels the quiz.
  Future<void> cancelQuiz() async {
    await databaseService.cancelQuiz(quizId: quizId);
  }

  /// Deletes the quiz.
  Future<void> deleteQuiz() async {
    await databaseService.deleteQuiz(quizId);
  }

  /// Validates the 3 first players.
  Future<void> validate3Players() async {
    await databaseService.validatePlayers(quizId: quizId, limit: 3);
  }

  /// Starts the active (idle) quiz at [now].
  Future<void> startActiveQuiz(DateTime now) async {
    await databaseService.startActiveQuiz(quizId: quizId, now: now);
  }

  /// Pauses or resumes the quiz.
  Future<void> togglePauseResume() async {
    var now = timeService.timestamp;
    await databaseService.togglePauseResumeQuiz(quizId: quizId, now: now);
  }

  /// Sends the player result (once), following its rank or goodie.
  ValueStream<SendResultControllerState> sendResult(
    DateTime now, {
    bool force = false,
  }) {
    if (_sendResultController != null && !force) {
      return _sendResultController!.state;
    }
    _sendResultController?.dispose();
    var controller = _sendResultController = SendResultController(this);
    () async {
      await _sendResultController!.sendResults(force: force);
    }();

    return controller.state;
  }

  /// True if the quiz can be paused or navigated (not post, not idle).
  bool canPauseOrNavigate(QuizPlayerStateNow stateNow) {
    return (!stateNow.isPost && !stateNow.isIdle);
  }

  /// Pauses the quiz at [now].
  void pause(DateTime now) {
    var stateNow = stateValueStream.value.now(now);
    // Can't pause once in post mode
    if (canPauseOrNavigate(stateNow)) {
      databaseService.pauseQuiz(quizId: quizId, now: now);
    }
  }

  /// Resumes the quiz at [now].
  void resume(DateTime now) {
    databaseService.resumeQuiz(quizId: quizId, now: now);
  }

  Future<void> _quizOffset(int offsetMs) async {
    _status = await databaseService.quizOffset(
      quizId: quizId,
      ms: offsetMs,
      quizStatus: _status,
    );
    _updateState();
  }

  /// Goes to the previous question (or restarts the current one).
  Future<void> previous(DateTime now) async {
    var stateNow = stateValueStream.value.now(now);
    // Can't navigate once in post mode
    if (!canPauseOrNavigate(stateNow)) {
      return;
    }
    var index = stateNow.questionIndex;
    if (index != null) {
      var questionRemainingMs = stateNow.getQuestionAnswerRemainingMs(index);
      if (questionRemainingMs > 0) {
        if (index == 0) {
          // Go to start!
          await _quizOffset(-stateNow.ms);
        } else {
          // Go previous
          await _quizOffset(
            -stateNow.getQuestionAnswerElapsedMs(index) -
                stateNow.getQuestionTotalDurationMs(index - 1),
          );
        }
      } else {
        // Go to the same question
        await _quizOffset(-stateNow.getQuestionAnswerElapsedMs(index));
      }
    }
    if (stateNow.isPost) {
      // Go to the last question
      await _quizOffset(
        -stateNow.getPostMs() -
            stateNow.getQuestionTotalDurationMs(questionCount - 1),
      );
    } else if (stateNow.isPre) {
      // Go to the start
      await _quizOffset(-stateNow.getElapsedPreMs());
    }
  }

  /// Goes to the next question.
  Future<void> next(DateTime now) async {
    var stateNow = stateValueStream.value.now(now);
    // Can't navigate once in post mode
    if (!canPauseOrNavigate(stateNow)) {
      return;
    }
    var index = stateNow.questionIndex;
    if (index != null) {
      // Go to next
      await _quizOffset(stateNow.getQuestionTotalRemainingMs(index));
    }
    if (stateNow.isPre) {
      // Go to the first question
      await _quizOffset(stateNow.getRemainingPreMs());
    }
  }

  /// Starts the quiz at [now] with [controllerId] as its controller.
  Future<void> startQuiz({
    required String controllerId,
    required DateTime now,
  }) async {
    await databaseService.startQuiz(
      quizId: quizId,
      controllerId: controllerId,
      now: now,
    );
  }
}

final _computeScoreLock = Lock();
final _playerScoreLock = Lock();

/// Generates [count] random player results.
List<ApiQuizzSendResultQuery> generateRandomPlayers(
  int count, {
  List<Avatar>? avatars,
  required FsQuiz quiz,
}) {
  var random = Random(DateTime.now().millisecondsSinceEpoch);
  return List.generate(
    count,
    (index) =>
        generateRandomPlayer(quiz: quiz, avatars: avatars, random: random),
  );
}

/// Generates a random player result.
ApiQuizzSendResultQuery generateRandomPlayer({
  List<Avatar>? avatars,
  required FsQuiz quiz,
  Random? random,
}) {
  random ??= Random(DateTime.now().millisecondsSinceEpoch);
  var username = 'player${random.nextInt(1000)}';
  String avatar;
  if (avatars != null && avatars.isNotEmpty) {
    avatar = avatars[random.nextInt(avatars.length)].name;
  } else {
    avatar = 'avatar${random.nextInt(1000)}';
  }
  var result = ApiQuizzSendResultQuery()
    ..localTimestamp.v = Timestamp.now().toIso8601String()
    ..sessionId.v = quiz.sessionId.v
    ..quizType.v = quiz.type.v
    ..username.v = username
    ..avatar.v = avatar
    ..quizId.v = quiz.id
    ..answers.v = quiz.questions.v
        ?.map((question) {
          var tooLate = random!.nextInt(100) > 90;
          if (!tooLate) {
            var possibleAnswers = question.answers.v;
            if (possibleAnswers?.isNotEmpty == true) {
              var answer = CvQuizPlayerAnswer()
                ..questionId.v = question.questionId.v
                ..elapsedMs.v = random.nextInt(
                  (quiz.answerDelayMsOrDefault * 1.10).round(),
                )
                ..answerId.v =
                    possibleAnswers![random.nextInt(possibleAnswers.length)]
                        .id
                        .v;
              return answer;
            }
          }
          return null;
        })
        .nonNulls
        .toList();
  return result;
}
