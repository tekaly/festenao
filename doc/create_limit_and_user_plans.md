# Create limits and user plans

How many entities (projects, playlists...) a user creates through the api,
and how an app admin changes that limit or blocks a user. Server side, opt
in, generic on the entity type.

**Status (2026-11-03).** Written in festenao_common, tested on the memory
server (`test/festenao_user_plan_test.dart`, six tests). Not yet used by a
deployed app at the time of writing; a private app on festenao was the first
one wired.

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
  count and the creation).
- A blocked user keeps the direct Firestore access the rules give them; the
  server commands only are refused. Disabling the auth account would block
  them in every app of the Firebase project.
