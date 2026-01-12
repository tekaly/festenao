import '../../data/src/cv_sembast/app_cv_sembast.dart';

/// Text answer type.
const surveyAnswerTypeText = 'text';

/// Integer answer type.
const surveyAnswerTypeInt = 'int';

/// Boolean answer type.
const surveyAnswerTypeBool = 'bool';

/// Choice answer type.
const surveyAnswerTypeChoice = 'choice';

/// Multi-choice answer type.
const surveyAnswerTypeChoiceMulti = 'choice_multi';

var _initialized = false;

/// Initializes survey builders.
void fufFormInitSurveyBuilders() {
  if (!_initialized) {
    _initialized = true;

    cvAddConstructors([
      CvSurveyInfoDetails.new,
      CvSurveyAnswer.new,
      CvSurveyQuestion.new,
      CvSurveyQuestionChoice.new,
      CvSurveyQuestions.new,
      CvSurveyAnswers.new,
      CvSurveyQuestionConditions.new,
      CvSurveyQuestionCondition.new,
    ]);
  }
}

/// Survey info details model.
class CvSurveyInfoDetails extends CvModelBase {
  /// The spreadsheet ID.
  final spreadsheetId = CvField<String>('spreadsheetId');

  /// The survey name.
  final name = CvField<String>('name');

  /// The survey description.
  final description = CvField<String>('description');

  /// The list of questions.
  final questions = CvModelField<CvSurveyQuestions>('questions');

  @override
  CvFields get fields => [spreadsheetId, name, description, questions];
}

/// Collection of survey questions.
class CvSurveyQuestions extends CvModelBase {
  /// The list of survey questions.
  final list = CvModelListField<CvSurveyQuestion>('questions');

  @override
  List<CvField> get fields => [list];
}

/// Collection of survey answers.
class CvSurveyAnswers extends CvModelBase {
  /// The list of survey answers.
  final list = CvModelListField<CvSurveyAnswer>('list');

  @override
  List<CvField> get fields => [list];
}

/// Survey answer model.
class CvSurveyAnswer extends CvModelBase with CvSurveyAnswerMixin {
  /// Question identifier.
  final id = CvField<String>('id'); // Question ID

  @override
  List<CvField> get fields => [id, ...mixinFields];
}

/// Mixin for survey answer fields.
mixin CvSurveyAnswerMixin on CvModel {
  /// Integer answer value.
  final answerInt = CvField<int>('int');

  /// Date answer value as a string.
  final answerDate = CvField<String>('date');

  /// Text answer value.
  final answerText = CvField<String>('text');

  /// Selected single choice ID.
  final choiceId = CvField<String>('choiceId');

  /// Selected multiple choice IDs.
  final choiceIds = CvListField<String>('choiceIds');

  /// List of fields provided by the mixin.
  List<CvField> get mixinFields => [answerInt, answerText, choiceId, choiceIds];
}

/// Survey question choice model.
class CvSurveyQuestionChoice extends CvModelBase {
  /// Choice identifier.
  final id = CvField<String>('id');

  /// Value to use in the spreadsheet (uses [text] if null).
  final sheetValue = CvField<String>('sheetValue'); // Use text if null

  /// Display text for the choice.
  final text = CvField<String>('text');

  /// Type of answer if "other" is allowed (e.g., 'text' or 'int').
  final otherAnswerType = CvField<String>('otherAnswerType'); // text, int

  @override
  List<CvField> get fields => [id, text, sheetValue, otherAnswerType];
}

/// Survey question condition model.
class CvSurveyQuestionCondition extends CvModelBase {
  /// ID of the question this condition depends on.
  final questionId = CvField<String>('questionId');

  /// ID of the required answer choice.
  final answerChoiceId = CvField<String>('answerChoiceId');

  @override
  List<CvField> get fields => [questionId, answerChoiceId];
}

/// Collection of survey question conditions.
class CvSurveyQuestionConditions extends CvModelBase {
  /// List of conditions.
  final list = CvModelListField<CvSurveyQuestionCondition>('list');

  @override
  List<CvField> get fields => [list];
}

/// Survey question model.
class CvSurveyQuestion extends CvModelBase with CvSurveyQuestionMixin {
  /// Question identifier.
  final id = CvField<String>('id'); // Question ID

  /// Spreadsheet column name (uses [id] if null).
  final sheetColumn = CvField<String>('sheetColumn'); // Uses id if null

  /// Conditions that must be met to show this question.
  final conditions = CvModelField<CvSurveyQuestionConditions>('conditions');

  @override
  List<CvField> get fields => [
    id,
    sheetColumn,
    conditions,
    ...questionMixinFields,
  ];
}

/// Mixin for survey question fields.
mixin CvSurveyQuestionMixin on CvModel {
  /// Display text for the question.
  final text = CvField<String>('text');

  /// Hint text for the question.
  final hint = CvField<String>('hint');

  /// Whether an empty answer is allowed.
  final answerEmptyAllowed = CvField<bool>('answerEmptyAllowed');

  /// The type of answer required.
  final answerType = CvField<String>('answerType');

  /// List of possible answer choices.
  final choices = CvModelListField<CvSurveyQuestionChoice>('answerChoices');

  // For answerType == int
  /// Minimum allowed integer value.
  final answerIntMin = CvField<int>('answerIntMin');

  /// Maximum allowed integer value.
  final answerIntMax = CvField<int>('answerIntMax');

  /// Preset integer values for selection.
  final answerIntPresets = CvListField<int>('answerIntPresets');

  /// List of fields provided by the mixin.
  List<CvField> get questionMixinFields => [
    text,
    hint,
    answerEmptyAllowed,
    answerType,
    choices,
    answerIntMin,
    answerIntMax,
    answerIntPresets,
  ];
}

/// Converts survey questions and answers to a map model.
CvMapModel cvSurveyQuestionAnswersToMap(
  CvSurveyQuestions questions,
  CvSurveyAnswers answers,
) {
  var map = CvMapModel();
  var questionMap = <String, CvSurveyQuestion>{};
  if (questions.list.v != null) {
    for (var question in questions.list.v!) {
      questionMap[question.id.v!] = question;
    }
  }

  if (answers.list.v != null) {
    for (var answer in answers.list.v!) {
      var question = questionMap[answer.id.v!];
      if (question == null) {
        continue;
      }
      var key = question.sheetColumn.v ?? question.id.v!;
      void setAnswerText() {
        map[key] = answer.answerText.v;
      }

      void setAnswerInt() {
        map[key] = answer.answerInt.v;
      }

      void setAnswerChoice() {
        if (question.choices.v != null) {
          for (var choice in question.choices.v!) {
            if (choice.id.v == answer.choiceId.v) {
              if (choice.otherAnswerType.v == surveyAnswerTypeText) {
                map[key] = answer.answerText.v;
              }
              map[key] ??= choice.sheetValue.v ?? choice.text.v;
              break;
            }
          }
        }
      }

      void setAnswerChoiceMulti() {
        if (question.choices.v != null) {
          var values = <String>[];
          for (var choice in question.choices.v!) {
            if (answer.choiceIds.v != null &&
                answer.choiceIds.v!.contains(choice.id.v)) {
              values.add(choice.sheetValue.v ?? choice.text.v ?? choice.id.v!);
            }
          }
          map[key] = values.join(', ');
        }
      }

      if (question.answerType.v == surveyAnswerTypeText) {
        setAnswerText();
      } else if (question.answerType.v == surveyAnswerTypeInt) {
        setAnswerInt();
      } else if (question.answerType.v == surveyAnswerTypeChoice) {
        setAnswerChoice();
      } else if (question.answerType.v == surveyAnswerTypeChoiceMulti) {
        setAnswerChoiceMulti();
      } else {
        if (question.choices.v != null) {
          if (answer.choiceIds.v != null) {
            setAnswerChoiceMulti();
          } else {
            setAnswerChoice();
          }
          continue;
        } else if (answer.answerInt.isNotNull) {
          setAnswerInt();
          continue;
        } else if (answer.answerText.isNotNull) {
          setAnswerText();
          continue;
        }
        // ignore: avoid_print
        print('UnsupportedError Answer type ${question.answerType.v}');
      }
    }
  }

  return map;
}
