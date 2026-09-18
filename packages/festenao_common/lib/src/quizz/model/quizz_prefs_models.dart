import '../import.dart';
import '../quizz_constant.dart';
import 'quizz_api_models.dart';
import 'quizz_fs_models.dart';

var _builderInitialized = false;

/// Registers the local (prefs) quizz models (idempotent).
void initQuizzPrefsBuilders() {
  if (_builderInitialized) {
    return;
  }
  _builderInitialized = true;
  initQuizzApiBuilders();
  cvAddConstructors([
    PrefsQuizLocalStatus.new,
    PrefsQuizLocalCopy.new,
    CvPrefsQuizPlayerAnswer.new,
  ]);
}

/// The local copy of a quiz (gd): the questions picked for this device.
class PrefsQuizLocalCopy extends CvModelBase
    with QuizConfigMixin, CvQuizWithQuestionsMixin {
  @override
  final uid = CvField<String>('uid');

  /// The quiz id.
  final quizId = CvField<String>('quizId');

  /// The quiz type.
  final quizType = CvField<String>('quizType');
  @override
  final questions = CvModelListField<CvQuizEncodedQuestion>('questions');

  @override
  Map<String, Object?> toMap({
    List<String>? columns,
    bool includeMissingValue = false,
  }) {
    prepareQuestionsToMap();
    return super.toMap(
      columns: columns,
      includeMissingValue: includeMissingValue,
    );
  }

  @override
  void fromMap(Map map, {List<String>? columns}) {
    super.fromMap(map, columns: columns);
    prepareQuestionsFromMap();
  }

  @override
  List<CvField<Object?>> get fields => [
    uid,
    quizId,
    quizType,
    ...quizQuestionsMixinFields,
    ...quizConfigMixinFields,
  ];
}

/// A local player answer.
class CvPrefsQuizPlayerAnswer extends CvModelBase {
  /// The question id.
  late final questionId = CvField<String>('questionId');

  /// The answer id, null if not answered.
  late final answerId = CvField<String>('answerId');

  /// The time taken to answer.
  late final elapsedMs = CvField<int>('elapsedMs');

  /// The question start (gd only).
  late final startMs = CvField<int>('startMs');

  /// True if correct (gd only).
  late final correct = CvField<bool>('correct');

  @override
  late final fields = [questionId, answerId, elapsedMs, correct, startMs];
}

/// The local status of the player in a quiz: registration, answers, sent
/// result and rank.
class PrefsQuizLocalStatus extends CvModelBase {
  /// The quiz id.
  final quizId = CvField<String>('quizId');

  /// The session id.
  final sessionId = CvField<String>('sessionId');

  /// The quiz type.
  final quizType = CvField<String>('quizType');

  /// The player name.
  final username = CvField<String>('username');

  /// The player avatar.
  final avatar = CvField<String>('avatar');

  /// The answers.
  late final answers = CvModelListField<CvPrefsQuizPlayerAnswer>('answers');

  /// The player id once the results are sent.
  final resultsSentPlayerId = CvField<String>('playerId');

  /// The rank once computed.
  final rank = CvField<int>('rank');

  /// The player count once computed.
  final playerCount = CvField<int>('playerCount');

  /// The selected language.
  final lang = CvField<String>('lang');

  /// The questions with their correct answers, saved locally when done.
  final questions = CvModelListField<CvQuestion>('questions');

  /// The goodie won (gd).
  final won = CvField<String>('won');

  /// The goodie label (gd).
  final wonText = CvModelField<CvLocalizedText>('wonText');

  /// The winning count (gd only, from the config, optional).
  final winningCount = CvField<int>('winningCount');

  /// The local device id.
  final deviceId = CvField<String>('deviceId');

  /// Local start time, used for gd to compute time.
  final startTimestamp = CvField<String>('startTimestamp');

  /// The player timestamp when won (gd).
  final wonTimestamp = CvField<String>('wonTimestamp');

  @override
  List<CvField<Object?>> get fields => [
    sessionId,
    quizType,
    quizId,
    username,
    avatar,
    answers,
    resultsSentPlayerId,
    rank,
    playerCount,
    lang,
    startTimestamp,
    won,
    wonTimestamp,
    wonText,
    winningCount,
    deviceId,
  ];
}

/// Local status helpers.
extension PrefsQuizLocalStatusExt on PrefsQuizLocalStatus {
  /// Registered once a language and (tv) a username are set.
  bool get isRegistered =>
      isLangSelected && (quizType.v == quizTypeGd || username.isNotNull);

  /// True once a language is selected.
  bool get isLangSelected => lang.isNotNull;

  /// The answer of a question, null if none.
  CvPrefsQuizPlayerAnswer? findAnswerByQuestionId(String questionId) {
    return answers.v?.where((e) => e.questionId.v == questionId).firstOrNull;
  }

  /// The index of the answer of a question, -1 if none.
  int findAnswerIndexQuestionId(String questionId) {
    return answers.v?.indexWhere((e) => e.questionId.v == questionId) ?? -1;
  }

  /// Adds or replaces the answer of a question.
  void addAnswer(CvPrefsQuizPlayerAnswer answer) {
    var index = findAnswerIndexQuestionId(answer.questionId.v!);
    if (index >= 0) {
      answers.v!.removeAt(index);
      answers.v!.insert(index, answer);
    } else {
      (answers.v ??= <CvPrefsQuizPlayerAnswer>[]).add(answer);
    }
  }

  /// The selected answer id of a question, null if none.
  String? getSelectedAnswerId(String questionId) {
    return findAnswerByQuestionId(questionId)?.answerId.v;
  }

  /// The correct answer id of a question (once [questions] is set).
  String? getQuestionCorrectAnswerId(String questionId) {
    return questions.v!
        .firstWhere((question) => question.id.v == questionId)
        .correctAnswerId
        .v;
  }

  /// The score (once [questions] is set).
  int computeScore() {
    var score = 0;
    if (answers.isNotNull) {
      for (var answer in answers.v!) {
        var questionId = answer.questionId.v!;
        var answerId = answer.answerId.v;

        var correctAnswerId = getQuestionCorrectAnswerId(questionId);

        // Correct?
        if (correctAnswerId == answerId && answerId != null) {
          score++;
        }
      }
    }
    return score;
  }

  /// The player answers as api answers.
  List<CvQuizPlayerAnswer> toApiAnswers() =>
      answers.v
          ?.map(
            (e) => CvQuizPlayerAnswer()
              ..elapsedMs.v = e.elapsedMs.v
              ..questionId.v = e.questionId.v
              ..answerId.v = e.answerId.v
              ..correct.v = e.correct.v,
          )
          .toList() ??
      <CvQuizPlayerAnswer>[];
}
