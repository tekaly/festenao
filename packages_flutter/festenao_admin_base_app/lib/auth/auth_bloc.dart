import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_common/tkcms_auth.dart';

class AuthBlocState {
  final FirebaseUser? user;

  AuthBlocState({required this.user});
}

class AuthBloc extends AutoDisposeStateBaseBloc<AuthBlocState> {
  AuthBloc() {
    audiAddStreamSubscription(
        globalAdminAppFirebaseContext.auth.onCurrentUser.listen((user) {
      add(AuthBlocState(user: user));
    }));
  }
}

var globalAuthBloc = AuthBloc();
