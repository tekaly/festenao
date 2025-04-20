import 'package:festenao_common/festenao_audi.dart';
import 'package:festenao_common/form/tk_form.dart';

class TkFormPlayerBlocState {
  TkFormPlayerBlocState({required this.player});
  final TkFormPlayer player;
}

class FormPlayerBloc extends AutoDisposeStateBaseBloc<TkFormPlayerBlocState> {
  /// Form player
  final TkFormPlayer player;

  FormPlayerBloc({required this.player}) {
    add(TkFormPlayerBlocState(player: player));
  }
}
