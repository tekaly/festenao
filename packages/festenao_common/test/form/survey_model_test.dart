import 'package:festenao_common/form/tk_form.dart';
import 'package:festenao_common/form/tk_form_db.dart';
import 'package:test/test.dart';

void main() {
  test('survey answer date', () {
    var answer = CvSurveyAnswer()
      ..id.v = 'q1'
      ..answerDate.v = '2025-02-25';
    expect(answer.toMap(), {'id': 'q1', 'date': '2025-02-25'});
  });

  group('cvSurveyAnswer', () {
    test('multi choice ids', () {
      var answer = TkFormPlayerQuestionAnswer(
        choiceIds: ['c1', 'c2'],
      ).cvSurveyAnswer;
      expect(answer.choiceIds.v, ['c1', 'c2']);
      expect(answer.id.v, isNull);
    }, timeout: const Timeout(Duration(seconds: 10)));
    test('question id', () {
      var answer = TkFormPlayerQuestionAnswer(
        choiceId: 'c1',
        textValue: 'other',
      ).toCvSurveyAnswer(questionId: 'q1');
      expect(answer.toMap(), {
        'id': 'q1',
        'int': null,
        'text': 'other',
        'choiceId': 'c1',
      });
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('cvSurveyQuestionAnswersToMap', () {
    CvSurveyQuestions questions(String? otherAnswerType) =>
        CvSurveyQuestions()
          ..list.v = [
            CvSurveyQuestion()
              ..id.v = 'q1'
              ..answerType.v = surveyAnswerTypeChoice
              ..choices.v = [
                CvSurveyQuestionChoice()
                  ..id.v = 'yes'
                  ..text.v = 'Oui',
                CvSurveyQuestionChoice()
                  ..id.v = 'other'
                  ..text.v = 'Autre'
                  ..otherAnswerType.v = otherAnswerType,
              ],
          ];
    CvSurveyAnswers answers(String choiceId, {String? text, int? intValue}) =>
        CvSurveyAnswers()
          ..list.v = [
            CvSurveyAnswer()
              ..id.v = 'q1'
              ..choiceId.v = choiceId
              ..answerText.setValue(text)
              ..answerInt.setValue(intValue),
          ];
    test('other text', () {
      fufFormInitSurveyBuilders();
      expect(
        cvSurveyQuestionAnswersToMap(
          questions(surveyAnswerTypeText),
          answers('other', text: 'Peut-être'),
        ).toMap(),
        {'q1': 'Peut-être'},
      );
    }, timeout: const Timeout(Duration(seconds: 10)));
    test('other int, typed as text', () {
      fufFormInitSurveyBuilders();
      // The question screen stores the typed value of any "other" choice as
      // text.
      expect(
        cvSurveyQuestionAnswersToMap(
          questions(surveyAnswerTypeInt),
          answers('other', text: '12'),
        ).toMap(),
        {'q1': '12'},
      );
      expect(
        cvSurveyQuestionAnswersToMap(
          questions(surveyAnswerTypeInt),
          answers('other', intValue: 12),
        ).toMap(),
        {'q1': 12},
      );
    }, timeout: const Timeout(Duration(seconds: 10)));
    test('other empty and plain choice', () {
      fufFormInitSurveyBuilders();
      expect(
        cvSurveyQuestionAnswersToMap(
          questions(surveyAnswerTypeInt),
          answers('other'),
        ).toMap(),
        {'q1': 'Autre'},
      );
      expect(
        cvSurveyQuestionAnswersToMap(
          questions(surveyAnswerTypeText),
          answers('yes', text: 'ignored'),
        ).toMap(),
        {'q1': 'Oui'},
      );
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
