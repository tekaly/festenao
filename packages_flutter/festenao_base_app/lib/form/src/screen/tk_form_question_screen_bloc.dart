import 'package:festenao_common/festenao_audi.dart';
import 'package:festenao_common/form/tk_form.dart';

class TkFormPlayerQuestionBlocState {
  final TkFormPlayerFormBlocState form;
  final TkFormPlayerQuestion question;
  final TkFormPlayerQuestionAnswer? answer;

  TkFormPlayerQuestionBlocState({
    required this.form,
    required this.question,
    required this.answer,
  });
}

class TkFormPlayerQuestionBloc
    extends AutoDisposeStateBaseBloc<TkFormPlayerFormBlocState> {}

class TkFormPlayerFormBlocState {
  final TkFormPlayerForm form;

  TkFormPlayerFormBlocState({required this.form});
}

class TkFormPlayerBloc
    extends AutoDisposeStateBaseBloc<TkFormPlayerFormBlocState> {}
