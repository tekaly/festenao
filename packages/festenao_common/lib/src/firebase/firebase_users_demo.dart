import 'package:tekartik_firebase_auth/auth_admin.dart';

/// The users [fillDemoFirebaseUsers] creates: `alice` and `bob` match the
/// `user` documents of the firestore demo, the others show what a listing
/// marks — an unverified email, a disabled user, one with a phone only.
List<FirebaseAuthCreateUserRequest> demoFirebaseUserRequests() => [
  FirebaseAuthCreateUserRequest(
    uid: 'alice',
    email: 'alice@example.com',
    displayName: 'Alice',
    emailVerified: true,
    password: 'alice-password',
    photoURL: 'https://example.com/alice.png',
  ),
  FirebaseAuthCreateUserRequest(
    uid: 'bob',
    email: 'bob@example.com',
    displayName: 'Bob',
    emailVerified: true,
    password: 'bob-password',
  ),
  FirebaseAuthCreateUserRequest(
    uid: 'carol',
    email: 'carol@example.com',
    displayName: 'Carol',
    password: 'carol-password',
  ),
  FirebaseAuthCreateUserRequest(
    uid: 'dave',
    email: 'dave@example.com',
    displayName: 'Dave (disabled)',
    emailVerified: true,
    disabled: true,
  ),
  FirebaseAuthCreateUserRequest(
    uid: 'erin',
    displayName: 'Erin',
    phoneNumber: '+33600000000',
  ),
];

/// The uid of the anonymous user [fillDemoFirebaseUsers] adds when the
/// backend can mark one as such.
const demoFirebaseAnonymousUid = 'anonymous-visitor';

/// Creates the demo users, [demoFirebaseUserRequests], in [auth].
///
/// A local backend ([FirebaseAuthLocalAdmin], the sdb or sembast one) also
/// gets an anonymous user, [demoFirebaseAnonymousUid], which the admin api
/// cannot create.
Future<void> fillDemoFirebaseUsers(FirebaseAuthAdmin auth) async {
  for (var request in demoFirebaseUserRequests()) {
    await auth.createUser(request);
  }
  if (auth is FirebaseAuthLocalAdmin) {
    await auth.setUser(demoFirebaseAnonymousUid, isAnonymous: true);
  }
}
