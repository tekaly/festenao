# festenao_firebase

Firestore security rules as code: an imperative rules builder, an in-memory
simulator that replicates the emulator, an emulator harness, and the
tkcms/festenao rule sets with the presets that generate the rules files of the
festenao firebase contexts.

## Libraries

| Library | Content |
|---|---|
| `firestore_rules.dart` | `FirestoreRules`, `RulesMatch`, `RulesFunction`, the `RulesExpr` tree and the text writer |
| `firestore_rules_sim.dart` | `RulesEvaluator`, `FirestoreRulesSimulator`, `RulesEnforcedFirestore` (a `Firestore` wrapper checking every operation) |
| `firestore_rules_emulator.dart` | `FirestoreRulesEmulator`: auth + firestore emulators on a generated folder, hot rules loading, owner and user rest contexts, custom claims |
| `festenao_firestore_rules.dart` | `TkCmsFirestoreRules` (entity rules at any depth) and the `festenao*Rules()` presets |
| `firestore_rules_test_runner.dart` | `FirestoreRulesTestContext` (sim and emulator) and `runFestenaoFirestoreRulesTests`, the same suite on both |

## Writing rules

```dart
import 'package:festenao_firebase/firestore_rules.dart';

var rules = FirestoreRules()..denyAll();
var signedIn = rules.function(
  'signedIn', [], (f) => requestAuth.isNotNull & requestAuthUid.isNotNull);
var isMember = rules.function('isMember', ['roomId'], (f) {
  var doc = f.let('doc',
      rulesGet(docPath(['room', f.param('roomId'), 'member', requestAuthUid])));
  return doc.isNotNull & doc.data.get('active', false).eq(true);
});
rules.match('/room/{roomId}', (m) {
  m.allow([RulesMethod.read], signedIn.call([]) & isMember.call([m.v('roomId')]));
  m.allow([RulesMethod.create],
      requestResourceData.get('owner', '').eq(requestAuthUid));
  m.match('/message/{messageId}', (mm) {
    mm.allow([RulesMethod.read, RulesMethod.write],
        signedIn.call([]) & isMember.call([mm.v('roomId')]));
  });
});
print(rules.toRulesText());
```

Everything is appended in call order, which is also the order of the file.
`m.v('name')` returns a wildcard bound by the block or one of its ancestors and
throws otherwise. Expressions: `&`, `|`, `~`, `eq`, `neq`, `lt`..., `isIn`,
`member`, `get(key, default)`, `call(method, args)`, `ternary`, literals
through `lit()` (or plain Dart values in most places), `docPath([...])` for
`/databases/$(database)/documents/...` paths, `rulesGet`/`rulesExists`.

## tkcms entity rules at any depth

```dart
import 'package:festenao_firebase/festenao_firestore_rules.dart';

var tkCms = TkCmsFirestoreRules(denyAll: true);
tkCms.level(1) // /{top}/{topId}/{entity}/{entityId}
  ..addEntityRules()          // entity doc (read: read, write: admin), data/** (read/write)
  ..addInviteReadRules()
  ..addAccessManageRules()    // admins manage access rows
  ..addAccessUserReadRules()  // a user reads its own rows
  ..addCreatorRules()         // no backend: creatorUserId flow
  ..addPublicAccessRules(scope: TkCmsPublicReadScope.dataOnly)
  ..addUserPrvRules();
tkCms.level(2); // /{top}/{topId}/{sub}/{subId}/{entity}/{entityId}, sub2* functions
print(tkCms.toRulesText());
```

Level 0 is `/{entity}/{entityId}` (`hasEntityAccess`), level 1 adds
`{top}/{topId}` (`subHasEntityAccess`), level 2 `{sub}/{subId}`
(`sub2HasEntityAccess`), and so on: one definition, any nesting depth.

Presets (`festenaoRulesPresets`): `api_context`, `no_api_context`,
`full_api_context`, `dartff` (the legacy root file), `server_full_api`
(calendelio style: api owned access, app level `user_access`).

`dart run tool/generate_firestore_rules.dart` rewrites the rules files of
`festenao_dartff` and its contexts (`--check` only reports), 
`dart run tool/print_rules.dart <preset>` prints one.

## Simulating the rules

```dart
import 'package:festenao_firebase/firestore_rules_sim.dart';

var simulator = FirestoreRulesSimulator(rules: rules, auth: memoryAuth);
var firestore = simulator.enforce(memoryFirestore); // checked as auth.currentUser
// memoryFirestore itself bypasses the rules (seeding), like the emulator owner.
simulator.setCustomUserClaims(uid, {'role': 'admin'}); // request.auth.token.role
```

The evaluator replicates the engine: nested matches, single and recursive
wildcards (unbound on `list`, using one is an evaluation error), any matching
`allow` grants, evaluation errors deny, `&&`/`||` short circuit, `get()` of a
missing document is `null`, member access on a missing key is an error,
`get()`/`exists()` are cached per request and limited to 10 documents (20 in
batches and transactions). Writes see `resource` (before) and
`request.resource` (after, merges and field values resolved); batches and
transactions are checked against the state before them. Not supported:
`collectionGroup`, `getAfter`.

## Emulator

```dart
import 'package:festenao_firebase/firestore_rules_emulator.dart';

var emulator = await FirestoreRulesEmulator.start(rules: rules); // demo project
var user = await emulator.newUserContext();   // rules enforced rest client
var owner = await emulator.newOwnerContext(); // `Bearer owner`: bypasses rules
await emulator.loadRules(otherRulesText);      // hot swap
await emulator.setCustomUserClaims(uid, {'role': 'admin'}); // sign in again after
await emulator.stop();
```

No custom claims were needed to bypass the rules: the emulator accepts the
`owner` token (`FirestoreRest.useFirestoreEmulator(owner: true)`), and the
simulator hands out the unwrapped firestore. Custom claims are supported for
what they are for, `request.auth.token.<claim>` conditions.

## Tests

- `test/rules_writer_test.dart`, `test/rules_sim_test.dart`: unit tests.
- `test/festenao_rules_sim_test.dart` and `test/festenao_rules_emulator_test.dart`:
  the same suite (`runFestenaoFirestoreRulesTests`) on both backends.
- `test/legacy_rules_emulator_test.dart`: the suite on the hand written files
  the presets replaced (`test/data/legacy_rules`).
- `test/festenao_common_runners_sim_test.dart`: the festenao_common access
  runners on the simulator.

`dart run tool/start_rules_emulator.dart [preset]` keeps an emulator running,
the emulator tests then reuse it.
