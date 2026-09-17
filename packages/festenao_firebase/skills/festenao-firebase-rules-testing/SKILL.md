---
name: festenao-firebase-rules-testing
description: >-
  Use when testing firestore security rules with festenao_firebase: the
  in-memory simulator (FirestoreRulesSimulator, RulesEnforcedFirestore,
  FirestoreRulesSimTestContext), the emulator harness (FirestoreRulesEmulator,
  FirestoreRulesEmulatorTestContext, owner and user contexts, loadRules, custom
  claims), the shared FirestoreRulesTestContext (firestore, adminFirestore,
  signInOrUp, setRules), expectPermissionDenied and
  runFestenaoFirestoreRulesTests, plus what the simulator does and does not
  replicate.
---

# festenao_firebase rules testing

A rules file is worth what its tests say. `festenao_firebase` evaluates the
same `FirestoreRules` object two ways: an in-memory simulator that replicates
the rules engine (no emulator, milliseconds) and the firebase emulator itself
(the reference). Both expose the same `FirestoreRulesTestContext`, so one
suite runs on both: the simulator run is what a normal test run costs, the
emulator run is what proves the simulator right.

## Guidelines

* Import `package:festenao_firebase/firestore_rules_test_runner.dart` — it
  re-exports the rules, the simulator, the emulator and the contexts, plus
  `expectPermissionDenied` and `runFestenaoFirestoreRulesTests`. For a
  non-test use, `firestore_rules_sim.dart` and `firestore_rules_emulator.dart`
  are the narrower imports.
* `FirestoreRulesTestContext` is what a rules test needs: `firestore` (rules
  enforced, acting as the signed in user), `adminFirestore` (bypasses the
  rules, seeds what the api would write), `signInOrUp(email)` returning the
  uid, `signOut()`, `setRules(rules)` / `setRulesText(text)`,
  `setCustomUserClaims(uid, claims)` and `close()`.
* `FirestoreRulesSimTestContext.create(rules: ...)` is the memory one,
  `FirestoreRulesEmulatorTestContext.create(rules: ...)` the emulator one.
  Guard an emulator test with `FirestoreRulesEmulator.isSupported()` and give
  it a generous `Timeout`; keep it `@TestOn('vm')`.
* The shape of a rules test: seed through `adminFirestore` (what the api
  does), act through `firestore` as a user, assert what is readable and
  `expectPermissionDenied(() => ...)` on what is not. Sign in as a second
  user to check that somebody else is refused, and `signOut()` to check what
  the world sees.
* Test the denials, not only the grants: a rule file that allows everything
  passes every happy path. Each test should name one rule.
* `runFestenaoFirestoreRulesTests(contextBuilder)` is the suite of the
  festenao presets (entities, access, invites, public flags, private data),
  run per preset; `setRules:` overrides what a preset group loads, which is
  how the legacy hand written files are checked against the generated ones.
  An app's own rules deserve their own small suite next to it.
* Give the app suite its own library (`lib/test/<app>_firestore_rules_test.
  dart`) and two thin entry points, `test/firestore_rules_sim_test.dart` and
  `test/firestore_rules_emulator_test.dart`: same tests, two backends.
* Add a test asserting the generated file matches the generator
  (`File('firestore.rules').readAsString()` against `toRulesText()`): rules
  that pass while the deployed file is stale prove nothing.
* The simulator replicates: nested matches, single and recursive wildcards
  (unbound on `list`, using one is an evaluation error), any matching `allow`
  grants, evaluation errors deny, `&&`/`||` short circuit, `get()` of a
  missing document as `null`, member access on a missing key as an error,
  `get()`/`exists()` cached per request and capped at 10 documents (20 in
  batches and transactions), `resource` (before) vs `request.resource`
  (after, merges and field values resolved), batches and transactions checked
  against the state before them. Not supported: `collectionGroup`,
  `getAfter`.
* Bypassing the rules to seed is not a custom claim: the emulator takes the
  `owner` token (`newOwnerContext()`) and the simulator hands out the
  unwrapped firestore. `setCustomUserClaims` is for the rules that read
  `request.auth.token.<claim>`, and the user must sign in again afterwards.
* `dart run tool/start_rules_emulator.dart [preset]` keeps an emulator
  running between runs; the emulator tests reuse it.

## Examples

### A suite, run on both backends

```dart
// lib/test/playelio_firestore_rules_test.dart
library;

import 'package:festenao_firebase/firestore_rules_test_runner.dart';
import 'package:test/test.dart';

export 'package:festenao_firebase/firestore_rules_test_runner.dart';

/// Runs the playelio rules tests on the context [contextBuilder] creates.
void runPlayelioFirestoreRulesTests(
  FirestoreRulesTestContextBuilder contextBuilder,
) {
  late FirestoreRulesTestContext ctx;
  const app = 'playelio-dev';
  const playlistPath = 'app/$app/playlist/p1';
  const syncedPath = '$playlistPath/data/synced';
  const publicFlagPath =
      'app/$app/access/playlist/entity_id/p1/public_access/public';
  String accessPath(String uid) =>
      'app/$app/access/playlist/entity_id/p1/user_access/$uid';

  setUpAll(() async => ctx = await contextBuilder());
  tearDownAll(() async => ctx.close());
  setUp(() async {
    await ctx.signOut();
    for (var path in [publicFlagPath, syncedPath, playlistPath]) {
      await ctx.adminFirestore.doc(path).delete();
    }
  });

  /// What the api does when creating a playlist and granting access.
  Future<void> apiCreatePlaylist(String uid) async {
    await ctx.adminFirestore.doc(playlistPath).set({'name': 'p1'});
    await ctx.adminFirestore.doc(accessPath(uid)).set({
      'read': true,
      'write': true,
      'admin': true,
    });
  }

  test('a client cannot create a playlist, the api does', () async {
    var uid = await ctx.signInOrUp('creator@playelio.test');
    await expectPermissionDenied(
      () => ctx.firestore.doc(playlistPath).set({'name': 'mine'}),
    );
    await apiCreatePlaylist(uid);
    expect((await ctx.firestore.doc(playlistPath).get()).data, {'name': 'p1'});
  });

  test('a public playlist is readable by anyone', () async {
    var owner = await ctx.signInOrUp('owner@playelio.test');
    await apiCreatePlaylist(owner);
    await ctx.signOut();
    await expectPermissionDenied(() => ctx.firestore.doc(playlistPath).get());

    await ctx.adminFirestore.doc(publicFlagPath).set({'read': true});
    // Anyone reads the flag and the playlist, and writes neither.
    expect((await ctx.firestore.doc(publicFlagPath).get()).data, {
      'read': true,
    });
    expect((await ctx.firestore.doc(playlistPath).get()).data, {'name': 'p1'});
    await expectPermissionDenied(
      () => ctx.firestore.doc(syncedPath).set({'v': 2}),
    );
  });
}
```

```dart
// test/firestore_rules_sim_test.dart
import 'package:playelio_firebase/playelio_firestore_rules.dart';
import 'package:playelio_firebase/test/playelio_firestore_rules_test.dart';
import 'package:test/test.dart';

void main() {
  group('sim', () {
    runPlayelioFirestoreRulesTests(
      () => FirestoreRulesSimTestContext.create(rules: playelioFirestoreRules()),
    );
  });
}
```

```dart
// test/firestore_rules_emulator_test.dart
@TestOn('vm')
library;

import 'dart:io';

import 'package:playelio_firebase/playelio_firestore_rules.dart';
import 'package:playelio_firebase/test/playelio_firestore_rules_test.dart';
import 'package:test/test.dart';

Future<void> main() async {
  if (!await FirestoreRulesEmulator.isSupported()) {
    test('firebase emulator not supported', () {
      stderr.writeln('firebase emulator not supported');
    });
    return;
  }
  group('emulator', () {
    runPlayelioFirestoreRulesTests(
      () => FirestoreRulesEmulatorTestContext.create(
        rules: playelioFirestoreRules(),
      ),
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}
```

### The simulator outside a test

```dart
import 'package:festenao_firebase/firestore_rules_sim.dart';

var simulator = FirestoreRulesSimulator(rules: rules, auth: memoryAuth);
// Checked as auth.currentUser; memoryFirestore itself bypasses the rules.
var firestore = simulator.enforce(memoryFirestore);
simulator.setCustomUserClaims(uid, {'role': 'admin'}); // request.auth.token.role
```

### The emulator harness

```dart
import 'package:festenao_firebase/firestore_rules_emulator.dart';

var emulator = await FirestoreRulesEmulator.start(rules: rules);
var user = await emulator.newUserContext(); // rules enforced rest client
var owner = await emulator.newOwnerContext(); // `Bearer owner`, bypasses rules
await emulator.loadRules(otherRulesText); // hot swap
await emulator.stop();
```

## Common mistakes

* Seeding through the rules enforced firestore: the test then fails on the
  setup instead of the rule it is about. Seed with `adminFirestore`.
* Asserting only what works. A rule set that grants everything passes those
  tests; `expectPermissionDenied` is what pins a rule down.
* Leaving state between tests: the suites delete their documents in `setUp`,
  and the emulator keeps them otherwise (a second run then passes for the
  wrong reason).
* Trusting a simulator run alone for `collectionGroup` or `getAfter`: they
  are not supported, only the emulator answers.
* Forgetting to sign in again after `setCustomUserClaims`: the token in hand
  still has the old claims.
