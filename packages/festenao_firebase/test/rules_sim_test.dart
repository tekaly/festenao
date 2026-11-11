import 'package:festenao_firebase/firestore_rules_sim.dart';
import 'package:festenao_firebase/firestore_rules_test_runner.dart'
    show FirestoreRulesSimTestContext;
import 'package:tekartik_firebase_firestore/firestore.dart';
import 'package:test/test.dart';

/// A reader over a map of documents.
class MapReader implements RulesDocumentReader {
  final Map<String, Map<String, Object?>> docs;
  var reads = 0;

  MapReader(this.docs);

  @override
  Future<Map<String, Object?>?> read(String path) async {
    reads++;
    return docs[path];
  }
}

void main() {
  group('evaluator', () {
    late FirestoreRules rules;
    late RulesEvaluator evaluator;
    setUp(() {
      rules = FirestoreRules()..denyAll();
      var signedIn = rules.function(
        'signedIn',
        [],
        (f) => requestAuth.isNotNull & requestAuthUid.isNotNull,
      );
      rules.match('/user/{userId}/{document=**}', (m) {
        m.allow([
          RulesMethod.read,
          RulesMethod.write,
        ], signedIn.call([]) & requestAuthUid.eq(m.v('userId')));
      });
      rules.match('/public/{docId}', (m) {
        m.allow([RulesMethod.get], true);
      });
      rules.match('/room/{roomId}', (m) {
        m.allow(
          [RulesMethod.read],
          rulesGet(
            docPath(['room', m.v('roomId'), 'member', requestAuthUid]),
          ).isNotNull,
        );
        m.allow([
          RulesMethod.create,
        ], requestResourceData.get('owner', '').eq(requestAuthUid));
        m.allow(
          [RulesMethod.update],
          resourceData.member('owner').eq(requestAuthUid) &
              requestResourceData.member('owner').eq(requestAuthUid),
        );
        m.match('/member/{memberId}', (mm) {
          mm.allow(
            [RulesMethod.read],
            rulesExists(
              docPath(['room', mm.v('roomId'), 'member', requestAuthUid]),
            ),
          );
        });
      });
      rules.match('/claims/{docId}', (m) {
        m.allow([
          RulesMethod.read,
        ], requestAuthToken.get('admin', false).eq(true));
        m.allow([
          RulesMethod.write,
        ], requestAuthToken.email.lower().eq('a@b.c'));
      });
      evaluator = RulesEvaluator(rules);
    });

    Future<bool> allowed(RulesRequest request, [MapReader? reader]) async =>
        (await evaluator.evaluate(request, reader ?? MapReader({}))).allowed;

    FirestoreRulesAuth auth(String uid, [Map<String, Object?>? token]) =>
        FirestoreRulesAuth(uid: uid, token: token);

    test('wildcards and auth', () async {
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.get,
            path: 'user/u1',
            auth: auth('u1'),
          ),
        ),
        isTrue,
      );
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.get,
            path: 'user/u1/data/d1',
            auth: auth('u1'),
          ),
        ),
        isTrue,
      );
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.get,
            path: 'user/u1',
            auth: auth('u2'),
          ),
        ),
        isFalse,
      );
      // Signed out: request.auth.uid errors, denied.
      expect(
        await allowed(
          RulesRequest(method: RulesMethod.get, path: 'user/u1', auth: null),
        ),
        isFalse,
      );
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.get,
            path: 'other/x',
            auth: auth('u1'),
          ),
        ),
        isFalse,
      );
    });

    test('list and unbound wildcard', () async {
      // The userId wildcard is bound on a list of a sub collection.
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.list,
            path: 'user/u1/data',
            auth: auth('u1'),
          ),
        ),
        isTrue,
      );
      // But unbound when listing the users.
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.list,
            path: 'user',
            auth: auth('u1'),
          ),
        ),
        isFalse,
      );
      // get only: no list.
      expect(
        await allowed(
          RulesRequest(method: RulesMethod.get, path: 'public/p1', auth: null),
        ),
        isTrue,
      );
      expect(
        await allowed(
          RulesRequest(method: RulesMethod.list, path: 'public', auth: null),
        ),
        isFalse,
      );
    });

    test('get, exists and access calls', () async {
      var reader = MapReader({
        'room/r1/member/u1': {'x': 1},
      });
      var decision = await evaluator.evaluate(
        RulesRequest(
          method: RulesMethod.get,
          path: 'room/r1',
          auth: auth('u1'),
        ),
        reader,
      );
      expect(decision.allowed, isTrue);
      expect(decision.accessCalls, 1);
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.get,
            path: 'room/r1',
            auth: auth('u2'),
          ),
          reader,
        ),
        isFalse,
      );
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.get,
            path: 'room/r1/member/u9',
            auth: auth('u1'),
          ),
          reader,
        ),
        isTrue,
      );
      // Missing member: get() null, exists false.
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.get,
            path: 'room/r2',
            auth: auth('u1'),
          ),
          reader,
        ),
        isFalse,
      );
    });

    test('create and update data', () async {
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.create,
            path: 'room/r1',
            auth: auth('u1'),
            requestResourceData: {'owner': 'u1'},
          ),
        ),
        isTrue,
      );
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.create,
            path: 'room/r1',
            auth: auth('u1'),
            requestResourceData: {'owner': 'u2'},
          ),
        ),
        isFalse,
      );
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.create,
            path: 'room/r1',
            auth: auth('u1'),
            requestResourceData: {},
          ),
        ),
        isFalse,
      );
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.update,
            path: 'room/r1',
            auth: auth('u1'),
            resourceData: {'owner': 'u1'},
            requestResourceData: {'owner': 'u1', 'name': 'x'},
          ),
        ),
        isTrue,
      );
      // Changing the owner is denied.
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.update,
            path: 'room/r1',
            auth: auth('u1'),
            resourceData: {'owner': 'u1'},
            requestResourceData: {'owner': 'u2'},
          ),
        ),
        isFalse,
      );
      // Missing member access on a map is an error, not null.
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.update,
            path: 'room/r1',
            auth: auth('u1'),
            resourceData: {},
            requestResourceData: {'owner': 'u1'},
          ),
        ),
        isFalse,
      );
      // Delete has no rule.
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.delete,
            path: 'room/r1',
            auth: auth('u1'),
            resourceData: {'owner': 'u1'},
          ),
        ),
        isFalse,
      );
    });

    test('token claims', () async {
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.get,
            path: 'claims/c',
            auth: auth('u1'),
          ),
        ),
        isFalse,
      );
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.get,
            path: 'claims/c',
            auth: auth('u1', {'admin': true}),
          ),
        ),
        isTrue,
      );
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.create,
            path: 'claims/c',
            auth: auth('u1', {'email': 'A@b.c'}),
            requestResourceData: {},
          ),
        ),
        isTrue,
      );
      // No email: member access error.
      expect(
        await allowed(
          RulesRequest(
            method: RulesMethod.create,
            path: 'claims/c',
            auth: auth('u1'),
            requestResourceData: {},
          ),
        ),
        isFalse,
      );
    });

    test('access call limit', () async {
      var rules = FirestoreRules();
      rules.match('/many/{docId}', (m) {
        var expr = lit(true);
        for (var i = 0; i < 11; i++) {
          expr = expr & rulesExists(docPath(['doc', 'd$i'])).not();
        }
        m.allow([RulesMethod.get], expr);
      });
      var evaluator = RulesEvaluator(rules);
      var decision = await evaluator.evaluate(
        RulesRequest(method: RulesMethod.get, path: 'many/x', auth: null),
        MapReader({}),
      );
      expect(decision.allowed, isFalse);
      expect(decision.trace.single, contains('Too many document access calls'));
      decision = await evaluator.evaluate(
        RulesRequest(
          method: RulesMethod.get,
          path: 'many/x',
          auth: null,
          multi: true,
        ),
        MapReader({}),
      );
      expect(decision.allowed, isTrue);
    });

    test('access call limit of a query', () async {
      // A query is a single request for the limit: 10, not the 20 of
      // batches and transactions.
      var rules = FirestoreRules();
      rules.match('/many/{docId}', (m) {
        var expr = lit(true);
        for (var i = 0; i < 11; i++) {
          expr = expr & rulesExists(docPath(['doc', 'd$i'])).not();
        }
        m.allow([RulesMethod.list], expr);
      });
      var ctx = await FirestoreRulesSimTestContext.create(rules: rules);
      try {
        await ctx.adminFirestore.doc('many/x').set({'a': 1});
        await expectLater(
          ctx.firestore.collection('many').get(),
          throwsA(isA<FirestoreRulesPermissionDeniedException>()),
        );
      } finally {
        await ctx.close();
      }
    });

    test('error absorption', () async {
      var rules = FirestoreRules();
      rules.match('/t/{docId}', (m) {
        // Error on the left, false on the right: false.
        m.allow([RulesMethod.get], requestAuthUid.eq('x') & lit(false));
        // Error on the left, true on the right: true.
        m.allow([RulesMethod.create], requestAuthUid.eq('x') | lit(true));
        // Error on the right after a true left: error.
        m.allow([RulesMethod.update], lit(true) & requestAuthUid.eq('x'));
      });
      var evaluator = RulesEvaluator(rules);
      Future<bool> run(RulesMethod method) async => (await evaluator.evaluate(
        RulesRequest(
          method: method,
          path: 't/x',
          auth: null,
          requestResourceData: {},
          resourceData: {},
        ),
        MapReader({}),
      )).allowed;
      expect(await run(RulesMethod.get), isFalse);
      expect(await run(RulesMethod.create), isTrue);
      expect(await run(RulesMethod.update), isFalse);
    });

    test('timestamp year, month and day are utc', () async {
      // The engine reads them in UTC: around midnight UTC the local date
      // differs whatever the time zone of the machine (one of the two times
      // below is on another day in any time zone but UTC).
      var rules = FirestoreRules();
      rules.match('/t/{docId}', (m) {
        m.allow([RulesMethod.get], requestTime.call('year').eq(2026));
        m.allow([RulesMethod.list], requestTime.call('month').eq(12));
        m.allow([RulesMethod.create], requestTime.call('day').eq(31));
      });
      var evaluator = RulesEvaluator(rules);
      Future<bool> run(RulesMethod method, DateTime time) async =>
          (await evaluator.evaluate(
            RulesRequest(
              method: method,
              path: method == RulesMethod.list ? 't' : 't/x',
              auth: null,
              requestResourceData: method == RulesMethod.create ? {} : null,
              time: Timestamp.fromDateTime(time),
            ),
            MapReader({}),
          )).allowed;
      for (var time in [
        DateTime.utc(2026, 12, 31, 0, 30),
        DateTime.utc(2026, 12, 31, 23, 30),
      ]) {
        for (var method in [
          RulesMethod.get,
          RulesMethod.list,
          RulesMethod.create,
        ]) {
          expect(await run(method, time), isTrue, reason: '$method $time');
        }
      }
    });
  });

  group('request resource data', () {
    test('set, merge and update', () {
      expect(computeRequestResourceData(existing: {'a': 1}, data: {'b': 2}), {
        'b': 2,
      });
      expect(
        computeRequestResourceData(
          existing: {
            'a': 1,
            'sub': {'x': 1},
          },
          data: {
            'b': 2,
            'sub': {'y': 2},
          },
          merge: true,
        ),
        {
          'a': 1,
          'b': 2,
          'sub': {'x': 1, 'y': 2},
        },
      );
      expect(
        computeRequestResourceData(
          existing: {
            'a': 1,
            'sub': {'x': 1},
          },
          data: {'sub.y': 2, 'a': FieldValue.delete},
          update: true,
        ),
        {
          'sub': {'x': 1, 'y': 2},
        },
      );
      var now = Timestamp(1, 0);
      expect(
        computeRequestResourceData(
          existing: null,
          data: {
            't': FieldValue.serverTimestamp,
            'l': FieldValue.arrayUnion([1]),
          },
          now: now,
        ),
        {
          't': now,
          'l': [1],
        },
      );
      expect(
        computeRequestResourceData(
          existing: {
            'l': [1, 2],
          },
          data: {
            'l': FieldValue.arrayRemove([1]),
          },
          update: true,
        ),
        {
          'l': [2],
        },
      );
    });
  });
}
