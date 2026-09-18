import '../import.dart';
import '../quizz_constant.dart';
import '../quizz_encrypt.dart';

var _builderInitialized = false;

/// Registers the quizz firestore and cv models (idempotent).
void initQuizzFsBuilders() {
  if (_builderInitialized) {
    return;
  }
  _builderInitialized = true;
  // common
  cvAddConstructors([
    CvLocalizedText.new,
    CvAnswer.new,
    CvQuestion.new,
    CvQuizEncodedQuestion.new,
  ]);

  // firestore
  cvAddConstructors([
    FsQuestion.new,
    FsQuizPlayer.new,
    FsQuiz.new,
    FsQuizConfig.new,
    FsQuizStatus.new,
    FsSession.new,
    FsQuizArchive.new,
    FsQuizController.new,
  ]);
}

/// A text in english and french.
class CvLocalizedText extends CvModelBase {
  /// English.
  late final en = CvField<String>('en');

  /// French.
  late final fr = CvField<String>('fr');

  @override
  late final fields = [en, fr];
}

/// A possible answer of a question.
class CvAnswer extends CvModelBase {
  /// The answer id, unique in the question (`A`, `B`...).
  late final id = CvField<String>('id');

  /// The answer text.
  late final text = CvModelField<CvLocalizedText>('text');

  @override
  late final fields = [id, text];
}

/// The read view of a question: its text, its answers and the correct one.
abstract class CvQuestionRead {
  /// The question text.
  CvModelField<CvLocalizedText> get text;

  /// The possible answers.
  CvModelListField<CvAnswer> get answers;

  /// The correct answer id.
  CvField<String> get correctAnswerId;
}

/// Question helpers.
extension CvQuestionReadExt on CvQuestionRead {
  /// The number of answers.
  int get answerCount => answers.v?.length ?? 0;

  /// The answer at [index].
  CvAnswer getAnswer(int index) {
    return answers.v![index];
  }

  /// The answer with [id].
  CvAnswer getAnswerById(String id) {
    return answers.v!.firstWhere((element) => element.id.v == id);
  }

  /// The answer with [id], null if not found.
  CvAnswer? getAnswerByIdOrNull(String id) {
    return answers.v?.where((element) => element.id.v == id).firstOrNull;
  }
}

/// The common fields of a question (text, answers, tags).
mixin CvQuestionMixin implements CvQuestionRead {
  @override
  late final text = CvModelField<CvLocalizedText>('text');
  @override
  late final answers = CvModelListField<CvAnswer>('answers');

  /// Selection tags.
  late final tags = CvListField<String>('tags');

  /// The mixin fields.
  CvFields get questionMixinFields => <CvField>[text, answers, tags];
}

/// The writable correct answer of a question.
mixin CvQuestionWriteMixin implements CvQuestionRead {
  @override
  late final correctAnswerId = CvField<String>('correctAnswerId');
}

/// A question with a clear correct answer, local copy only (never shared
/// with the players before the end).
class CvQuestion extends CvModelBase with CvQuestionMixin {
  /// The question id.
  late final id = CvField<String>('id');

  @override
  late final correctAnswerId = CvField<String>('correctAnswerId');

  @override
  late final fields = [id, ...questionMixinFields, correctAnswerId];
}

/// The encoded correct answer of a question, as stored in a quiz.
mixin CvQuestionEncodedMixin {
  /// The encrypted correct answer id, see [CvQuizWithQuestionsMixin].
  late final correctAnswerIdEnc = CvField<String>('correctAnswerIdEnc');

  /// Set manually upon decoding, never serialized.
  late final correctAnswerId = CvField<String>('correctAnswerIdEnc');
}

/// A question as stored in a quiz: the correct answer is encrypted with the
/// quiz uid so that a player cannot cheat by reading the quiz document.
class CvQuizEncodedQuestion extends CvModelBase
    with CvQuestionMixin, CvQuestionEncodedMixin {
  /// The question id.
  late final questionId = CvField<String>('id');
  @override
  late final fields = [questionId, ...questionMixinFields, correctAnswerIdEnc];
}

/// The parts of a quiz needed to encode/decode its questions.
abstract class CvQuizWithQuestions {
  /// The questions.
  CvModelListField<CvQuizEncodedQuestion> get questions;

  /// The quiz uid, generated locally, used for correct answer encoding.
  CvField<String> get uid;
}

abstract class _CommonConverter with Converter<String, String> {
  final CvQuizWithQuestions model;

  const _CommonConverter(this.model);
}

class _ToConverter extends _CommonConverter {
  const _ToConverter(super.model);

  @override
  String convert(String input) =>
      quizzModelEncryptionCodec.encode([model.uid.v!, input].join(','));
}

class _FromConverter extends _CommonConverter {
  const _FromConverter(super.mode);

  @override
  String convert(String input) {
    var parts = quizzModelEncryptionCodec.decode(input).split(',');
    if (model.uid.v! != parts[0]) {
      throw ArgumentError('Invalid value');
    }
    return parts[1];
  }
}

/// The codec encrypting the correct answers of a quiz with its uid.
class QuizEncodedCodec with Codec<String, String> {
  /// The quiz.
  final CvQuizWithQuestions quiz;

  /// Creates the codec of [quiz].
  QuizEncodedCodec(this.quiz) {
    encoder = _ToConverter(quiz);
    decoder = _FromConverter(quiz);
  }

  @override
  late final Converter<String, String> decoder;

  @override
  late final Converter<String, String> encoder;
}

/// Encodes the correct answers before `toMap`, decodes them after `fromMap`.
mixin CvQuizWithQuestionsMixin implements CvQuizWithQuestions {
  /// The questions fields.
  late final quizQuestionsMixinFields = <CvField>[questions];

  /// Encrypts the correct answers, to call before `toMap`.
  void prepareQuestionsToMap() {
    if (questions.v?.isNotEmpty ?? false) {
      assert(uid.v != null, 'uid must be set');
    }

    var codec = QuizEncodedCodec(this);

    questions.v?.forEach((question) {
      try {
        question.correctAnswerIdEnc.v = codec.encode(
          question.correctAnswerId.v!,
        );
      } catch (_) {}
    });
  }

  /// Decrypts the correct answers, to call after `fromMap`.
  void prepareQuestionsFromMap() {
    var codec = QuizEncodedCodec(this);

    questions.v?.forEach((question) {
      try {
        question.correctAnswerId.v = codec.decode(
          question.correctAnswerIdEnc.v!,
        );
      } catch (_) {}
    });
  }
}

/// A question in `questions/{id}`.
class FsQuestion extends CvFirestoreDocumentBase
    with CvQuestionMixin, CvQuestionWriteMixin {
  /// Last played timestamp, must not be null as it is used for ordering.
  late final lastPlayedTimestamp = CvField<Timestamp>('lastPlayedTimestamp');

  /// True if disabled (never picked).
  late final disabled = CvField<bool>('disabled');

  @override
  late final fields = [
    ...questionMixinFields,
    correctAnswerId,
    lastPlayedTimestamp,
    disabled,
  ];

  /// The question as stored in a quiz.
  CvQuizEncodedQuestion toEncoded() {
    return CvQuizEncodedQuestion()
      ..questionId.v = id
      ..text.v = text.v
      ..tags.setValue(tags.v)
      ..correctAnswerId.v = correctAnswerId.v
      ..answers.fromCvField(answers);
  }
}

/// The never played timestamp (epoch).
var neverPlayedTimestamp = Timestamp(0, 0);

/// 2000-01-01.
var twoThousandsTimestamp = Timestamp(946684800, 0);

/// The minimum timestamp used for ordering.
var minTimestamp = twoThousandsTimestamp;

/// Field names holder.
final fsQuestionModel = FsQuestion();

/// The status of a quiz in `quizzes/{id}/infos/status`.
///
/// Every app listens to this document, it controls the quiz lifetime. It
/// might not exist.
class FsQuizStatus extends CvFirestoreDocumentBase {
  /// Controller id, managed by the controller, typically a device id.
  late final controllerId = CvField<String>('controllerId');

  /// The quiz status (idle, playing, paused, cancelled, done, archived).
  late final status = CvField<String>('status');

  /// Set when the quiz starts being displayed, could even be in the future
  /// and is shifted when resumed after a pause.
  late final startTimestamp = CvField<Timestamp>('startTimestamp');

  /// Only if paused.
  late final pausedStartTimestamp = CvField<Timestamp>('pausedStartTimestamp');

  /// Only after done.
  late final playersCount = CvField<int>('playersCount');

  /// Only after done.
  late final doneTimestamp = CvField<Timestamp>('doneTimestamp');

  @override
  late final fields = [
    controllerId,
    startTimestamp,
    pausedStartTimestamp,
    status,
    playersCount,
    doneTimestamp,
  ];

  /// True if cancelled.
  bool get isCancelled => status.v == quizStatusCancelled;

  /// True if not started yet.
  bool get isIdle => status.v == quizStatusIdle;

  /// True if paused.
  bool get isPaused => status.v == quizStatusPaused;

  /// True if done (ranking computed).
  bool get isDone => status.v == quizStatusDone;

  /// True if archived.
  bool get isArchived => status.v == quizStatusArchived;

  /// True if playing (the only valid status for gd).
  bool get isPlaying => status.v == quizStatusPlaying;

  /// True if done or archived.
  bool get isDoneOrArchived => isDone || isArchived;

  /// True if not cancelled, done nor archived.
  bool get canBeCancelled => !isCancelled && !isDoneOrArchived;
}

/// Field names holder.
final fsQuizStatusModel = FsQuizStatus();

/// A session in `sessions/{id}`: a place/time where quizzes are played,
/// with at most one active quiz.
class FsSession extends CvFirestoreDocumentBase {
  /// The session name.
  late final name = CvField<String>('name');

  /// The active quiz id if any.
  late final activeQuizId = CvField<String>('activeQuizId');

  @override
  List<CvField<Object?>> get fields => [name, activeQuizId];
}

/// Field names holder.
final fsSessionModel = FsSession();

/// The config of a quiz (delays, question count, tags).
mixin QuizConfigMixin {
  /// Time to display the QR code and get ready to display the first question.
  late final preDelayMs = CvField<int>('preDelayMs');

  /// Time to answer a question.
  late final answerDelayMs = CvField<int>('answerDelayMs');

  /// Time to pause between questions.
  late final pauseDelayMs = CvField<int>('pauseDelayMs');

  /// Time to validate players.
  late final validationDelayMs = CvField<int>('validationDelayMs');

  /// Question count.
  late final questionCount = CvField<int>('questionCount');

  /// Question winning count (gd only, optional).
  late final questionWinningCount = CvField<int>('questionWinningCount');

  /// Selection tags.
  late final tags = CvListField<String>('tags');

  /// The mixin fields.
  CvFields get quizConfigMixinFields => <CvField>[
    preDelayMs,
    answerDelayMs,
    pauseDelayMs,
    validationDelayMs,
    questionCount,
    questionWinningCount,
    tags,
  ];
}

/// Config helpers.
extension QuizConfigMixinExt on QuizConfigMixin {
  /// The answer delay or its default.
  int get answerDelayMsOrDefault =>
      answerDelayMs.v ?? quizConfigAnswerDelayMsDefault;

  /// The pre delay or its default.
  int get preDelayMsOrDefault => preDelayMs.v ?? quizConfigPreDelayMsDefault;

  /// The pause delay or its default.
  int get pauseDelayMsOrDefault =>
      pauseDelayMs.v ?? quizConfigPauseDelayMsDefault;

  /// The validation delay or its default.
  int get validationDelayMsOrDefault =>
      validationDelayMs.v ?? quizConfigValidationDelayMsDefault;

  /// The question count or its default.
  int get questionCountOrDefault =>
      questionCount.v ?? quizConfigQuestionCountDefault;

  /// Copies the config fields from [config].
  void copyConfigFrom(QuizConfigMixin config) {
    var configFields = config.quizConfigMixinFields;
    for (var field in quizConfigMixinFields) {
      field.fromCvField(
        configFields.firstWhere((element) => element.name == field.name),
      );
    }
  }
}

/// A quiz in `quizzes/{id}`.
///
/// When created, its questions are considered as played. The uid should be
/// set before calling `toMap`.
class FsQuiz extends CvFirestoreDocumentBase
    with QuizConfigMixin, CvQuizWithQuestionsMixin
    implements CvQuizWithQuestions {
  /// The quiz type ([quizTypeTv], [quizTypeGd]).
  late final type = CvField<String>('type');
  @override
  late final questions = CvModelListField<CvQuizEncodedQuestion>('questions');

  /// Generated locally, used for correct answer encoding.
  @override
  late final uid = CvField<String>('uid');

  /// Creation timestamp (server timestamp when missing).
  late final createdTimestamp = CvField<Timestamp>('createdTimestamp');

  /// The session id.
  late final sessionId = CvField<String>('sessionId');

  /// True for a gd quiz.
  bool get isTypeGd => type.v == quizTypeGd;

  @override
  void fromMap(Map map, {List<String>? columns}) {
    super.fromMap(map, columns: columns);
    prepareQuestionsFromMap();
  }

  @override
  Map<String, Object?> toMap({
    List<String>? columns,
    bool includeMissingValue = false,
  }) {
    prepareQuestionsToMap();

    var map = super.toMap(columns: columns, includeMissingValue: false);
    // Set server if needed
    if (createdTimestamp.isNull) {
      map.withServerTimestamp(createdTimestamp);
    }
    return map;
  }

  @override
  late final fields = [
    uid,
    questions,
    createdTimestamp,
    ...quizConfigMixinFields,
    sessionId,
    type,
  ];
}

/// Field names holder.
final fsQuizModel = FsQuiz();

/// Quiz helpers.
extension FsQuizExt on FsQuiz {
  /// The correct answer id of a question.
  String getQuestionCorrectAnswerId(String questionId) {
    return questions.v!
        .firstWhere((question) => question.questionId.v == questionId)
        .correctAnswerId
        .v!;
  }

  /// The correct answer id of a question, null if not found.
  String? getQuestionCorrectAnswerIdOrNull(String questionId) {
    return questions.v
        ?.where((question) => question.questionId.v == questionId)
        .firstOrNull
        ?.correctAnswerId
        .v;
  }
}

/// The default quiz config in `infos/quiz_config`.
class FsQuizConfig extends CvFirestoreDocumentBase with QuizConfigMixin {
  @override
  late final fields = [...quizConfigMixinFields];
}

/// Field names holder.
final fsQuizConfigModel = FsQuizConfig();

/// A tv quiz player in `quizzes/{id}/players/{playerId}`.
class FsQuizPlayer extends CvFirestoreDocumentBase
    with WithServerTimestampMixin {
  /// The player name.
  late final username = CvField<String>('username');

  /// The player avatar.
  late final avatar = CvField<String>('avatar');

  /// The score (correct answers count).
  late final score = CvField<int>('score');

  /// 0 unknown, 1 valid, -1 invalid, sorted on this field.
  late final validity = CvField<int>('validity');

  /// Local start time of the player.
  late final localTimestamp = CvField<Timestamp>('localTimestamp');

  /// Total elapsed time for the correct answers.
  late final elapsedMs = CvField<int>('elapsedMs');

  /// The rank, set once.
  late final rank = CvField<int>('rank');
  @override
  late final fields = [
    username,
    avatar,
    score,
    elapsedMs,
    rank,
    ...timedMixinFields,
    validity,
    localTimestamp,
  ];
}

/// Field names holder.
final fsQuizPlayerModel = FsQuizPlayer();

/// An archived quiz summary in `archived_quizzes/{id}`.
class FsQuizArchive extends CvFirestoreDocumentBase {
  /// The quiz id.
  late final quizId = CvField<String>('quizId');

  /// The session id.
  late final sessionId = CvField<String>('sessionId');

  /// The start timestamp.
  late final startTimestamp = CvField<Timestamp>('startTimestamp');

  /// The players count.
  late final playersCount = CvField<int>('playersCount');
  @override
  late final fields = [sessionId, quizId, startTimestamp, playersCount];
}

/// Field names holder.
final fsQuizArchiveModel = FsQuizArchive();

/// A controller presence in `quizzes/{id}/controllers/{controllerId}`.
class FsQuizController extends CvFirestoreDocumentBase
    with WithServerTimestampMixin {
  @override
  List<CvField<Object?>> get fields => [...timedMixinFields];
}
