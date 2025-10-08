import 'package:festenao_common/festenao_audi.dart';
import 'package:tekartik_firebase_auth/auth.dart';

/// State for the Festenao authentication bloc.
///
/// Contains the current Firebase user, or null if not logged in.
class FestenaoAuthBlocState {
  /// The current Firebase user, or null if not logged in.
  final FirebaseUser? user;

  /// Creates a new [FestenaoAuthBlocState] with the given user.
  FestenaoAuthBlocState({required this.user});
  @override
  String toString() => 'FestenaoAuthBlocState(user: $user)';
}

/// Authentication bloc for Festenao.
///
/// Manages the current user state based on Firebase authentication.
class FestenaoAuthBloc extends AutoDisposeStateBaseBloc<FestenaoAuthBlocState> {
  /// The Firebase authentication instance.
  late final FirebaseAuth firebaseAuth;

  /// Creates a new [FestenaoAuthBloc] with an optional FirebaseAuth instance.
  FestenaoAuthBloc({FirebaseAuth? firebaseAuth}) {
    this.firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;
    audiAddStreamSubscription(
      this.firebaseAuth.onCurrentUser.listen((user) {
        add(FestenaoAuthBlocState(user: user));
      }),
    );
  }
}
