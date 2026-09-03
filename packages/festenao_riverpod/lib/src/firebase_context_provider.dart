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
