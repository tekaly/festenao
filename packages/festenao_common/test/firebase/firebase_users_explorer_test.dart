import 'package:festenao_common/data/object_editor.dart' show ReadOnlyException;
import 'package:festenao_common/firebase/firebase_users_explorer.dart';
import 'package:tekartik_firebase_auth/auth_mixin.dart';
import 'package:tekartik_firebase_auth_sdb/auth_sdb.dart';
import 'package:test/test.dart';

/// A backend implementing nothing but the uid and the email.
class _BareUserRecord with FirebaseUserRecordDefaultMixin {
  @override
  final String uid;

  @override
  final String? email;

  _BareUserRecord(this.uid, this.email);
}

Future<FirebaseAuthSdb> _newAuth() async {
  var auth = newFirebaseAuthSdbMemory() as FirebaseAuthSdb;
  await fillDemoFirebaseUsers(auth);
  return auth;
}

void main() {
  group('FirebaseUsersExplorer', () {
    test('lists the users page by page', () async {
      var auth = await _newAuth();
      var explorer = FirebaseUsersExplorer(auth: auth, pageSize: 4);
      expect(explorer.canList, isTrue);
      expect(explorer.canWrite, isTrue);

      var page = await explorer.list();
      expect(page.users.map((user) => user.uid), [
        'alice',
        'anonymous-visitor',
        'bob',
        'carol',
      ]);
      expect(page.hasMore, isTrue);
      page = await explorer.list(pageToken: page.nextPageToken);
      expect(page.users.map((user) => user.uid), ['dave', 'erin']);
      expect(page.hasMore, isFalse);
      await auth.app.delete();
    });

    test('reads what each user holds', () async {
      var auth = await _newAuth();
      var explorer = FirebaseUsersExplorer(auth: auth);
      var users = {
        for (var user in (await explorer.list()).users) user.uid: user,
      };
      var alice = users['alice']!;
      expect(alice.label, 'Alice');
      expect(alice.emailVerified, isTrue);
      expect(alice.fields['photoURL'], 'https://example.com/alice.png');
      expect(users['carol']!.emailVerified, isFalse);
      expect(users['dave']!.isDisabled, isTrue);
      expect(users['erin']!.label, 'Erin');
      expect(users['erin']!.fields['phoneNumber'], '+33600000000');
      expect(users['erin']!.email, isNull);
      var anonymous = users[demoFirebaseAnonymousUid]!;
      expect(anonymous.isAnonymous, isTrue);
      expect(anonymous.label, demoFirebaseAnonymousUid);
      await auth.app.delete();
    });

    test('finds a user by uid or email', () async {
      var auth = await _newAuth();
      var explorer = FirebaseUsersExplorer(auth: auth);
      expect((await explorer.find('bob'))!.email, 'bob@example.com');
      expect((await explorer.find(' bob@example.com '))!.uid, 'bob');
      expect(await explorer.find('nobody@example.com'), isNull);
      expect(await explorer.find('nobody'), isNull);
      expect(await explorer.find(''), isNull);
      await auth.app.delete();
    });

    test('creates and deletes a user', () async {
      var auth = await _newAuth();
      var explorer = FirebaseUsersExplorer(auth: auth);
      var created = await explorer.create(
        FirebaseAuthCreateUserRequest(
          uid: 'frank',
          email: 'frank@example.com',
          displayName: 'Frank',
        ),
      );
      expect(created.label, 'Frank');
      expect((await explorer.get('frank'))!.email, 'frank@example.com');
      await explorer.delete('frank');
      expect(await explorer.get('frank'), isNull);
      await auth.app.delete();
    });

    test('a read only explorer writes nothing', () async {
      var auth = await _newAuth();
      var explorer = FirebaseUsersExplorer(auth: auth).readOnly;
      expect(explorer.canWrite, isFalse);
      expect(explorer.canList, isTrue);
      await expectLater(
        explorer.create(FirebaseAuthCreateUserRequest(uid: 'frank')),
        throwsA(isA<ReadOnlyException>()),
      );
      await expectLater(
        explorer.delete('alice'),
        throwsA(isA<ReadOnlyException>()),
      );
      expect(await explorer.get('alice'), isNotNull);
      await auth.app.delete();
    });
  });

  test('keeps the fields a backend implements', () {
    var entry = FirebaseUserEntry(_BareUserRecord('1234', 'me@example.com'));
    expect(entry.fields, {'uid': '1234', 'email': 'me@example.com'});
    expect(entry.label, 'me@example.com');
    expect(entry.isAnonymous, isFalse);
    expect(entry.isDisabled, isFalse);
  });
}
