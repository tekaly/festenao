import 'package:festenao_common/festenao_audi.dart';
import 'package:tekartik_firebase_auth/auth.dart';

/// Null means not logged in
class FestenaoAuthBlocState {
  final FirebaseUser? user;

  FestenaoAuthBlocState({required this.user});
}

/// Auth Bloc
class FestenaoAuthBloc extends AutoDisposeStateBaseBloc<FestenaoAuthBlocState> {
  late final FirebaseAuth firebaseAuth;

  FestenaoAuthBloc({FirebaseAuth? firebaseAuth}) {
    this.firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;
    audiAddStreamSubscription(
      this.firebaseAuth.onCurrentUser.listen((user) {
        add(FestenaoAuthBlocState(user: user));
      }),
    );
  }
}
