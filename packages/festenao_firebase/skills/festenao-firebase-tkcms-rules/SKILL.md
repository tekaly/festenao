---
name: festenao-firebase-tkcms-rules
description: >-
  Use when generating the firestore.rules of a tkcms/festenao app with
  festenao_firebase: TkCmsFirestoreRules and its levels (entity, invite,
  access manage, access self, creator, public access, user_prv, user_access,
  public get rule sets at any nesting depth) and the festenao*Rules() presets
  (api_context, no_api_context, full_api_context, server_full_api, dartff)
  with FestenaoRulesOptions, plus the app side pair of tools that generates
  firestore.rules and deploys it.
---

# festenao_firebase tkcms rules

A tkcms entity lives at `<parent>/{entity}/{entityId}` with its access rows
under `<parent>/access/{entity}/entity_id/{entityId}/user_access/{userId}`,
its mirror index under `access/{entity}/user_id/{userId}/entity_access/...`,
its invites, its public read flag and its per user private area. Those paths
are always the same shape, so the rules that guard them are written once:
`TkCmsFirestoreRules` emits the rule sets for a level (nesting depth) and the
`festenao*Rules()` presets assemble the levels into the rules file of a
deployment context. An app declares which preset it is and generates its
file; it does not write match blocks.

## Guidelines

* Import `package:festenao_firebase/festenao_firestore_rules.dart` (the rule
  sets, the presets and the builder it re-exports). Never import `src/`.
* `TkCmsFirestoreRules({rules, denyAll})` declares `signedIn()` (and the
  explicit deny all block when asked). `level(depth)` is where the rule sets
  live: depth 0 is `/{entity}/{entityId}` with `hasEntityAccess(...)`
  functions, depth 1 `/{top}/{topId}/{entity}/{entityId}` with the `sub`
  prefixed ones, depth 2 `sub2`, and so on — one definition, any depth. An
  app under `app/<appId>` is depth 1.
* The rule sets of a level, each printing its own commented section:
  * `addEntityRules()` — the entity document (read with read access, write
    with `rootWriteAccess`, `admin` by default) and `data/{dataId}/**` (read
    with read access, write with write access). `dataScope:
    TkCmsEntityDataScope.all` collapses it into one rule over the whole
    `{entity}/{entityId}/**` subtree (the legacy festenao shape), where
    `allReadAccess` says what reading takes.
  * `addInviteReadRules()` — any signed in user reads an invite it knows the
    id of.
  * `addAccessManageRules()` — entity admins read and write the access rows,
    both sides.
  * `addAccessUserReadRules({legacy})` — a user reads its own rows;
    `legacy: true` writes the three separate older rules instead of the one
    covering `access/{entity}/user_id/{userId}/**`.
  * `addAccessSelfRules()` — a user `get`s and deletes (leaves) its own row
    on the entity side. `get`, not `read`: the `userId` wildcard is unbound
    on a list.
  * `addStandaloneInviteRules()` — the no backend invite flow: the holder of
    an admin `invite_access/{inviteCode}` creates invites and an access row
    naming an admin invite id can be created by anyone (the invite id is the
    capability).
  * `addCreatorRules()` — the no backend creation flow, where the client
    writes the entity and its own access row with `creatorUserId`.
  * `addPublicAccessRules({scope, adminWrite})` — the public read flag at
    `access/{entity}/entity_id/{entityId}/public_access/public`: `{read:
    true}` opens the entity (`TkCmsPublicReadScope.all`) or only its data
    (`dataOnly`) to anyone, signed out included. The flag itself is readable
    by anyone — that read is what `isEntityPublic()` does after a
    `set-public` command — and writable by entity admins unless
    `adminWrite: false` reserves it for the api.
  * `addUserPrvRules()` / `addEntityUserPrvRules()` — the per user private
    area, `<parent>/user_prv/{userId}/**` and the legacy per entity one.
  * `addUserAccessRules()` — app level rights at `<parent>/user_access/
    {userId}`, readable by their owner, never client writable.
  * `addPublicGetRules()` — world readable documents under
    `<parent>/public/get/**` (`get` only, no `list`).
* The presets, in `festenaoRulesPresets` by name, all taking
  `FestenaoRulesOptions(userAccess:, accessSelf:, publicAccess:, maxDepth:,
  header:)`:
  * `festenaoApiContextRules()` (`api_context`) — a cloud function owns every
    access mutation; clients read their entities, write their data and their
    private area. The preset of an app whose entities are created through its
    api (a playelio playlist, a notelio booklet).
  * `festenaoNoApiContextRules()` (`no_api_context`) — no backend: the client
    creates its entities and access rows itself (`creatorUserId`), standalone
    invites, public read of the data.
  * `festenaoFullApiContextRules()` (`full_api_context`) — top level *and*
    sub entities, standalone invites by code at both levels.
  * `festenaoServerFullApiRules()` (`server_full_api`) — the same two levels
    with the api owning every mutation, no client side invites nor flag
    writes, app level `user_access` (calendelio style).
  * `festenaoDartffRules()` (`dartff`) — the legacy festenao root file: both
    levels with whole subtree entity rules, standalone invites, per user
    private data and the public read flags.
* Pick the preset by *who writes the access rows*, not by the app: a
  deployment whose api creates entities never wants the creator or the
  standalone invite rules, which let a client grant itself access.
* An app keeps its rules in one `lib/<app>_firestore_rules.dart` returning
  the preset with its own `header`, next to the `firebase.json` that deploys
  the generated file, plus `tool/generate_firestore_rules.dart` and
  `tool/publish_firestore_rules.dart`. The header says the file is generated.
* Check the result before deploying: run the rules suite on the simulator and
  the emulator (`festenao-firebase-rules-testing`). The presets are covered
  by `runFestenaoFirestoreRulesTests`, an app's own additions are not.

## Examples

### The rules of an api backed app

```dart
// lib/playelio_firestore_rules.dart
library;

import 'package:festenao_firebase/festenao_firestore_rules.dart';

export 'package:festenao_firebase/festenao_firestore_rules.dart';

/// The playelio rules.
FirestoreRules playelioFirestoreRules() => festenaoApiContextRules(
  options: const FestenaoRulesOptions(
    // `app/<app>/user_access/<userId>`: the app level rights (publishing).
    userAccess: true,
    // A member gets (and deletes, to leave) its own access row.
    accessSelf: true,
    // A published playlist is readable by anyone, the flag is api written.
    publicAccess: true,
    header:
        'playelio: playlists are created through the api function.\n'
        'Generated by tool/generate_firestore_rules.dart, do not edit.',
  ),
);

/// The rules file, next to the firebase.json that deploys it.
const playelioFirestoreRulesPath = 'firestore.rules';
```

### The deploy tool

```dart
// tool/publish_firestore_rules.dart
import 'package:playelio_common/constants.dart';
import 'package:tekartik_firebase_build/firebase_project.dart';

import 'generate_firestore_rules.dart';

/// Regenerates `firestore.rules` and deploys it
/// (`firebase deploy --only firestore:rules`).
///
/// Run from the package root, with the firebase cli logged in:
/// `dart run tool/publish_firestore_rules.dart`
Future<void> main(List<String> args) async {
  await generateFirestoreRules();
  await FirebaseProjectBuilder(
    options: FirebaseProjectOptions(projectId: fbPlayelioProjectId),
  ).deployFirestoreRules();
}
```

### Assembling levels by hand

```dart
import 'package:festenao_firebase/festenao_firestore_rules.dart';

/// Two nested entity levels: `app/<appId>/project/<projectId>` and
/// `app/<appId>/project/<projectId>/room/<roomId>`.
FirestoreRules appRules() {
  var rules = FirestoreRules();
  rules.headerComment('Generated, do not edit.');
  var tkCms = TkCmsFirestoreRules(rules: rules, denyAll: true);
  for (var depth = 1; depth <= 2; depth++) {
    tkCms.level(depth)
      ..addEntityRules()
      ..addInviteReadRules()
      ..addAccessManageRules()
      ..addAccessUserReadRules()
      ..addAccessSelfRules()
      ..addPublicAccessRules(adminWrite: false)
      ..addUserPrvRules();
  }
  tkCms.level(1).addUserAccessRules();
  return rules;
}
```

## Common mistakes

* Reading the public flag with the entity rules: the flag document is not
  under the entity, it is an `access/...` document, and only
  `addPublicAccessRules()` makes it world readable. A deployment missing it
  answers `permission-denied` to `isEntityPublic()` while `set-public`
  itself, which the api performs, succeeds.
* Mixing `addCreatorRules()` or `addStandaloneInviteRules()` into an api
  backed deployment: a client can then grant itself access to an entity.
* Generating at the wrong depth: an app under `app/<appId>` is depth 1, and
  the depth 0 rule sets would guard `/{entity}/{entityId}` instead.
* Editing the generated file to patch one rule. Add the rule set (or the
  missing preset option) and regenerate, otherwise the next run drops it.
* Deploying without running the suite: `firebase deploy --only
  firestore:rules` accepts anything that compiles, including rules that deny
  what the app needs.
