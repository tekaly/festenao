import 'dart:convert';

import 'package:festenao_common/firebase/firebase_service_account.dart';
import 'package:test/test.dart';

Map<String, Object?> _serviceAccount(String projectId) => {
  'type': 'service_account',
  'project_id': projectId,
  'private_key_id': 'k-$projectId',
  'private_key':
      '-----BEGIN PRIVATE KEY-----\nfake\n-----END PRIVATE KEY-----\n',
  'client_email': 'admin@$projectId.iam.gserviceaccount.com',
};

void main() {
  group('enc', () {
    test('round trip', () {
      var plain = _serviceAccount('p1');
      var enc = festenaoServiceAccountEncMap(plain);
      expect(enc.keys, [
        'type',
        'project_id',
        'client_email',
        'private_key_id',
        'password',
        'enc',
      ]);
      expect(enc['type'], festenaoServiceAccountEncType);
      expect(enc['project_id'], 'p1');
      expect(enc['client_email'], 'admin@p1.iam.gserviceaccount.com');
      expect(enc['private_key_id'], 'k-p1');
      expect((enc['password'] as String).length, 32);
      expect(jsonEncode(enc), isNot(contains('PRIVATE KEY')));
      expect(festenaoServiceAccountMapIsEnc(enc), isTrue);
      expect(festenaoServiceAccountMapIsEnc(plain), isFalse);
      expect(festenaoServiceAccountMapIsEnc(null), isFalse);

      expect(festenaoServiceAccountMapFromEncMap(enc), plain);
      expect(festenaoServiceAccountMapDecode(enc), plain);
      expect(festenaoServiceAccountMapDecode(plain), same(plain));
      expect(festenaoServiceAccountMapDecode(null), isNull);
      expect(festenaoServiceAccountMapError(enc), isNull);
      expect(festenaoServiceAccountTextError(jsonEncode(enc)), isNull);

      // A random password: never the same twice.
      expect(festenaoServiceAccountEncMap(plain)['enc'], isNot(enc['enc']));
      // Obfuscating the obfuscated json obfuscates the account.
      var again = festenaoServiceAccountEncMap(enc, password: 'p' * 16);
      expect(again['password'], 'p' * 16);
      expect(festenaoServiceAccountMapFromEncMap(again), plain);
    });

    test('given password', () {
      var plain = _serviceAccount('p1');
      var enc = festenaoServiceAccountEncMap(
        plain,
        password: '0123456789abcdef',
      );
      expect(enc['password'], '0123456789abcdef');
      expect(festenaoServiceAccountMapFromEncMap(enc), plain);
      expect(
        () => festenaoServiceAccountEncMap(plain, password: 'short'),
        throwsArgumentError,
      );
    });

    test('refuses a broken service account', () {
      expect(
        () => festenaoServiceAccountEncMap({'project_id': 'p1'}),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('no client_email'),
          ),
        ),
      );
    });

    test('errors never quote a value', () {
      var plain = _serviceAccount('p1');
      var enc = festenaoServiceAccountEncMap(plain);

      Matcher stateError(Object matcher) => throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(matcher, isNot(contains('PRIVATE KEY'))),
        ),
      );
      // Not obfuscated.
      expect(
        () => festenaoServiceAccountMapFromEncMap(plain),
        stateError(contains('Not an obfuscated')),
      );
      // A wrong password.
      var wrongPassword = {...enc, 'password': 'x' * 32};
      expect(
        () => festenaoServiceAccountMapFromEncMap(wrongPassword),
        stateError(contains('does not decrypt')),
      );
      expect(
        festenaoServiceAccountMapError(wrongPassword),
        contains('does not decrypt'),
      );
      // A damaged text.
      expect(
        () => festenaoServiceAccountMapFromEncMap({...enc, 'enc': 'abc'}),
        stateError(contains('does not decrypt')),
      );
      // Another project in clear.
      expect(
        () => festenaoServiceAccountMapFromEncMap({...enc, 'project_id': 'p2'}),
        stateError(contains('not the one of project p2')),
      );
      // The clear project id is optional.
      expect(
        festenaoServiceAccountMapFromEncMap({...enc}..remove('project_id')),
        plain,
      );
      // A broken account inside.
      var broken = festenaoServiceAccountEncMap(plain, password: 'p' * 16);
      broken['enc'] = festenaoServiceAccountEncMap(
        plain,
        password: 'p' * 16,
      )['enc'];
      expect(festenaoServiceAccountMapError(broken), isNull);
    });
  });
}
