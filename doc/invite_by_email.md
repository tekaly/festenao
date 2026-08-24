# Invite by email

Design note for adding *invite by email* next to the existing *invite by link*
(`TkCmsFsInviteEntity`). Nothing here is implemented yet.

## 1. Requirements

- An entity admin (or a global app admin) invites someone **by email address**,
  with an access level (read / write / admin), exactly like the link invite.
- Server commands, alongside the existing `entity/<type>/create-invite`,
  `accept-invite`, `delete-invite`, to **create**, **list** and **check**
  pending email invites — checkable *from both sides*:
  - the inviter: "which invites did I send on this entity, and what happened to
    them";
  - the invitee: "do I have pending invites", called **after login and on app
    start**.
- The invitee can **accept** or **discard** the invite, like a link invite.
- Only an **entity admin** or a **global app admin** can create / list / revoke
  email invites.
- The invite data is **admin-only**: no client touches it directly. The user's
  whole surface is three api commands — query, accept, discard (§7).
- Old email invites are **swept by the existing cron**, like link invites
  (§10).

## 2. What exists today (link invite)

Firestore layout (rooted at `app/<appId>`, see `FestenaoFirestoreDatabase`):

```
invite/<entityType>/invite_id/<inviteId>                            TkCmsFsInviteId
invite/<entityType>/invite_id/<inviteId>/invite_entity/<entityId>   TkCmsFsInviteEntity
access/<entityType>/entity_id/<entityId>/user_access/<userId>       TkCmsFsUserAccess
access/<entityType>/user_id/<userId>/entity_access/<entityId>       TkCmsFsUserAccess
```

| Layer | File |
|---|---|
| Models + collection ids | `tkcms/packages/tkcms_common/lib/src/firestore/model/fs_user_access_v2.dart` |
| Firestore operations | `tkcms/packages/tkcms_common/lib/src/firestore/tkcms_firestore_database_entity_user_access.dart` (`createInviteEntity`, `acceptInviteEntity`, `deleteInviteEntity`, `deleteOldInvites`) |
| Command names + api models | `packages/festenao_common/lib/api/festenao_api_fs_entity.dart` |
| Client | `packages/festenao_common/lib/api/festenao_api_fs_entity_client.dart` |
| Server handler | `packages/festenao_common/lib/server/festeano_server_entity_handler.dart` |
| Cron cleanup | `FestenaoServerApp.onCronCommand` → `projectDb.deleteOldInvites()` |
| Rules | `packages/festenao_noff/firestore.rules` (+ `festenao_dartff/` and the per-context copies) |
| UI | `packages_flutter/festenao_dashboard_base_app/lib/src/screen/project_sdb_share_screen{,_bloc}.dart`, `project_sdb_invite_view_screen{,_bloc}.dart` |

The link invite is *bearer-token* shaped: whoever holds `inviteId` can accept
it. Access checks happen at **creation** time (the creator cannot grant more
than they have — `createInviteEntity`), not at acceptance time. Invites expire
after `tkCmsInviteEntityExpirationDefault` (7 days) via the cron.

## 3. Key decisions

### 3.1 The email invite is *addressed*, not bearer — and API-only

The whole point is that only the named recipient can accept it. That means the
grant decision moves to **acceptance** time and needs a trusted email for the
accepting user. `TkCmsFirebaseContext.authOrNull` exposes `FirebaseAuth`, whose
`getUser(uid)` returns a `UserRecord` with `email` and `emailVerified`;
`auth_node`, `firebase_admin_sdk` and `auth_sembast` all implement it, so prod,
dartff and the local test server all work.

Decision: **the email invite documents are admin-only. No client, on either
side, ever reads or writes them directly.** Everything goes through the secured
api:

- the inviter (entity admin / global app admin) creates, lists and revokes via
  commands;
- the invitee queries, accepts and discards via commands.

Firestore rules therefore grant *nothing* on this data (§9). Rules could in
principle do the invitee side themselves — `request.auth.token.email` and
`request.auth.token.email_verified` exist — but that path is explicitly not
taken: the server is the only party that should decide that a uid owns a
verified address, and keeping one enforcement point avoids the rules and the
handler drifting apart. The standalone / no-api fallback that
`ProjectSdbInviteViewScreenBloc` has for link invites simply does not offer
email invites (`globalFestenaoApiServiceOrNull == null` → hide the feature).

### 3.2 `emailVerified` is mandatory

Firebase email/password signup does **not** verify the address. Accepting an
invite on the strength of an unverified email would let anyone claim someone
else's invite by registering their address. So: acceptance requires
`userRecord.emailVerified == true`. Federated providers (google.com) come back
verified. Surface a clear "verify your email address to accept this invite"
state in the UI rather than a generic error.

### 3.3 Do not resolve the email to a uid at creation time

Storing only the email (never a uid) means:
- inviting someone who has no account yet works — they see the invite the first
  time they start the app after signing up (this is the main win over link
  invites);
- the inviter learns nothing about whether that address has an account
  (no `getUserByEmail` probe → no account-enumeration oracle).

### 3.4 Email normalisation

`email.trim().toLowerCase()` is the stored/normalised form and the value the
invitee lookup queries on (§4 — it is a field, never a document id).
Gmail dot/plus aliasing is deliberately *not* normalised — matching Firebase
Auth's own behaviour. Document that.

## 4. Firestore layout

**The email never appears in a document path.** One collection, auto-generated
ids exactly like the link invite (`AutoIdGenerator.autoId()`):

```
invite/<entityType>/email_invite_id/<inviteId>     TkCmsFsEmailInvite
```

The email is a **field**, and every lookup is a single-field query the server
runs with admin credentials:

| Question | Query |
|---|---|
| invites this entity sent (inviter) | `where('entityId', isEqualTo: entityId)` |
| invites addressed to me (invitee) | `where('email', isEqualTo: normalisedEmail)` |
| expired invites (cron) | `where('timestamp', isLessThan: t).orderBy('timestamp').orderById()` |

All three are single-field — automatically indexed, no composite index to
declare, and the same query shape `deleteOldInvites()` already uses. Keep them
single-field: filter on `status` **in memory** rather than adding it to the
`where`, since the per-entity and per-email result sets are tiny.

Rationale for dropping the email-keyed index document that a first draft of this
note proposed:

- an email as a document id is a path segment, and path handling differs
  between the firestore backends (notably rest) — not worth the risk;
- `hashing.sha256(email)` only buys obfuscation: the address space of real email
  addresses is small enough to brute-force offline, so a leaked hash is a leaked
  address. Real secrecy needs an HMAC with a server-side secret, and rules
  cannot hold a secret — which defeats the only reason the hash existed;
- it was there purely to make the *optional* standalone/rules path (§3.1)
  possible. §9 shows how to get that without any email in a path.

Two fewer writes per invite, no enumeration surface, one document to clean up.

## 5. Models (tkcms, `fs_user_access_v2.dart`)

```dart
/// invite/<entityType>/email_invite_id/<inviteId>
class TkCmsFsEmailInvite<TFsEntity extends TkCmsFsEntity>
    extends CvFirestoreDocumentBase with WithServerTimestampMixin {
  final entityId = CvField<String>('entityId');
  final entity = CvModelField<TFsEntity>('entity');      // cached name, as the link invite does
  final userAccess = CvModelField<TkCmsCvUserAccess>('userAccess');
  final email = CvField<String>('email');                // normalised, queried
  final inviterUserId = CvField<String>('inviterUserId');
  final status = CvField<String>('status');              // pending | accepted | discarded
  final acceptedUserId = CvField<String>('acceptedUserId');
  final closedTimestamp = CvField<Timestamp>('closedTimestamp');
  @override
  CvFields get fields => [entityId, entity, userAccess, email, inviterUserId,
      status, acceptedUserId, closedTimestamp, ...timedMixinFields];
}

/// Api-side summary (not a firestore doc).
class TkCmsCvEmailInvite extends CvModelBase { /* inviteId, entityId, entityName,
    email, access, status, inviterUserId, timestamp */ }
```

Register both in `initTkCmsFsUserAccessBuilders()`, and
`TkCmsFsEmailInvite<FsProject>.new` in `initFestenaoFsBuilders()` next to the
existing `TkCmsFsInviteEntity<FsProject>.new`.

Constants: `tkCmsFsEmailInviteIdCollectionId = 'email_invite_id'` and the three
status values.

`status` is kept (rather than deleting the document on accept/discard) precisely
so the inviter's "check" command can report *what happened*; the cron sweeps
closed invites a few days later.

## 6. Access layer (tkcms `TkCmsFirestoreDatabaseServiceEntityAccess`)

New methods, mirroring the existing invite ones:

```dart
Future<String> createEmailInviteEntity({
  required String userId,            // inviter
  required String entityId,
  required String email,             // raw, normalised inside
  required TkCmsCvUserAccess userAccess,
  required TFsEntity entity,
  bool skipAccessCheck = false,      // true for a global app admin
});

Future<List<TkCmsFsEmailInvite<TFsEntity>>> listEntityEmailInvites(
    String entityId, {String? status});

Future<List<TkCmsFsEmailInvite<TFsEntity>>> listEmailInvites(String email);

Future<void> acceptEmailInviteEntity({
  required String userId, required String email, required String inviteId});

Future<void> discardEmailInviteEntity({
  required String userId, required String email, required String inviteId});

Future<void> deleteEmailInviteEntity({required String inviteId});

Future<void> deleteOldEmailInvites();   // called from deleteOldInvites()
```

`createEmailInviteEntity` reuses the exact escalation check already in
`createInviteEntity` (read ⊂ write ⊂ admin against the inviter's
`user_access` doc), plus:

- reject if the entity does not exist or is `deleted`;
- upsert semantics: one pending invite per (entityId, email) — re-inviting
  updates the access and refreshes the timestamp instead of piling up. With no
  deterministic id this is a query-then-write inside the transaction, or a
  cheap `listEntityEmailInvites` before it;
- a cap on pending invites per entity (say 100) to bound abuse.

`acceptEmailInviteEntity` runs in one transaction: read the invite, assert
`status == pending` and `invite.email == email`, merge the granted access into
the existing `TkCmsFsUserAccess` (the same `admin/write/read` OR-merge as
`acceptInviteEntity`), write both access documents via `txnSetEntityUserAccess`,
and set `status = accepted` + `acceptedUserId`.

`discardEmailInviteEntity` sets `status = discarded`.

## 7. Server commands (festenao)

In `festenao_api_fs_entity.dart`, following the existing naming
(`entity/<entityType>/<command>`):

| Command | Caller | Query | Result |
|---|---|---|---|
| `create-email-invite` | entity admin / app admin | `entityId`, `email`, access fields | `inviteId` |
| `list-email-invites` | entity admin / app admin | `entityId`, optional `status` | `invites: List<TkCmsCvEmailInvite>` |
| `delete-email-invite` | entity admin / app admin | `entityId`, `inviteId` | `inviteId` |
| `check-email-invites` | **any signed-in user** | *(optional `entityId`)* | `email`, `emailVerified`, `invites` |
| `accept-email-invite` | **invitee** | `entityId`, `inviteId` | `inviteId` |
| `discard-email-invite` | **invitee** | `entityId`, `inviteId` | `inviteId` |

The last three are the complete user-side surface: **query, accept, discard**.
A user needs no other capability, and has no direct firestore access to this
data at all.

Api models mirror the existing ones — a shared
`FsCmsEntityEmailInviteIdBaseApiCommon<T>` (`entityId` + `inviteId`) for
accept / discard / delete, and `FsCmsEntityCreateEmailInviteApiQuery<T>` with
`TkCmsCvUserAccessMixin` like `FsCmsEntityCreateInviteApiQuery<T>` does.
Register them all in `initFestenaoFsEntityApiBuilders<T>()`.

`check-email-invites` is *the* command a user calls to see their pending
invites — on app start and again right after login. It resolves the caller's
verified email server-side (§3.1), queries
`where('email', isEqualTo: normalisedEmail)`, filters to `status == pending` and
returns a `TkCmsCvEmailInvite` per invite with everything the UI needs to render
a decision: entity name, granted access, who invited, when. It returns
`emailVerified: false` with an empty list rather than an error when the
account's email is unverified, so the UI can prompt for verification. It is
cheap (one indexed collection read) and safe to call unconditionally.

`accept-email-invite` / `discard-email-invite` re-resolve the caller's verified
email and assert it matches `invite.email` — the `inviteId` is *not* a bearer
token here, unlike the link invite.

### Handler (`FestenaoEntityHandler`)

Route the six commands in `onCommandOrNull` (no `compat v2` aliases needed —
these are new). Three helpers, all currently missing:

```dart
String _requireUserId(ApiRequest r);            // the ApiError block is repeated 4x today
Future<UserRecord> _requireUser(String userId); // app.firebaseContext.auth.getUser(uid)
Future<bool> _isAppAdmin(String userId);        // app/<appId>/user_access/<userId>
```

`_isAppAdmin` reads `fsAppUserAccessCollection(appId).doc(userId)` and checks
`FsUserAccess.isAdmin` (which already covers `roleSuperAdmin`). That is the
"global app admin" of the requirement; it bypasses the per-entity escalation
check on create / list / delete. Note `appId` comes from
`appFlavorContext.app`, so admins are per flavor — that is consistent with the
rest of the app.

`userId` now only ever comes from the callable transport
(`onCallableCommand`, from `request.context.auth?.uid`). The http handlers used
to take it from the request body, which any client could forge; they now clear
it (`tkcms` `server_v2.dart`, `server_v1.dart`, `server_admin_sdk.dart`, and
the client no longer sends it). That was a prerequisite for this feature: the
entire email invite design rests on the server knowing *who is calling*, so a
spoofable userId would have made accept-invite trivially bypassable.

## 8. Client

`FestenaoApiFsEntityClient` gets the six matching methods
(`createEntityEmailInvite`, `listEntityEmailInvites`, `checkEmailInvites`,
`acceptEntityEmailInvite`, `discardEntityEmailInvite`,
`deleteEntityEmailInvite`), each a copy of the existing invite method shape.

## 9. Firestore rules

**None.** The email invite collection is admin-only (§3.1), so the correct rules
change is *no rule at all* — the default deny is the intended behaviour, for the
inviter as much as for the invitee.

That is already what happens today, but by accident rather than by statement.
Walking `packages/festenao_noff/firestore.rules` for
`app/<appId>/invite/<entityType>/email_invite_id/<inviteId>`:

- the explicit invite rules are scoped to the `invite_id` collection
  (`.../invite/{entity}/invite_id/{document=**}`), so they do not match
  `email_invite_id`;
- the catch-all `/{top}/{topId}/{entity}/{entityId}/{document=**}` *does* match,
  with `{entity} = invite` and `{entityId} = <entityType>`, but its conditions
  resolve to `subHasEntityWriteAccess(top, topId, 'invite', '<entityType>', uid)`
  and `subEntityCreatorUserIdMatches(...)` — a `get()` on an access document
  that never exists, and a `creatorUserId` that is never set. Both are false or
  error, so the request is denied.

So: add **no** rule, and add a **rules test** asserting a signed-in non-admin,
an entity admin and the invitee are all denied read and write on
`email_invite_id`. Relying on an accident without a test is how it gets opened
later by a well-meaning catch-all.

## 10. Cleanup (cron)

Email invites **must** be swept by the same cron as link invites, otherwise
`email_invite_id` grows without bound — including invites to addresses that
never signed up, which is exactly the case that produces long-lived garbage.

`FestenaoServerApp.onCronCommand` already calls
`db.projectDb.deleteOldInvites()`. Fold the email pass into that method (so
every entity type and every app that already runs the cron picks it up with no
change on their side):

```dart
Future<void> deleteOldInvites() async {
  await _deleteOldLinkInvites();     // the existing body, unchanged
  await deleteOldEmailInvites();     // new
}
```

`deleteOldEmailInvites()` mirrors the existing sweep — same
`where(timestamp, isLessThan:).orderBy(timestamp).orderById().limit(20)`
paginated batch loop, over `email_invite_id`, deleting one document per invite
(there is no second document any more, §4). Two cutoffs:

- **pending** invites older than `tkCmsEmailInviteExpirationDefault` — a new
  constant, suggested **30 days**: the 7-day
  `tkCmsInviteEntityExpirationDefault` is tuned for a link someone pastes into a
  chat, and is too short for an invite whose recipient may not have an account
  yet;
- **closed** invites (`accepted` / `discarded`) older than a few days — the
  inviter has had time to see the outcome in `list-email-invites`. Use
  `closedTimestamp`, not `timestamp`, so a long-pending invite accepted on day
  29 still lingers a few days rather than vanishing immediately.

Two passes, each a single-field query (§4). Cover both in the server tests:
a pending invite past the cutoff disappears, one before it survives, and an
accepted invite disappears on the closed cutoff without waiting for the pending
one.

## 11. UI

Every screen below talks to `FestenaoApiFsEntityClient`, never to firestore —
there is no `onSnapshot` equivalent for this data (§3.1), so the blocs are
request/response with an explicit refresh rather than stream-backed like
`ProjectSdbShareScreenBloc` is for link invites.

- **Inviter** — `project_sdb_share_screen.dart`: an "invite by email" field next
  to the existing access checkboxes, plus a pending-invites list from
  `list-email-invites` (email + access + status, with revoke), refreshed after
  each mutation. `ProjectSdbShareScreenBloc` already holds
  `SdbSharedEntity.isAdmin`, which is the gate for showing it — the server
  re-checks it regardless. The pending list also belongs on
  `project_sdb_users_screen.dart`, under the granted users.
- **Invitee** — a `PendingInvitesBloc` calling `check-email-invites`:
  - on app start, once the identity bloc reports a signed-in user;
  - again on every sign-in transition of `globalTkCmsFbIdentityBloc`.
  Show a banner / dialog listing the invites, each with **Accept** and
  **Discard**, reusing the confirmation dialogs and `projectInvite*` strings
  already in `packages_flutter/festenao_admin_base_app/lib/l10n/`. New strings
  needed: invite-by-email title, "sent to <email>", "verify your email to
  accept", the pending/accepted/discarded labels.
- `project_sdb_invite_view_screen.dart` stays as-is — it is the link-invite
  deep-link screen.

## 12. Tests

- `packages/festenao_common/lib/test/festenao_test_server_test_runner.dart`
  already wires a `FestenaoServerAppTest` with a `projectHandler`; the email
  invite commands are testable there end to end (auth_sembast supports
  `getUser`/`getUserByEmail`, so `emailVerified` can be exercised).
- Cases worth covering: non-admin cannot create; app admin can create without
  entity access; escalation beyond the inviter's own access is refused; wrong
  email cannot accept; unverified email cannot accept; accept merges rather than
  replaces existing access; discard is final; re-invite upserts; expiry sweep.
- Cron (§10): a pending invite past the cutoff is deleted, one before it
  survives, an accepted invite goes on the closed cutoff.
- Rules (§9): a signed-in non-admin, an entity admin and the invitee are all
  denied read and write on `email_invite_id` — the whole design rests on this
  data being admin-only, so it deserves an assertion rather than an accident.
- `packages/festenao_common/lib/test/project_standalone_access_test_runner.dart`
  needs nothing: standalone does not offer email invites.

## 13. Phasing

1. tkcms models + access layer + cron sweep (§10).
2. festenao api models, handler (incl. `_isAppAdmin`), client, server tests.
3. Rules-denial test (§9) + inviter UI.
4. Invitee UI — `check-email-invites` on start/login, accept, discard.

No standalone/rules phase: email invites are api-only by design (§3.1).

## 14. Open questions

- ~~**Http vs callable transport**~~ — resolved: the http transport no longer
  accepts a client-supplied userId (§7).
- **Notification**: nothing here actually *sends* an email. The invite is only
  discovered when the invitee opens the app. Sending a real mail (a
  `mail` collection for the Trigger Email extension, or an SMTP call from the
  function) is a separate, optional piece — but without it "invite by email"
  only reaches people who already use the app.
- **Should an email invite auto-apply on signup** instead of needing an explicit
  accept? Current design says no — explicit accept/discard was the requirement.
