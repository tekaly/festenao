import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/form/tk_form.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';

import 'form_screen.dart';
import 'tk_form_question_screen_bloc.dart';

var debugQuestionScreen = false; // devWarning(true);

void _log(String message) {
  if (debugQuestionScreen) {
    // ignore: avoid_print
    print('/fq $message');
  }
}

class QuestionPlayerScreenBlocState {
  final TkFormPlayerQuestionBlocState playerState;

  QuestionPlayerScreenBlocState({required this.playerState});
  @override
  String toString() {
    var question = playerState.question;
    return question.toString();
  }
}

class QuestionPlayerScreenBloc
    extends AutoDisposeStateBaseBloc<QuestionPlayerScreenBlocState>
    implements SurveyPlayerBloc {
  /// Question player
  late final questionPlayer = player.getQuestionPlayer(questionIndex);
  late final surveyBloc = globalSurveyPlayerFormBloc;
  final int questionIndex;

  TkFormPlayer? _tkFormPlayer;
  QuestionPlayerScreenBloc({
    required this.questionIndex,
    TkFormPlayer? player,
  }) {
    _tkFormPlayer = player;
    _init();
  }

  Future<void> _init() async {
    TkFormPlayerFormBlocState formState;
    if (_tkFormPlayer == null) {
      if (debugQuestionScreen) {
        _log('waiting for surveyBloc');
      }
      formState = await surveyBloc.state.first;
      if (debugQuestionScreen) {
        _log('got state $formState');
      }
    } else {
      formState = TkFormPlayerFormBlocState(form: _tkFormPlayer!.form);
    }
    try {
      var tkQuestion = player.getQuestion(questionIndex);
      var tkAnswer = player.getAnswer(questionIndex);
      add(
        QuestionPlayerScreenBlocState(
          playerState: TkFormPlayerQuestionBlocState(
            form: formState,
            question: tkQuestion,
            answer: tkAnswer,
          ),
        ),
      );
    } catch (e) {
      addError('Question not found $e');
    }
  }

  @override
  TkFormPlayer get player => _tkFormPlayer ?? surveyBloc.player;
}
