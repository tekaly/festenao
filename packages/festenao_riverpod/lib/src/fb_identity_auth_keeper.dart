import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:tkcms_common/tkcms_auth.dart';

import 'firebase_context_provider.dart';

/// Signing in anonymously failed: offline, or anonymous sign in not enabled
/// on the firebase project.
///
/// Transient: [FestenaoFbIdentityAuthKeeper.start] retries every
/// [FestenaoFbIdentityAuthKeeper.retryDelay], riverpod retries the providers
/// failing with it ([festenaoFbSignedInIdentityProvider]).
class FestenaoFbIdentitySignInException implements Exception {
  /// The error of the auth.
  final Object error;

  /// A failed anonymous sign in, because of [error].
  FestenaoFbIdentitySignInException(this.error);

  @override
  String toString() =>
      'FestenaoFbIdentitySignInException: anonymous sign in failed: $error';
}

/// Keeps someone signed in on a [FirebaseAuth]: the user the auth restored
/// (an account or an anonymous user), an anonymous user when nobody is, or
/// the service account of an app running with admin credentials (the admin
/// sdk) when [allowServiceAccount].
///
/// Two uses:
/// - on demand: [ensureSignedIn] (or [ensureIdentity]) before an action
///   needing a user (the rules and the api answer for one), none for a local
///   action;
/// - always: [start] at launch, so that a user is always there (an app
///   writing to firestore without an account), until [stop].
///
/// An app running with admin credentials has no current user, ever: its
/// [FirebaseAuth.onCurrentUser] never emits. Every member then acts as the
/// service account when [allowServiceAccount], and throws an
/// [UnsupportedError] otherwise, instead of waiting forever.
class FestenaoFbIdentityAuthKeeper {
  /// The auth.
  final FirebaseAuth auth;

  /// Whether the app may act as the service account when it runs with
  /// admin credentials. False for an app written for a user: a service
  /// account bypasses the firestore rules.
  final bool allowServiceAccount;

  /// The delay before signing in again after a failure, while started.
  final Duration retryDelay;

  /// Called with the error of each failed anonymous sign in (a log).
  final void Function(Object error)? onSignInError;

  Future<User>? _signingIn;
  var _keeping = false;
  StreamSubscription<User?>? _subscription;
  Completer<void>? _firstAttempt;
  Timer? _retry;

  /// Keeps someone signed in on [auth], as described in the class
  /// documentation.
  ///
  /// [allowServiceAccount] accepts the service account of an app running
  /// with admin credentials, [retryDelay] is the delay between two attempts
  /// while started, [onSignInError] receives the error of each failed
  /// attempt.
  FestenaoFbIdentityAuthKeeper(
    this.auth, {
    this.allowServiceAccount = false,
    this.retryDelay = const Duration(seconds: 15),
    this.onSignInError,
  });

  /// True when the app runs with admin credentials (a service account): no
  /// user, ever.
  bool get hasAdminCredentials => auth.app.hasAdminCredentials;

  /// Who the app acts as now, without signing in: the service account (with
  /// admin credentials), the user the auth restored (an account or an
  /// anonymous user), null when nobody is signed in.
  ///
  /// Throws an [UnsupportedError] with admin credentials unless
  /// [allowServiceAccount].
  Future<TkCmsFbIdentity?> currentIdentity() async {
    if (hasAdminCredentials) {
      return _serviceAccount();
    }
    var user = await auth.onCurrentUser.first;
    return user == null ? null : TkCmsFbIdentityUser(user: user);
  }

  /// The user the auth restored (an account or an anonymous user), null
  /// when nobody is signed in, without signing in.
  ///
  /// Throws an [UnsupportedError] with admin credentials: a service account
  /// has no user.
  Future<User?> currentUser() async {
    if (hasAdminCredentials) {
      throw UnsupportedError(
        'The app runs with admin credentials: a service account has no user',
      );
    }
    return auth.onCurrentUser.first;
  }

  /// Who the app acts as, signing in anonymously first when nobody is: the
  /// service account (with admin credentials) or a user.
  ///
  /// Throws a [FestenaoFbIdentitySignInException] when the sign in fails, an
  /// [UnsupportedError] with admin credentials unless [allowServiceAccount].
  Future<TkCmsFbIdentity> ensureIdentity() async {
    if (hasAdminCredentials) {
      return _serviceAccount();
    }
    return TkCmsFbIdentityUser(user: await ensureSignedIn());
  }

  /// The signed in user, signing in anonymously first when nobody is.
  ///
  /// Concurrent calls share one sign in. Throws a
  /// [FestenaoFbIdentitySignInException] when it fails, an [UnsupportedError]
  /// with admin credentials (a service account has no user).
  Future<User> ensureSignedIn() async {
    var user = await currentUser();
    if (user != null) {
      return user;
    }
    return _signingIn ??= _signIn().whenComplete(() {
      _signingIn = null;
    });
  }

  Future<User> _signIn() async {
    try {
      return (await auth.signInAnonymously()).user;
    } catch (e) {
      onSignInError?.call(e);
      throw FestenaoFbIdentitySignInException(e);
    }
  }

  /// Keeps a user signed in until [stop]: signs in anonymously now when
  /// nobody is, again whenever the user signs out, retrying a failed sign in
  /// every [retryDelay].
  ///
  /// Completes after the first attempt, signed in or not (offline: the local
  /// data still shows while the retries go on), or at [stop]. With admin
  /// credentials there is no user to keep: completes at once when
  /// [allowServiceAccount], throws an [UnsupportedError] otherwise.
  Future<void> start() async {
    if (hasAdminCredentials) {
      _serviceAccount();
      return;
    }
    var firstAttempt = _firstAttempt;
    if (firstAttempt == null) {
      final attempt = firstAttempt = _firstAttempt = Completer<void>();
      _keeping = true;
      _subscription = auth.onCurrentUser.listen((user) async {
        await _keep(user);
        if (!attempt.isCompleted) {
          attempt.complete();
        }
      });
    }
    await firstAttempt.future;
  }

  Future<void> _keep(User? user) async {
    if (!_keeping || user != null) {
      return;
    }
    try {
      await ensureSignedIn();
    } on FestenaoFbIdentitySignInException {
      // Unless stopped meanwhile.
      if (_keeping) {
        _retry?.cancel();
        _retry = Timer(retryDelay, () {
          unawaited(_retryKeep());
        });
      }
    }
  }

  Future<void> _retryKeep() async => _keep(await auth.onCurrentUser.first);

  /// Stops keeping: no sign in nor retry starts after it (one already sent
  /// may still complete), and a pending [start] completes.
  Future<void> stop() async {
    _keeping = false;
    _retry?.cancel();
    _retry = null;
    var firstAttempt = _firstAttempt;
    _firstAttempt = null;
    if (firstAttempt != null && !firstAttempt.isCompleted) {
      firstAttempt.complete();
    }
    // Cancel the field itself, then clear it before waiting: a start
    // meanwhile keeps its own subscription.
    var cancel = _subscription?.cancel();
    _subscription = null;
    await cancel;
  }

  TkCmsFbIdentityServiceAccount _serviceAccount() {
    if (!allowServiceAccount) {
      throw UnsupportedError(
        'The app runs with admin credentials (a service account) and acts '
        'as a user only (allowServiceAccount is false)',
      );
    }
    return TkCmsFbIdentityServiceAccount(projectId: auth.app.options.projectId);
  }
}

/// The [FestenaoFbIdentityAuthKeeper] of the app, on
/// [festenaoFirebaseAuthProvider]: a user only (no service account), not
/// started, stopped with the container.
///
/// [festenaoFbSignedInIdentityProvider] and
/// [festenaoFirebaseSignedInUserProvider] sign in on demand through it.
/// Override it with the keeper the bootstrap started (`overrideWithValue`,
/// the app stops it) to keep a user signed in from launch, or with one
/// created with `allowServiceAccount: true` in an app that may run with
/// admin credentials.
final festenaoFbIdentityAuthKeeperProvider =
    Provider<FestenaoFbIdentityAuthKeeper>((ref) {
      var keeper = FestenaoFbIdentityAuthKeeper(
        ref.watch(festenaoFirebaseAuthProvider),
      );
      ref.onDispose(() {
        unawaited(keeper.stop());
      });
      return keeper;
    }, name: 'festenaoFbIdentityAuthKeeper');

/// [festenaoFbIdentityProvider], never null: who the app acts as, signing in
/// anonymously first when nobody is. The user (an account or an anonymous
/// user), or the service account of an app running with admin credentials
/// when the [festenaoFbIdentityAuthKeeperProvider] allows it.
///
/// Loading while signing in, computed again when the identity changes (a
/// sign out signs in a new anonymous user). A failed sign in
/// ([FestenaoFbIdentitySignInException]) is retried by riverpod (its default
/// retry), then stays an error until invalidated; a refused service account
/// is an [UnsupportedError], never retried.
final festenaoFbSignedInIdentityProvider = FutureProvider<TkCmsFbIdentity>((
  ref,
) async {
  var keeper = ref.watch(festenaoFbIdentityAuthKeeperProvider);
  var identity = await ref.watch(festenaoFbIdentityProvider.future);
  if (identity is TkCmsFbIdentityUser) {
    return identity;
  }
  return keeper.ensureIdentity();
}, name: 'festenaoFbSignedInIdentity');

/// The signed in user, signing in anonymously first when nobody is, as
/// [festenaoFbSignedInIdentityProvider].
///
/// An [UnsupportedError] in an app running with admin credentials: a
/// service account has no user.
final festenaoFirebaseSignedInUserProvider = FutureProvider<User>((ref) async {
  var identity = await ref.watch(festenaoFbSignedInIdentityProvider.future);
  var user = identity.user;
  if (user == null) {
    throw UnsupportedError(
      'The app runs with admin credentials: a service account has no user',
    );
  }
  return user;
}, name: 'festenaoFirebaseSignedInUser');
