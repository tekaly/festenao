import 'package:riverpod/misc.dart' show Override;
import 'package:riverpod/riverpod.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

import 'firebase_app_provider.dart';

/// The firebase services the app runs against: auth, firestore (and storage).
///
/// Must be overridden by the app, once, at the root `ProviderScope` (or
/// [ProviderContainer]), with the [FirebaseContext] its entry point built: a
/// real one (flutterfire, rest), or a local backend-less one in tests and in
/// the offline entry point. Everything below then depends on the services
/// rather than on the `FirebaseXxx.instance` globals.
///
/// [festenaoFirebaseContextOverrides] builds this override together with the
/// [festenaoFirebaseAppProvider] one, so the two never disagree.
final festenaoFirebaseContextProvider = Provider<FirebaseContext>(
  (ref) => throw UnimplementedError(
    'festenaoFirebaseContextProvider must be overridden with the firebase '
    'services of the app (see festenaoFirebaseContextOverrides)',
  ),
  name: 'festenaoFirebaseContext',
);

/// The firebase auth of the app.
final festenaoFirebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => ref.watch(festenaoFirebaseContextProvider).auth,
  name: 'festenaoFirebaseAuth',
);

/// The firestore of the app, the remote side of every synchronization.
final festenaoFirestoreProvider = Provider<Firestore>(
  (ref) => ref.watch(festenaoFirebaseContextProvider).firestore,
  name: 'festenaoFirestore',
);

/// The signed in user, null when signed out.
///
/// Loading until the auth has emitted its first state, which is what a router
/// redirect should wait for before sending anyone to a sign in screen.
final festenaoFirebaseUserProvider = StreamProvider<User?>(
  (ref) => ref.watch(festenaoFirebaseAuthProvider).onCurrentUser,
  name: 'festenaoFirebaseUser',
);

/// The id of the signed in user, null while unknown or signed out.
///
/// Everything user scoped hangs from it: the per user projects database, and
/// the firestore rules answer for that user only.
final festenaoFirebaseUserIdProvider = Provider<String?>(
  (ref) => ref.watch(festenaoFirebaseUserProvider).value?.uid,
  name: 'festenaoFirebaseUserId',
);

/// Who the app acts as, the tkcms [TkCmsFbIdentity]: the service account
/// ([TkCmsFbIdentityServiceAccount]) when the firebase app has admin
/// credentials (the admin sdk), the signed in user ([TkCmsFbIdentityUser])
/// otherwise, null when signed out.
///
/// Prefer it to [festenaoFirebaseUserProvider] in an app that may run with
/// admin credentials: that auth never has a current user, its
/// `onCurrentUser` never emits and [festenaoFirebaseUserProvider] stays
/// loading forever.
final festenaoFbIdentityProvider = StreamProvider<TkCmsFbIdentity?>((ref) {
  var bloc = TkCmsFbIdentityBloc(auth: ref.watch(festenaoFirebaseAuthProvider));
  ref.onDispose(bloc.dispose);
  return bloc.state.map((state) => state.identity);
}, name: 'festenaoFbIdentity');

/// The overrides binding [festenaoFirebaseContextProvider] and
/// [festenaoFirebaseAppProvider] to [firebaseContext].
///
/// Add them to the root `ProviderScope` next to the ones of
/// `festenaoFlutterProviderOverrides`.
List<Override> festenaoFirebaseContextOverrides(
  FirebaseContext firebaseContext,
) => [
  festenaoFirebaseContextProvider.overrideWithValue(firebaseContext),
  festenaoFirebaseAppProvider.overrideWithValue(firebaseContext.firebaseApp),
];
