import 'package:festenao_common/festenao_audi.dart';
import 'package:festenao_common/form/tk_form.dart';

class TkFormPlayerFormBlocState {
  TkFormPlayerFormBlocState({required this.player});
  final TkFormPlayer player;
}

class FormPlayerBloc
    extends AutoDisposeStateBaseBloc<TkFormPlayerFormBlocState> {
  /// Form player
  final TkFormPlayer player;

  FormPlayerBloc({required this.player}) {
    add(TkFormPlayerFormBlocState(player: player));
  }
}
