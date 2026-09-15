/// The shared test suite of the `entity/<type>/set-public` command
/// ([FestenaoApiFsEntityClient.setEntityPublic]), for any entity type and
/// any deployment: the memory server, the emulator, a deployed project.
///
/// An app describes what the suite needs in an
/// [EntitySetPublicApiTestContext] (its two test users, the way to create
/// and clean up an entity, its api client and, when it has one, its app
/// level privilege) and calls [entitySetPublicApiTestRunner] in a group of
/// its server test suite.
library;

import 'package:dev_test/test.dart';
import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';

/// What [entitySetPublicApiTestRunner] needs from an app.
class EntitySetPublicApiTestContext<T extends TkCmsFsEntity> {
  /// The entity api client, its access rooted where the server writes (the
  /// flag is read back through it).
  final FestenaoApiFsEntityClient<T> client;

  /// Signs the first test user in, the creator, hence an admin, of the
  /// entity; returns its id.
  final Future<String> Function() signInAdmin;

  /// Signs the second test user in, with no access on the entity; returns
  /// its id. Null when the deployment has no second test user: the stranger
  /// test is then skipped.
  final Future<String> Function()? signInStranger;

  /// Creates an entity as the signed in user (the admin) and returns its id.
  final Future<String> Function() createEntity;

  /// Deletes and purges [entityId], the admin being signed in.
  final Future<void> Function(String entityId) purgeEntity;

  /// True when the app refuses an admin without an app level privilege
  /// (`FestenaoEntityHandlerOptions.setPublicCheck`).
  final bool privilegeRequired;

  /// Grants ([granted] true) or revokes the app level privilege of [userId].
  ///
  /// Null when the app has none, or when a test cannot write it (a
  /// deployment with rules, where the privilege is server written): the
  /// suite then only checks that the command is served and refuses.
  final Future<void> Function(String userId, {required bool granted})?
  setPublishPrivilege;

  /// True when the admin can read the flag back from firestore
  /// (`isEntityPublic`), the default.
  final bool flagReadable;

  /// What [entitySetPublicApiTestRunner] needs from an app.
  const EntitySetPublicApiTestContext({
    required this.client,
    required this.signInAdmin,
    this.signInStranger,
    required this.createEntity,
    required this.purgeEntity,
    required this.privilegeRequired,
    this.setPublishPrivilege,
    this.flagReadable = true,
  });
}

/// The set public suite, on the context [contextBuilder] gives (built once
/// per test, an entity is created and purged around each).
void entitySetPublicApiTestRunner<T extends TkCmsFsEntity>(
  Future<EntitySetPublicApiTestContext<T>> Function() contextBuilder,
) {
  late EntitySetPublicApiTestContext<T> ctx;
  late String adminUserId;
  late String entityId;

  setUp(() async {
    ctx = await contextBuilder();
    adminUserId = await ctx.signInAdmin();
    entityId = await ctx.createEntity();
  });

  tearDown(() async {
    await ctx.signInAdmin();
    await ctx.setPublishPrivilege?.call(adminUserId, granted: false);
    await ctx.purgeEntity(entityId);
  });

  Future<bool> setPublic(bool public) =>
      ctx.client.setEntityPublic(entityId: entityId, public: public);

  Future<bool> isPublic() => ctx.client.entityAccess.isEntityPublic(entityId);

  Future<void> expectRefused() async {
    try {
      await setPublic(true);
      fail('should fail');
    } on ApiException catch (e) {
      expect(e.error?.code.v, 'permission-denied', reason: '$e');
    }
  }

  test('an admin publishes and unpublishes', () async {
    var grant = ctx.setPublishPrivilege;
    if (ctx.privilegeRequired) {
      if (grant == null) {
        // The privilege cannot be granted from here: the command is served
        // (an unknown one is an internal error) and gated, nothing more.
        await expectRefused();
        return;
      }
      await grant(adminUserId, granted: true);
    }
    expect(await setPublic(true), isTrue);
    if (ctx.flagReadable) {
      expect(await isPublic(), isTrue);
    }
    expect(await setPublic(false), isFalse);
    if (ctx.flagReadable) {
      expect(await isPublic(), isFalse);
    }
  });

  test('a stranger is refused, privileged or not', () async {
    var grant = ctx.setPublishPrivilege;
    var signInStranger = ctx.signInStranger;
    if (signInStranger == null) {
      // No second test user here.
      return;
    }
    var strangerUserId = await signInStranger();
    await expectRefused();
    if (ctx.privilegeRequired && grant != null) {
      // The app level privilege does not open somebody else's entity.
      await grant(strangerUserId, granted: true);
      try {
        await expectRefused();
      } finally {
        await grant(strangerUserId, granted: false);
      }
    }
    if (ctx.flagReadable) {
      await ctx.signInAdmin();
      expect(await isPublic(), isFalse);
    }
  });

  test('an admin without the privilege is refused', () async {
    var grant = ctx.setPublishPrivilege;
    if (!ctx.privilegeRequired || grant == null) {
      // No privilege in this app, or nothing to revoke: the first test
      // covers it.
      return;
    }
    await grant(adminUserId, granted: false);
    await expectRefused();
    if (ctx.flagReadable) {
      expect(await isPublic(), isFalse);
    }
  });
}
