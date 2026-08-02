import 'dart:async';

import 'package:dev_test/test.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_support.dart';

import 'project_access_test_runner.dart';

/// Context for the user private data test runner.
class UserPrvAccessTestContext {
  /// Auth service.
  final FirebaseAuth auth;

  /// Firestore service.
  final Firestore firestore;

  /// Constructor.
  UserPrvAccessTestContext({required this.auth, required this.firestore});
}

/// First test user of the user private data test runner.
const userPrvTestEmail = 'user-prv-1@festenao-test.local';

/// Second test user of the user private data test runner.
const userPrvTestEmail2 = 'user-prv-2@festenao-test.local';

/// Test password of the user private data test users.
const userPrvTestPassword = 'test1234';

/// Checks the per user private data rules:
///
/// ```
/// match /{top}/{topId}/user_prv/{userId}/{document=**} {
///   allow read, write: if signedIn() && request.auth.uid == userId;
/// }
/// ```
///
/// Shared by the api and no-api contexts, both declare the same rule.
///
/// Dedicated users ([userPrvTestEmail]/[userPrvTestEmail2]) are used so that
/// signing in/out here does not interfere with the other runners.
void userPrvAccessTestRunner(
  FutureOr<UserPrvAccessTestContext> Function() contextBuilder, {
  bool rulesSupported = true,
  String appId = 'test_app',
  String email = userPrvTestEmail,
  String otherEmail = userPrvTestEmail2,
}) {
  late UserPrvAccessTestContext testContext;
  late FirebaseAuth auth;
  late Firestore firestore;

  setUp(() async {
    initTkCmsFsBuilders();
    testContext = await contextBuilder();
    auth = testContext.auth;
    firestore = testContext.firestore;
  });

  Future<void> expectPermissionError(Future<void> Function() action) async {
    if (rulesSupported) {
      try {
        await action();
        fail('should fail before');
      } catch (e) {
        expect(isExceptionPermissionError(e), isTrue, reason: '$e');
      }
    } else {
      await action();
    }
  }

  /// Sign in (or up) a given user, returns its user id.
  Future<String> signInEmail(String email) async {
    var userCredential = await auth.signInOrUpWithEmailAndPassword(
      email: email,
      password: userPrvTestPassword,
    );
    return userCredential.user.uid;
  }

  test('user private data', () async {
    // Sign in the other user once to get its user id.
    var otherUserId = await signInEmail(otherEmail);
    await auth.signOut();

    var userId = await signInEmail(email);

    String userPrvPath(String userId, [String? subPath]) =>
        'app/$appId/user_prv/$userId${subPath == null ? '' : '/$subPath'}';

    // The user private root document itself (`{document=**}` also matches
    // an empty sub path).
    var ownRootRef = firestore.doc(userPrvPath(userId));
    // A document in a sub collection.
    var ownDataRef = firestore.doc(userPrvPath(userId, 'data/test_data'));
    // A deeper document (recursive wildcard).
    var ownDeepRef = firestore.doc(
      userPrvPath(userId, 'data/test_data/sub/deep_data'),
    );
    // Another user private data.
    var otherDataRef = firestore.doc(
      userPrvPath(otherUserId, 'data/test_data'),
    );

    // A signed in user can write and read its own private data, at any depth.
    for (var ref in [ownRootRef, ownDataRef, ownDeepRef]) {
      await ref.set({'name': 'test_user_prv'});
      var snapshot = await ref.get();
      expect(snapshot.exists, isTrue, reason: ref.path);
      expect(snapshot.data['name'], 'test_user_prv', reason: ref.path);
    }

    // But not another user private data.
    await expectPermissionError(() async {
      await otherDataRef.set({'name': 'nope'});
    });
    await expectPermissionError(() async {
      await otherDataRef.get();
    });

    await auth.signOut();

    // Signed out, nothing is readable nor writable.
    await expectPermissionError(() async {
      await ownDataRef.get();
    });
    await expectPermissionError(() async {
      await ownDataRef.set({'name': 'nope'});
    });

    // The other user can access its own private data, not ours.
    await signInEmail(otherEmail);
    await otherDataRef.set({'name': 'test_user_prv_other'});
    expect((await otherDataRef.get()).exists, isTrue);
    await expectPermissionError(() async {
      await ownDataRef.get();
    });

    // Cleanup, each user deletes its own private data.
    await otherDataRef.delete();
    await auth.signOut();
    await signInEmail(email);
    for (var ref in [ownDeepRef, ownDataRef, ownRootRef]) {
      await ref.delete();
    }
    await auth.signOut();
  });
}
