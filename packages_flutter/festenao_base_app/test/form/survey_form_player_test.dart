import 'package:festenao_base_app/form/src/app/app_bloc.dart';
import 'package:festenao_base_app/form/src/screen/form_screen.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_common/form/tk_form.dart';
import 'package:festenao_common/form/tk_form_db.dart';
import 'package:flutter_test/flutter_test.dart';

/// q1 a choice (yes/no), q2 asked only when q1 is yes.
DbSurvey _conditionalSurvey() {
  fufFormInitDbBuilders();
  return dbSurveyStore.record('survey').cv()
    ..details.v = (CvSurveyInfoDetails()
      ..name.v = 'Survey'
      ..questions.v = (CvSurveyQuestions()
        ..list.v = [
          CvSurveyQuestion()
            ..id.v = 'q1'
            ..text.v = 'Do you come?'
            ..answerType.v = surveyAnswerTypeChoice
            ..choices.v = [
              CvSurveyQuestionChoice()
                ..id.v = 'yes'
                ..text.v = 'Yes',
              CvSurveyQuestionChoice()
                ..id.v = 'no'
                ..text.v = 'No',
            ],
          CvSurveyQuestion()
            ..id.v = 'q2'
            ..text.v = 'How many?'
            ..answerType.v = surveyAnswerTypeInt
            ..conditions.v = (CvSurveyQuestionConditions()
              ..list.v = [
                CvSurveyQuestionCondition()
                  ..questionId.v = 'q1'
                  ..answerChoiceId.v = 'yes',
              ]),
        ]));
}

SurveyFormPlayer _player(DbSurvey dbSurvey) => SurveyFormPlayer(
  id: 'survey',
  questions: dbSurvey.formPlayerQuestions,
  form: dbSurvey.formPlayerForm,
  dbSurvey: dbSurvey,
);

void main() {
  setUp(() {
    gAppBloc = AppBloc(
      databaseFactory: FestenaoDb.inMemoryDatabaseFactory,
      appOptions: AppFlavorContext.testLocal,
      surveyId: 'survey',
    )..startSurvey();
  });

  test('a conditional question is asked when its condition is met', () {
    var player = _player(_conditionalSurvey());
    player.setAnswer(0, TkFormPlayerQuestionAnswer(choiceId: 'yes'));
    expect(gAppBloc.getAnswer('q1')?.choiceId.v, 'yes');
    expect(player.shouldSkip(1), isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('a conditional question is skipped when its condition is not met', () {
    var player = _player(_conditionalSurvey());
    player.setAnswer(0, TkFormPlayerQuestionAnswer(choiceId: 'no'));
    expect(player.shouldSkip(1), isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('each question keeps its own answer', () {
    var player = _player(_conditionalSurvey());
    player.setAnswer(0, TkFormPlayerQuestionAnswer(choiceId: 'yes'));
    player.setAnswer(1, TkFormPlayerQuestionAnswer(intValue: 3));
    expect(gAppBloc.getAnswer('q1')?.choiceId.v, 'yes');
    expect(gAppBloc.getAnswer('q2')?.answerInt.v, 3);
    expect(gAppBloc.surveyAnswers.list.v, hasLength(2));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
