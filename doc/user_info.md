# Reading a user's account information (`get-user-info`)

An admin editing an access fills the name and the email of the user from its
account instead of typing them.

- Command: `festenaoEntityGetUserInfoCommand(entityType)`
  (`<entity>/get-user-info`), client
  `FestenaoApiFsEntityClient.getEntityUserInfo(entityId:, userId:)`.
- Result (`FsCmsEntityGetUserInfoApiResult`): `userId`, `name` (the display
  name), `email`, `emailVerified`, `disabled`, `hasAccess` (an access row on
  the entity exists).
- Rights, checked by the server handler
  (`FestenaoEntityHandler.onGetUserInfoCommand`):
  - an app admin (`access/app/entity_id/<app>/user_access/<uid>` admin) reads
    any user;
  - an admin of the entity reads only the users that have an access to it,
    so that an entity admin cannot look up the email of an arbitrary account
    (an unknown or foreign user gives the same `permission-denied`);
  - a reader, a writer, a stranger or a signed out caller: refused.
  - `not-found` for an unknown user (app admin only), `invalid-argument` for
    a missing or empty `entityId` or `userId`.
- Admin app: `AdminProjectUserEditScreen` shows *Fill from the account* under
  the user id when the secured api is there (`globalFestenaoApiServiceOrNull`),
  and fills an existing access missing its name or email when it opens
  (keeping what is typed, quietly).
- Tests: `festenao_common/lib/test/festenao_user_info_test_runner.dart` (on
  the in memory server: `test/festenao_user_info_test.dart`), the form in
  `festenao_admin_base_app/test/user_edit_fill_from_account_test.dart`.
