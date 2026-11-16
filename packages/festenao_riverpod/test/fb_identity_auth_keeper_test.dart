import 'dart:async';

import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:idb_shim/sdb.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

class _App implements FirebaseApp {
  _App({required this.hasAdminCredentials});

  @override
  final bool hasAdminCredentials;

  @override
  FirebaseAppOptions get options => FirebaseAppOptions(projectId: 'my-admin');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An auth nobody is signed in to, whose anonymous sign ins wait for the
/// test to answer them, or fail at once when [offline]; with admin
/// credentials when [admin] (no current user, ever).
class _Auth implements FirebaseAuth {
  _Auth({bool admin = false, this.offline = false})
    : app = _App(hasAdminCredentials: admin);

  @override
  final FirebaseApp app;

  /// Every sign in fails at once.
  final bool offline;

  /// The sign ins asked, in order.
  final signIns = <Completer<UserCredential>>[];

  /// The subscriptions to [onCurrentUser] not cancelled yet.
  var listeners = 0;

  @override
  Stream<User?> get onCurrentUser {
    late StreamController<User?> controller;
    controller = StreamController<User?>(
      onListen: () {
        listeners++;
        if (!app.hasAdminCredentials) {
          controller.add(null);
        }
      },
      onCancel: () {
        listeners--;
      },
    );
    return controller.stream;
  }

  @override
  Future<UserCredential> signInAnonymously() {
    var signIn = Completer<UserCredential>();
    signIns.add(signIn);
    if (offline) {
      signIn.completeError(StateError('offline'));
    }
    return signIn.future;
  }

  /// Fails the sign ins not answered yet (offline).
  void failPending() {
    for (var signIn in signIns) {
      if (!signIn.isCompleted) {
        signIn.completeError(StateError('offline'));
      }
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Waits (up to 5 s) for [condition].
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 500 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

void main() {
  group('FestenaoFbIdentityAuthKeeper', () {
    late FirebaseContext firebaseContext;
    late FirebaseAuth auth;
    setUp(() async {
      firebaseContext = await initFirebaseServicesLocalSdb(
        sdbFactory: newSdbFactoryMemory(),
        projectId: 'festenao-riverpod-keeper-test',
      ).init();
      auth = firebaseContext.auth;
    });
    tearDown(() async {
      await firebaseContext.close();
    });

    test('ensureSignedIn signs in anonymously once', () async {
      var keeper = FestenaoFbIdentityAuthKeeper(auth);
      expect(await keeper.currentUser(), isNull);
      expect(await keeper.currentIdentity(), isNull);
      var users = await Future.wait([
        keeper.ensureSignedIn(),
        keeper.ensureSignedIn(),
      ]);
      expect(users[0].isAnonymous, isTrue);
      expect(users[1].uid, users[0].uid);
      expect((await keeper.currentUser())?.uid, users[0].uid);
      expect((await keeper.ensureSignedIn()).uid, users[0].uid);
      var identity = await keeper.currentIdentity();
      expect(identity?.userId, users[0].uid);
      expect((await keeper.ensureIdentity()).userId, users[0].uid);
    });

    test('keeps the restored account', () async {
      var account = await auth.signInOrUpWithEmailAndPassword(
        email: 'alice@example.com',
        password: 'test1234',
      );
      var keeper = FestenaoFbIdentityAuthKeeper(auth);
      var user = await keeper.ensureSignedIn();
      expect(user.uid, account.user.uid);
      expect(user.isAnonymous, isFalse);
    });

    test('start keeps a user signed in until stop', () async {
      var keeper = FestenaoFbIdentityAuthKeeper(auth);
      await keeper.start();
      var first = await keeper.currentUser();
      expect(first?.isAnonymous, isTrue);

      await auth.signOut();
      var next = await auth.onCurrentUser
          .firstWhere((user) => user != null && user.uid != first!.uid)
          .timeout(const Duration(seconds: 5));
      expect(next?.isAnonymous, isTrue);

      await keeper.stop();
      await auth.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await keeper.currentUser(), isNull);
    });
  });

  group('failed sign in', () {
    test('throws, one attempt shared by concurrent calls', () async {
      var auth = _Auth();
      var errors = <Object>[];
      var keeper = FestenaoFbIdentityAuthKeeper(
        auth,
        onSignInError: errors.add,
      );
      var calls = [keeper.ensureSignedIn(), keeper.ensureSignedIn()];
      await _until(() => auth.signIns.isNotEmpty);
      auth.failPending();
      for (var call in calls) {
        await expectLater(
          call,
          throwsA(isA<FestenaoFbIdentitySignInException>()),
        );
      }
      expect(auth.signIns, hasLength(1));
      expect(errors, hasLength(1));
    });

    test('start retries every retryDelay until stop', () async {
      var auth = _Auth(offline: true);
      var keeper = FestenaoFbIdentityAuthKeeper(
        auth,
        retryDelay: const Duration(milliseconds: 10),
      );
      await keeper.start();
      expect(auth.signIns, hasLength(1));
      await _until(() => auth.signIns.length >= 3);

      await keeper.stop();
      var asked = auth.signIns.length;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(auth.signIns, hasLength(asked));
      expect(auth.listeners, 0);
    });

    test('never retries a sign in failing after stop', () async {
      var auth = _Auth();
      var keeper = FestenaoFbIdentityAuthKeeper(
        auth,
        retryDelay: const Duration(milliseconds: 10),
      );
      var started = keeper.start();
      await _until(() => auth.signIns.isNotEmpty);
      await keeper.stop();
      await started;
      auth.failPending();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(auth.signIns, hasLength(1));
      expect(auth.listeners, 0);
    });
  });

  group('service account', () {
    test('refused by default', () async {
      var auth = _Auth(admin: true);
      var keeper = FestenaoFbIdentityAuthKeeper(auth);
      expect(keeper.hasAdminCredentials, isTrue);
      await expectLater(keeper.currentIdentity(), throwsUnsupportedError);
      await expectLater(keeper.ensureIdentity(), throwsUnsupportedError);
      await expectLater(keeper.start(), throwsUnsupportedError);
      await expectLater(keeper.ensureSignedIn(), throwsUnsupportedError);
      expect(auth.signIns, isEmpty);
    });

    test('allowed', () async {
      var auth = _Auth(admin: true);
      var keeper = FestenaoFbIdentityAuthKeeper(
        auth,
        allowServiceAccount: true,
      );
      var identity = await keeper.ensureIdentity();
      expect(identity.isServiceAccount, isTrue);
      expect(identity.serviceAccountProjectId, 'my-admin');
      expect((await keeper.currentIdentity())?.isServiceAccount, isTrue);
      await keeper.start();
      // A service account has no user.
      await expectLater(keeper.currentUser(), throwsUnsupportedError);
      await expectLater(keeper.ensureSignedIn(), throwsUnsupportedError);
      expect(auth.signIns, isEmpty);
      expect(auth.listeners, 0);
    });
  });

  group('providers', () {
    test('sign in on demand', () async {
      var firebaseContext = await initFirebaseServicesLocalSdb(
        sdbFactory: newSdbFactoryMemory(),
        projectId: 'festenao-riverpod-signed-in-test',
      ).init();
      var container = ProviderContainer(
        overrides: [...festenaoFirebaseContextOverrides(firebaseContext)],
      );
      addTearDown(() async {
        container.dispose();
        await firebaseContext.close();
      });
      container.listen(festenaoFirebaseSignedInUserProvider, (_, _) {});
      var user = await container.read(
        festenaoFirebaseSignedInUserProvider.future,
      );
      expect(user.isAnonymous, isTrue);
      var identity = await container.read(
        festenaoFbSignedInIdentityProvider.future,
      );
      expect(identity.userId, user.uid);
      expect((await firebaseContext.auth.onCurrentUser.first)?.uid, user.uid);
    });

    test('service account', () async {
      var auth = _Auth(admin: true);
      var container = ProviderContainer(
        overrides: [festenaoFirebaseAuthProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);
      container.listen(festenaoFbSignedInIdentityProvider, (_, _) {});
      await expectLater(
        container.read(festenaoFbSignedInIdentityProvider.future),
        throwsUnsupportedError,
      );

      var allowing = ProviderContainer(
        overrides: [
          festenaoFirebaseAuthProvider.overrideWithValue(auth),
          festenaoFbIdentityAuthKeeperProvider.overrideWithValue(
            FestenaoFbIdentityAuthKeeper(auth, allowServiceAccount: true),
          ),
        ],
      );
      addTearDown(allowing.dispose);
      allowing.listen(festenaoFbSignedInIdentityProvider, (_, _) {});
      allowing.listen(festenaoFirebaseSignedInUserProvider, (_, _) {});
      var identity = await allowing.read(
        festenaoFbSignedInIdentityProvider.future,
      );
      expect(identity.isServiceAccount, isTrue);
      await expectLater(
        allowing.read(festenaoFirebaseSignedInUserProvider.future),
        throwsUnsupportedError,
      );
      expect(auth.signIns, isEmpty);
    });
  });
}
