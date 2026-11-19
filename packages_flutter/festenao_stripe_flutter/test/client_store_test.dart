import 'package:festenao_stripe_flutter/festenao_stripe_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/sdb.dart';

const _testKey = 'sk_test_0123456789abcdefWXYZ';
const _liveKey = 'rk_live_0123456789abcdefLIVE';

void main() {
  group('client', () {
    test('key checks and hint', () {
      expect(stripeManagerKeyError(_testKey), isNull);
      expect(stripeManagerKeyError(_liveKey), isNull);
      expect(stripeManagerKeyError(''), isNotNull);
      expect(stripeManagerKeyError('pk_test_0123456789abcdef'), isNotNull);
      expect(stripeManagerKeyError('sk_test_short'), isNotNull);
      expect(stripeManagerKeyError('sk_other_0123456789abcdef'), isNotNull);
      expect(stripeManagerKeyHint(_testKey), 'sk_test_…WXYZ');
      expect(stripeManagerKeyHint('sk_test_abc'), 'sk_test_…');
      var client = StripeManagerClient(id: 'a', name: 'A', secretKey: _liveKey);
      expect(client.isLive, isTrue);
      expect(client.isRestricted, isTrue);
      expect(client.modeLabel, 'LIVE');
      expect(client.toString(), isNot(contains(_liveKey)));
    });
  });

  group('store', () {
    late SdbFactory factory;
    setUp(() {
      factory = newSdbFactoryMemory();
    });

    test('add, select, delete, persisted', () async {
      var builtIn = StripeManagerClient(
        id: 'builtin_live',
        name: 'Built-in live',
        secretKey: _liveKey,
        builtIn: true,
      );
      var store = StripeManagerClientStore(
        factory: factory,
        builtInClients: [builtIn],
      );
      await store.ready();
      // Never starts on a live key.
      expect(store.current.value, isNull);
      expect(store.clients.value, [builtIn]);

      var added = await store.addClient(name: 'Mine', secretKey: ' $_testKey ');
      expect(added.secretKey, _testKey);
      expect(store.clients.value.map((c) => c.name), ['Built-in live', 'Mine']);
      await store.selectClient(added.id);
      expect(store.current.value?.id, added.id);
      await expectLater(
        store.deleteClient(builtIn.id),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        store.addClient(name: 'Bad', secretKey: 'pk_test_0123456789abcdef'),
        throwsA(isA<ArgumentError>()),
      );
      await store.close();

      // A new store reads the clients and the current one back.
      store = StripeManagerClientStore(
        factory: factory,
        builtInClients: [builtIn],
      );
      await store.ready();
      expect(store.current.value?.id, added.id);
      expect(store.clients.value.last.secretKey, _testKey);

      await store.selectClient(builtIn.id);
      await store.close();
      store = StripeManagerClientStore(
        factory: factory,
        builtInClients: [builtIn],
      );
      await store.ready();
      // The live one when it was chosen.
      expect(store.current.value?.id, builtIn.id);

      await store.selectClient(added.id);
      await store.deleteClient(added.id);
      expect(store.current.value, isNull);
      expect(store.clients.value, [builtIn]);
      await store.close();
    });

    test('first test client by default', () async {
      var store = StripeManagerClientStore(
        factory: factory,
        builtInClients: [
          StripeManagerClient(
            id: 'live',
            name: 'Live',
            secretKey: _liveKey,
            builtIn: true,
          ),
          StripeManagerClient(
            id: 'test',
            name: 'Test',
            secretKey: _testKey,
            builtIn: true,
          ),
        ],
      );
      await store.ready();
      expect(store.current.value?.id, 'test');
      await store.close();
    });
  });
}
