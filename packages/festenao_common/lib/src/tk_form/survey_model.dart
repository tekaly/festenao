import '../../data/src/cv_sembast/app_cv_sembast.dart';

const surveyAnswerTypeText = 'text';
const surveyAnswerTypeInt = 'int';
const surveyAnswerTypeBool = 'bool';
const surveyAnswerTypeChoice = 'choice';
const surveyAnswerTypeChoiceMulti = 'choice_multi';

var _initialized = false;
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

class CvSurveyInfoDetails extends CvModelBase {
  final spreadsheetId = CvField<String>('spreadsheetId');
  final name = CvField<String>('name');
  final description = CvField<String>('description');
  final questions = CvModelField<CvSurveyQuestions>('questions');
  @override
  CvFields get fields => [spreadsheetId, name, description, questions];
}

class CvSurveyQuestions extends CvModelBase {
  final list = CvModelListField<CvSurveyQuestion>('questions');
  @override
  List<CvField> get fields => [list];
}

class CvSurveyAnswers extends CvModelBase {
  final list = CvModelListField<CvSurveyAnswer>('list');
  @override
  List<CvField> get fields => [list];
}

class CvSurveyAnswer extends CvModelBase with CvSurveyAnswerMixin {
  final id = CvField<String>('id'); // Question ID
  @override
  List<CvField> get fields => [id, ...mixinFields];
}

mixin CvSurveyAnswerMixin on CvModel {
  final answerInt = CvField<int>('int');
  final answerDate = CvField<String>('date');
  final answerText = CvField<String>('text');
  final choiceId = CvField<String>('choiceId');
  final choiceIds = CvListField<String>('choiceIds');

  List<CvField> get mixinFields => [answerInt, answerText, choiceId, choiceIds];
}

class CvSurveyQuestionChoice extends CvModelBase {
  final id = CvField<String>('id');
  final sheetValue = CvField<String>('sheetValue'); // Use text if null
  final text = CvField<String>('text');
  final otherAnswerType = CvField<String>('otherAnswerType'); // text, int

  @override
  List<CvField> get fields => [id, text, sheetValue, otherAnswerType];
}

class CvSurveyQuestionCondition extends CvModelBase {
  final questionId = CvField<String>('questionId');
  final answerChoiceId = CvField<String>('answerChoiceId');

  @override
  List<CvField> get fields => [questionId, answerChoiceId];
}

class CvSurveyQuestionConditions extends CvModelBase {
  final list = CvModelListField<CvSurveyQuestionCondition>('list');
  @override
  List<CvField> get fields => [list];
}

class CvSurveyQuestion extends CvModelBase with CvSurveyQuestionMixin {
  final id = CvField<String>('id'); // Question ID
  final sheetColumn = CvField<String>('sheetColumn'); // Uses id if null
  final conditions = CvModelField<CvSurveyQuestionConditions>('conditions');
  @override
  List<CvField> get fields => [
    id,
    sheetColumn,
    conditions,
    ...questionMixinFields,
  ];
}

mixin CvSurveyQuestionMixin on CvModel {
  final text = CvField<String>('text');
  final hint = CvField<String>('hint');
  final answerEmptyAllowed = CvField<bool>('answerEmptyAllowed');
  final answerType = CvField<String>('answerType');
  final choices = CvModelListField<CvSurveyQuestionChoice>('answerChoices');
  // For answerType == int
  final answerIntMin = CvField<int>('answerIntMin');
  final answerIntMax = CvField<int>('answerIntMax');
  final answerIntPresets = CvListField<int>('answerIntPresets');

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
