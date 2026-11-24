# Create limits and user plans

How many entities (projects, playlists...) a user creates through the api,
and how an app admin changes that limit or blocks a user. Server side, opt
in, generic on the entity type.

**Status (2026-11-03, the site plan 2026-11-24).** Written in
festenao_common, tested on the memory server
(`test/festenao_user_plan_test.dart`, thirteen tests). Not yet used by a
deployed app at the time of writing; a private app on festenao was the
first one wired.

## Pieces

- **The create limit of an entity handler**:
  `FestenaoEntityHandlerOptions.createLimit`, a function returning the
  default limit (null: no default). When the option is set:
  - the create command (`entity/<type>/create`) counts the entities the user
    created through the api and not deleted, refuses with
    `resource-exhausted` at the limit, and creates the entity alive (a
    `deleted` sent by the client is dropped);
  - the creator is recorded server side,
    `app/<app>/creator/<type>/entity_id/<entityId>` (`userId`, `created`);
  - `entity/<type>/get-create-limit` is served
    (`FestenaoApiFsEntityClient.getCreateLimit`): the limit, the user's own
    limit, the count, whether they may create one more; the signed in
    user's, or anyone's for an app admin.

  The limit of a user is the one an app admin set them (their plan), the
  default otherwise; an app admin has none. Entities created directly by the
  client, or before the option, are not counted; a deleted or purged entity
  frees its place.
- **The user plans**: `app/<app>/user_plan/<userId>`, server side
  (`FsFestenaoUserPlan`): `createLimits` by entity type, `blocked`,
  `blockedReason`, `updatedBy`, `updated`. `FestenaoUserPlanHandler` serves
  `user-plan/get` (own, or anyone's for an app admin) and `user-plan/set`
  (app admins; only the fields set change, a null `createLimits` entry goes
  back to the default). Client: `FestenaoUserPlanApiClient`.
- **The site plan** (2026-11-24): the same record holds what a user's
  public sites get, free or paid:
  - `slugLimit` (the projects with a public address, a slug), `granted` (a
    paid plan given by an app admin, no end), `ads` (null: ads on the free
    plan only), set by `user-plan/set`;
  - `paidUntil` and `subscriptionId`, set by the server for a payment
    (`FestenaoUserPlanHandler.recordPayment`, the payment webhook) or by an
    app admin (`paidUntil` only).

  `festenaoSitePlanOf` (`FsFestenaoUserPlan.sitePlan`) gives the plan in
  effect: paid when granted or before `paidUntil` plus a grace period,
  the slug limit set or the policy's of the plan, none for an app admin.
  `FestenaoSitePlanPolicy` holds the defaults (proposals until decided: 1
  free address with ads, 10 paid ones without, 14 days of grace), given to
  the handler (`sitePlanPolicy`). `user-plan/get` answers the plan in
  effect too (`paid`, `inGrace`, `effectiveSlugLimit`, `effectiveAds`,
  `slugProjectCount`, `canClaimSlug`).
- **The counted public addresses**: `user-plan/claim-project-slug`
  (`FestenaoUserPlanApiClient.claimProjectSlug`, the admin of the project
  only) gives a project a slug in one transaction with its count:
  - the project is held by the user who claimed it first,
    `app/<app>/slug_project/<projectId>` (`userId`), and listed in their
    usage, `app/<app>/user_usage/<userId>` (`slugProjects`), both
    server-only;
  - a project counts once whatever its slugs and whichever of its admins
    changes it (its old slug an alias, as `setProjectSlug`);
  - refused: `invalid-argument` (an invalid slug, checked first),
    `resource-exhausted` (past the limit), `already-exists` (taken).

  `user-plan/release-project-slug` takes the slugs of a project back and
  frees its place. A server handler (the publish command of a festival)
  calls `claimProjectSlug`/`releaseProjectSlug` of the handler directly,
  after its own access check. The handler needs the server's `database`
  for these (`unimplemented` without it). On the free plan again, the
  addresses already held stay; none more until under the limit.
- **Blocked users**: `FestenaoUserPlanHandler.requireNotBlocked` refuses
  every command of a blocked user with `permission-denied` (`User blocked`),
  for the apps the handler serves; an app admin is never blocked. One read
  per command of a signed in user.
- **Several apps on one server**: `FestenaoEntityHandler.appId` restricts a
  handler to the requests naming its app (its entities and its app admins);
  `FestenaoProjectsServerApp.addAppProjectHandler(app, options:)` adds one
  for the projects of another app, tried before the server's own project
  handler (which serves any request). The server's own app may be given, its
  handler then replacing the default one.

## Using it

A festenao projects server app, at start:

```dart
serverApp
  ..addAppProjectHandler(
    app,
    options: FestenaoEntityHandlerOptions(createLimit: () => 3),
  )
  ..userPlanHandler = FestenaoUserPlanHandler(
    apps: [app],
    firestore: serverApp.fsDatabase.firestore,
  );
```

`userPlanHandler` once set is served and checked first by `onCommand`.

A server built on `TkCmsServerAppV2` with its own entity handlers (a
playlist handler, say): give its `FestenaoEntityHandler` an `appId` and a
`createLimit`, add a `FestenaoUserPlanHandler` to its handlers and call its
`requireNotBlocked(apiRequest)` first in `onCommand`.

The app creates through the api (`FestenaoApiFsEntityClient.createEntity`,
or `dashboardCreateProject(creator:)` of festenao_dashboard_base_app) and
shows the limit on `resource-exhausted`.

## Limits

- Enforced by the server only: a client allowed by the security rules to
  write an entity directly still can, and a user toggling the `deleted`
  flag of their entities directly frees places. Closing that is a rule
  change of the app.
- Two creations at once may both pass the count (no transaction around the
  count and the creation). The slug claims have one: two at once take one
  place.
- The slug limit counts the claims through the server only: a client the
  rules let write the slug registry (the `slug` role) is not counted, and a
  server serving public sites trusts a counted project only (its holder
  document), never the registry alone.
- A project deleted with a slug keeps it, and its place, until released:
  nothing releases the slugs of a deleted project yet.
- A blocked user keeps the direct Firestore access the rules give them; the
  server commands only are refused. Disabling the auth account would block
  them in every app of the Firebase project.
