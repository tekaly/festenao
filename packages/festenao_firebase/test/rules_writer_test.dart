import 'package:festenao_firebase/festenao_firestore_rules.dart';
import 'package:test/test.dart';

void main() {
  group('expression', () {
    test('operators and precedence', () {
      expect(
        (request.auth.isNotNull & request.auth.uid.eq('x')).toRulesText(),
        "request.auth != null && request.auth.uid == 'x'",
      );
      expect(
        ((lit(true) | lit(false)) & lit(true)).toRulesText(),
        '(true || false) && true',
      );
      expect(
        (lit(true) | (lit(false) & lit(true))).toRulesText(),
        'true || false && true',
      );
      expect((~request.auth.isNull).toRulesText(), '!(request.auth == null)');
      expect((lit(1) + lit(2)).eq(3).toRulesText(), '1 + 2 == 3');
      expect(lit('a').isIn(['a', 'b']).toRulesText(), "'a' in ['a', 'b']");
      expect(
        resource.data.get('admin', false).eq(true).toRulesText(),
        "resource.data.get('admin', false) == true",
      );
      expect(
        resource.data
            .get('userAccess', const <String, Object?>{})
            .get('admin', false)
            .toRulesText(),
        "resource.data.get('userAccess', {}).get('admin', false)",
      );
      expect(lit('a').ternary(1, 2).toRulesText(), "'a' ? 1 : 2");
      expect(
        requestAuthToken.email.lower().toRulesText(),
        'request.auth.token.email.lower()',
      );
      expect(lit("it's").toRulesText(), r"'it\'s'");
      expect(
        request.member('time').isType('timestamp').toRulesText(),
        'request.time is timestamp',
      );
    });

    test('path', () {
      expect(
        docPath([
          const RulesVar('top'),
          'access',
          'a/b',
          requestAuthUid,
        ]).toRulesText(),
        r'/databases/$(database)/documents/$(top)/access/a/b/$(request.auth.uid)',
      );
      expect(
        rulesGet(docPath(['a', 'b'])).toRulesText(),
        r'get(/databases/$(database)/documents/a/b)',
      );
      expect(
        rulesExists(docPath(['a', 'b'])).data.toRulesText(),
        r'exists(/databases/$(database)/documents/a/b).data',
      );
    });
  });

  group('rules', () {
    test('file', () {
      var rules = FirestoreRules();
      rules.headerComment('Test rules');
      rules.denyAll();
      var signedIn = rules.function(
        'signedIn',
        [],
        (f) => requestAuth.isNotNull & requestAuthUid.isNotNull,
      );
      var owns = rules.function('owns', ['userId'], (f) {
        var doc = f.let('doc', rulesGet(docPath(['user', f.param('userId')])));
        return doc.isNotNull & doc.data.get('owner', '').eq(requestAuthUid);
      });
      rules.match('/user/{userId}', (m) {
        m.comment('Users');
        m.allow([RulesMethod.read], signedIn.call([]));
        m.allow([RulesMethod.write], owns.call([m.v('userId')]));
        m.match('/data/{document=**}', (d) {
          d.allow([
            RulesMethod.read,
            RulesMethod.write,
          ], signedIn.call([]) & requestAuthUid.eq(d.v('userId')));
        });
      });
      expect(rules.toRulesText(), '''
rules_version = '2';

// Test rules
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }

    function signedIn() {
      return request.auth != null && request.auth.uid != null;
    }

    function owns(userId) {
      let doc = get(/databases/\$(database)/documents/user/\$(userId));
      return doc != null && doc.data.get('owner', '') == request.auth.uid;
    }

    match /user/{userId} {
      // Users
      allow read: if signedIn();
      allow write: if owns(userId);

      match /data/{document=**} {
        allow read, write: if signedIn() && request.auth.uid == userId;
      }
    }
  }
}
''');
    });

    test('unbound wildcard', () {
      var rules = FirestoreRules();
      rules.match('/user/{userId}', (m) {
        expect(() => m.v('other'), throwsArgumentError);
        expect(m.v('userId').name, 'userId');
        expect(m.v('database').name, 'database');
      });
    });

    test('presets compile', () {
      for (var entry in festenaoRulesPresets.entries) {
        var text = entry.value().toRulesText();
        expect(text, startsWith("rules_version = '2';"), reason: entry.key);
        expect(text, contains('function signedIn()'), reason: entry.key);
      }
    });

    test('levels', () {
      expect(
        const TkCmsRulesLevel(0).pattern('/{entity}/{entityId}'),
        '/{entity}/{entityId}',
      );
      expect(
        const TkCmsRulesLevel(1).pattern('/{entity}/{entityId}'),
        '/{top}/{topId}/{entity}/{entityId}',
      );
      expect(
        const TkCmsRulesLevel(2).pattern('/{entity}/{entityId}'),
        '/{top}/{topId}/{sub}/{subId}/{entity}/{entityId}',
      );
      expect(const TkCmsRulesLevel(3).parentParams, [
        'top',
        'topId',
        'sub',
        'subId',
        'sub2',
        'sub2Id',
      ]);
      expect(
        const TkCmsRulesLevel(0).functionName('hasEntityAccess'),
        'hasEntityAccess',
      );
      expect(
        const TkCmsRulesLevel(1).functionName('hasEntityAccess'),
        'subHasEntityAccess',
      );
      expect(
        const TkCmsRulesLevel(2).functionName('hasEntityAccess'),
        'sub2HasEntityAccess',
      );
      var tkCms = TkCmsFirestoreRules(denyAll: true);
      tkCms.level(2)
        ..addEntityRules()
        ..addUserPrvRules();
      var text = tkCms.toRulesText();
      expect(
        text,
        contains(
          'function sub2HasEntityAccess(top, topId, sub, subId, entity, entityId, userId, access)',
        ),
      );
      expect(
        text,
        contains('match /{top}/{topId}/{sub}/{subId}/{entity}/{entityId} {'),
      );
    });
  });
}
