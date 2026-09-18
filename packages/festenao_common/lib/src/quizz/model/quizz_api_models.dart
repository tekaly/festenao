import 'package:festenao_common/festenao_api.dart';

import '../import.dart';
import '../quizz_constant.dart';
import '../quizz_encrypt.dart';
import 'quizz_fs_models.dart';

var _builderInitialized = false;

/// Registers the quizz api models (idempotent).
void initQuizzApiBuilders() {
  if (_builderInitialized) {
    return;
  }
  _builderInitialized = true;
  initTkCmsApiBuilders();
  initQuizzFsBuilders();
  cvAddConstructors([
    CvQuizPlayerAnswer.new,
    ApiQuizzSendResultQuery.new,
    ApiQuizzSendResultResult.new,
  ]);
}

/// A player answer to a question.
class CvQuizPlayerAnswer extends CvModelBase {
  /// The question id.
  late final questionId = CvField<String>('questionId');

  /// The answer id, null if not answered.
  late final answerId = CvField<String>('answerId');

  /// The time taken to answer.
  late final elapsedMs = CvField<int>('elapsedMs');

  /// True if correct, gd only (the client knows the answer).
  late final correct = CvField<bool>('correct');

  @override
  late final fields = [questionId, answerId, elapsedMs, correct];
}

abstract class _CommonConverter with Converter<String, String> {
  final ApiQuizzSendResultQuery model;

  String get localTimeStampString =>
      model.localTimestamp.v ?? neverPlayedTimestamp.toIso8601String();

  String get quizId => model.quizId.v ?? '';

  const _CommonConverter(this.model);
}

class _ToConverter extends _CommonConverter {
  const _ToConverter(super.model);

  @override
  String convert(String input) => quizzModelEncryptionCodec.encode(
    [quizId, localTimeStampString, input].join(','),
  );
}

class _FromConverter extends _CommonConverter {
  const _FromConverter(super.mode);

  @override
  String convert(String input) {
    var parts = quizzModelEncryptionCodec.decode(input).split(',');
    if (quizId != parts[0]) {
      throw ArgumentError('Invalid value 1');
    }
    if (localTimeStampString != parts[1]) {
      throw ArgumentError('Invalid value 2');
    }
    return parts[2];
  }
}

/// The codec signing a player result (quiz id, local timestamp, total time).
class QuizResultEncodedCodec with Codec<String, String> {
  /// Creates the codec of [query].
  QuizResultEncodedCodec(ApiQuizzSendResultQuery query) {
    encoder = _ToConverter(query);
    decoder = _FromConverter(query);
  }

  @override
  late final Converter<String, String> decoder;

  @override
  late final Converter<String, String> encoder;
}

/// The username used when none is set.
const noUserName = '--no-username--';

/// The query of [apiCommandQuizzSendResult]: a player sends its answers.
///
/// The quizz data is located by [projectId] and [dataId] (the api app being
/// the one of the request), see `QuizzServerHandler`.
class ApiQuizzSendResultQuery extends ApiQuery {
  /// The project id.
  late final projectId = CvField<String>('projectId');

  /// The data id, [quizzDefaultDataId] when null.
  late final dataId = CvField<String>('dataId');

  /// The session id.
  late final sessionId = CvField<String>('sessionId');

  /// The quiz type ([quizTypeTv], [quizTypeGd]).
  late final quizType = CvField<String>('quizType');

  /// The quiz id.
  late final quizId = CvField<String>('quizId');

  /// The player name (tv).
  late final username = CvField<String>('username');

  /// The player avatar (tv).
  late final avatar = CvField<String>('avatar');

  /// The local device id (gd).
  late final localDeviceId = CvField<String>('localDeviceId');

  /// The local time, iso8601, checked by the server (less than 30 minutes
  /// ago) and part of the signature.
  late final localTimestamp = CvField<String>('localTimestamp');

  /// The winning count (gd only, from the config).
  late final winningCount = CvField<int>('winningCount');

  /// The answers.
  late final answers = CvModelListField<CvQuizPlayerAnswer>('answers');

  /// The signature, set by `toMap`, checked by `fromMap`.
  late final validation = CvField<String>('validation');

  @override
  late final fields = [
    projectId,
    dataId,
    sessionId,
    quizType,
    quizId,
    username,
    avatar,
    answers,
    validation,
    localTimestamp,
    winningCount,
    localDeviceId,
  ];

  /// The total answer time as a string, the signed content.
  String totalMsString() {
    if (answers.v?.isNotEmpty ?? false) {
      var totalMs = answers.v!
          .map((e) => e.elapsedMs.v!)
          .reduce((value, element) => value + element);
      return totalMs.toString();
    }
    return '0';
  }

  @override
  Map<String, Object?> toMap({
    List<String>? columns,
    bool includeMissingValue = false,
  }) {
    var codec = QuizResultEncodedCodec(this);
    // Encode info in validation.
    validation.v = codec.encode(totalMsString());
    return super.toMap(
      columns: columns,
      includeMissingValue: includeMissingValue,
    );
  }

  @override
  void fromMap(Map map, {List<String>? columns}) {
    super.fromMap(map, columns: columns);
    // Fix encrypted
    var codec = QuizResultEncodedCodec(this);
    var totalMs = codec.decode(validation.v!);
    if (totalMs != totalMsString()) {
      throw ArgumentError('Invalid validation');
    }
  }
}

/// Field names holder.
final apiQuizzSendResultQueryModel = ApiQuizzSendResultQuery();

/// The result of [apiCommandQuizzSendResult].
class ApiQuizzSendResultResult extends ApiResult {
  /// The player id (the same one when sent twice).
  late final playerId = CvField<String>('playerId');

  @override
  late final CvFields fields = [playerId];
}
