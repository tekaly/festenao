import 'package:festenao_common/festenao_sembast.dart';
import 'package:festenao_common/form/tk_form.dart';
import 'package:festenao_common/src/tk_form/survey_model.dart';
import 'package:meta/meta.dart';
import 'package:tekartik_common_utils/list_utils.dart';
import 'package:tekartik_firebase_firestore/utils/auto_id_generator.dart';

export 'package:tekartik_app_cv_sembast/app_cv_sembast.dart';

void fufFormInitDbBuilders() {
  cvAddConstructors([DbSurvey.new, DbDevice.new]);

  fufFormInitSurveyBuilders();
}

String? _cachedUniqueId;

@visibleForTesting
void cleanCachedUniqueDeviceId() {
  _cachedUniqueId = null;
}

class DbDevice extends DbStringRecordBase {
  final uniqueId = CvField<String>('uniqueId');

  @override
  CvFields get fields => [uniqueId];
}

class DbSurvey extends DbStringRecordBase {
  final lastUsedTimestamp = CvField<DbTimestamp>('lastUsedTimestamp');
  final details = CvModelField<CvSurveyInfoDetails>('details');

  @override
  CvFields get fields => [lastUsedTimestamp, details];
}

class _DbQuestionChoice implements TkFormPlayerQuestionChoice {
  final CvSurveyQuestionChoice dbSurveyQuestionChoice;

  _DbQuestionChoice(this.dbSurveyQuestionChoice);

  @override
  String get id => dbSurveyQuestionChoice.id.v ?? '';

  @override
  String get text => dbSurveyQuestionChoice.text.v ?? '';

  @override
  String toString() => 'DbSurvey${toDebugString()}';

  @override
  bool get allowOther => dbSurveyQuestionChoice.otherAnswerType.isNotNull;
}

/// Question options int
class _DbQuestionIntOptions extends _DbQuestionOptions
    implements TkFormPlayerQuestionIntOptions {
  _DbQuestionIntOptions(super.dbSurveyQuestion) : super._();

  @override
  List<int>? get presets => dbSurveyQuestion.answerIntPresets.v?.nonEmpty();

  @override
  int? get max => dbSurveyQuestion.answerIntMax.v;

  @override
  int? get min => dbSurveyQuestion.answerIntMin.v;
}

/// Question options text
class _DbQuestionTextOptions extends _DbQuestionOptions
    implements TkFormPlayerQuestionTextOptions {
  _DbQuestionTextOptions(super.dbSurveyQuestion) : super._();
}

/// Question options choice
class _DbQuestionOptionsChoice extends _DbQuestionOptions
    implements TkFormPlayerQuestionChoiceOptions {
  _DbQuestionOptionsChoice(super.dbSurveyQuestion) : super._();

  @override
  List<TkFormPlayerQuestionChoice>? get choices =>
      dbSurveyQuestion.choices.v
          ?.map((dbChoice) => _DbQuestionChoice(dbChoice))
          .toList();

  /// Only support text weird here but it is what it is...
  @override
  bool get choiceAllowOther {
    if (isTypeChoice) {
      if (dbSurveyQuestion.choices.v?.firstWhereOrNull(
            (choice) => choice.otherAnswerType.v == surveyAnswerTypeText,
          ) !=
          null) {
        return true;
      }
    }
    return false;
  }
}

class _DbQuestionOptions extends TkFormPlayerQuestionOptions
    with TkFormPlayerQuestionOptionsMixin {
  CvSurveyQuestion dbSurveyQuestion;

  _DbQuestionOptions._(this.dbSurveyQuestion);
  factory _DbQuestionOptions(CvSurveyQuestion dbSurveyQuestion) {
    switch (dbSurveyQuestion.answerType.v) {
      case surveyAnswerTypeInt:
        return _DbQuestionIntOptions(dbSurveyQuestion);

      case surveyAnswerTypeChoice:
      case surveyAnswerTypeChoiceMulti:
        return _DbQuestionOptionsChoice(dbSurveyQuestion);
      case surveyAnswerTypeText:
      default:
        return _DbQuestionTextOptions(dbSurveyQuestion);
    }
  }

  String? get _answerType => dbSurveyQuestion.answerType.v;
  @override
  bool get isTypeChoice => _answerType == surveyAnswerTypeChoice;

  @override
  bool get isTypeInt => _answerType == surveyAnswerTypeInt;

  @override
  bool get isTypeText => _answerType == surveyAnswerTypeText;

  @override
  bool get isTypeChoiceMulti => _answerType == surveyAnswerTypeChoiceMulti;

  @override
  bool get emptyAllowed {
    return dbSurveyQuestion.answerEmptyAllowed.v ?? false;
  }

  @override
  String toString() {
    return 'DbQuestionOptions(answerType: $_answerType)';
  }
}

/// Question extension
extension CvSurveyQuestionExt on CvSurveyQuestion {
  TkFormPlayerQuestion get formPlayerQuestion {
    var playerQuestion = TkFormPlayerQuestion(
      id: id.v ?? '',
      text: text.v ?? '',
      hint: hint.v,
      options: _DbQuestionOptions(this),
    );
    return playerQuestion;
  }

  /// Question options int
  TkFormPlayerQuestionIntOptions get intOptions {
    var presets = answerIntPresets.v?.nonEmpty();
    var max = answerIntMax.v;
    var min = answerIntMin.v;
    return TkFormPlayerQuestionIntOptions(presets: presets, min: min, max: max);
  }
}

extension DbSurveyExt on DbSurvey {
  TkFormPlayerForm get formPlayerForm {
    var self = this;
    var formPlayerForm = TkFormPlayerFormBase(
      id: self.id,
      name: self.details.v?.name.v ?? '',
    );

    return formPlayerForm;
  }

  List<TkFormPlayerQuestion> get formPlayerQuestions {
    var self = this;
    var questions = self.details.v?.questions.v?.list.v ?? [];
    return questions.map((question) => question.formPlayerQuestion).toList();
  }
}

/// Answer extension
extension TkFormPlayerQuestionAnswerExt on TkFormPlayerQuestionAnswer {
  CvSurveyAnswer get cvSurveyAnswer {
    var self = this;
    var cvSurveyAnswer = CvSurveyAnswer();
    cvSurveyAnswer.answerInt.v = self.intValue;
    cvSurveyAnswer.choiceId.v = self.choiceId;
    cvSurveyAnswer.answerText.v = self.textValue;

    return cvSurveyAnswer;
  }
}

final dbSurveyStore = cvStringStoreFactory.store<DbSurvey>('survey');
final dbInfoStore = cvStringStoreFactory.store<DbStringRecordBase>('info');

final dbDeviceRecord = dbInfoStore.castV<DbDevice>().record('device');

class LocalDatabase {
  final DatabaseFactory databaseFactory;
  late Database database;

  LocalDatabase(this.databaseFactory) {
    fufFormInitDbBuilders();
  }
  Future<void> init() async {
    database = await databaseFactory.openDatabase(
      'form.db',
      //codec: sembastFirestoreCodec,
    );
  }

  /// Never null, unique per app install only
  Future<String> getUniqueDeviceId({@visibleForTesting bool? forceRead}) async {
    forceRead ??= false;
    String? uniqueId;
    if (!forceRead) {
      // get Cached in RAM
      uniqueId = _cachedUniqueId;
      if (uniqueId?.isNotEmpty ?? false) {
        return uniqueId!;
      }
    }

    uniqueId = await database.transaction((txn) async {
      var device = await dbDeviceRecord.get(txn);
      var uniqueId = device?.uniqueId.v;
      if (uniqueId?.isNotEmpty ?? false) {
        return uniqueId!;
      }

      device ??= DbDevice();

      uniqueId = device.uniqueId.v = AutoIdGenerator.autoId();
      await dbDeviceRecord.put(txn, device);
      return uniqueId;
    });
    _cachedUniqueId = uniqueId;
    return uniqueId!;
  }
}
