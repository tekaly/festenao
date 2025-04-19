import 'package:festenao_base_app/form/src/app/app_bloc.dart';
import 'package:festenao_base_app/form/src/screen/tk_form_question_screen_bloc.dart';
import 'package:festenao_common/form/tk_form.dart';
import 'package:festenao_common/form/tk_form_db.dart';
import 'package:tekartik_common_utils/env_utils.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';

abstract class SurveyPlayerBloc {
  TkFormPlayer get player;
}

abstract class AppFormPlayerBloc
    implements StateBaseBloc<TkFormPlayerFormBlocState>, SurveyPlayerBloc {
  TkFormPlayer newPlayer();
}

class SurveyPlayerFormBlocMemory
    extends AutoDisposeStateBaseBloc<TkFormPlayerFormBlocState>
    implements AppFormPlayerBloc, SurveyPlayerBloc {
  @override
  final TkFormPlayer player;

  SurveyPlayerFormBlocMemory({required this.player});

  @override
  TkFormPlayer newPlayer() {
    add(TkFormPlayerFormBlocState(form: player.form));
    return player;
  }
}

class SurveyPlayerFormBloc
    extends AutoDisposeStateBaseBloc<TkFormPlayerFormBlocState>
    implements AppFormPlayerBloc, SurveyPlayerBloc {
  @override
  late TkFormPlayer player;
  SurveyPlayerFormBloc() {
    // newPlayer();
  }
  @override
  TkFormPlayer newPlayer() {
    var dbSurveyInfo = gAppBloc.dbSurveyVS.valueOrNull;

    if (dbSurveyInfo != null) {
      var form = dbSurveyInfo.formPlayerForm;
      var tkQuestions = dbSurveyInfo.formPlayerQuestions;

      player = SurveyFormPlayer(
        id: form.id,
        questions: tkQuestions,
        form: form,
        dbSurvey: dbSurveyInfo,
      );
      add(TkFormPlayerFormBlocState(form: form));
      return player;
    } else {
      addError('Invalid survey');
      throw ('Invalid survey');
    }
  }
}

AppFormPlayerBloc globalSurveyPlayerFormBloc = SurveyPlayerFormBloc();

// Only global specific survey player
class SurveyFormPlayer extends TkFormPlayerBase implements TkFormPlayer {
  final DbSurvey dbSurvey;

  SurveyFormPlayer({
    required super.id,
    required super.questions,
    required this.dbSurvey,
    required super.form,
  });

  @override
  void setAnswer(int index, TkFormPlayerQuestionAnswer? answer) {
    super.setAnswer(index, answer);
    var cvAnswer =
        answer?.cvSurveyAnswer; // (answer as DbSurveyAnswer?)?.cvSurveyAnswer;
    gAppBloc.addAnswer(cvAnswer);
  }

  @override
  bool shouldSkip(int index) {
    var kDebugMode = isDebug;
    var question = dbSurvey.details.v!.questions.v!.list.v![index];
    // Check conditions
    if (question.conditions.v?.list.v?.isNotEmpty ?? false) {
      try {
        var conditionMet = false;
        for (var condition in question.conditions.v!.list.v!) {
          //var tkAnswer = bloc.player.getAnswer(questionIndex);
          // print('tkAnswer: $tkAnswer');
          var answer = gAppBloc.getAnswer(condition.questionId.v!);
          if (condition.answerChoiceId.isNotNull) {
            if (answer?.choiceId.v == condition.answerChoiceId.v) {
              if (kDebugMode) {
                // ignore: avoid_print
                print('Condition met: $condition');
              }
              conditionMet = true;
              break;
            } else if (answer?.choiceIds.v?.contains(
                  condition.answerChoiceId.v,
                ) ??
                false) {
              if (kDebugMode) {
                // ignore: avoid_print
                print('Condition met: $condition');
              }
              conditionMet = true;
              break;
            }
          }
        }

        if (!conditionMet) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('Conditions not met: ${question.conditions.v!.list.v}');
          }
          // Should skip
          return true;
          /*
          sleep(0).then((_) {
            if (mounted) {
              Navigator.of(context).pop();
              _goToNext();
            }
          });*/
        }
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Error checking conditions: $e');
        }
      }
    }
    return false;
  }
}
