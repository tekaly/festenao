import 'package:dev_test/test.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

import 'festenao_test_server_test_runner.dart';

bool _isPermissionDenied(Object e) =>
    e is FirestoreException && e.code == FirestoreErrorCode.permissionDenied;

/// The email invites (`invite/<entityType>/email_invite_id`) are admin only
/// data: no rule lets a client read or write them, whoever it is (festenao
/// `doc/invite_by_email.md` §9), the deny by default must hold. The server
/// writes them through the api; the client firestore is refused everything.
///
/// Only meaningful where the rules apply (the emulator): an in memory
/// firestore refuses nothing.
void appEmailInviteRulesTestRunner(
  Future<FestenaoTestServerContext> Function() initAllContext,
) {
  late FestenaoTestServerContext context;

  setUpAll(() async {
    context = await initAllContext();
  });

  test('nobody reads or writes an email invite, not even the entity admin or '
      'the invitee', () async {
    var client = context.projectApiClient;
    var auth = context.clientContext.firebaseAuth!;
    var firestore = context.clientContext.firestore!;
    var projectDb = context.fsDatabase.projectDb;
    var adminEmail = 'emailinviteadmin@festenao-rules-test.local';
    var invitedEmail = 'emailinvitee@festenao-rules-test.local';
    var strangerEmail = 'emailinvitestranger@festenao-rules-test.local';
    var password = 'test1234';

    Future<void> signIn(String email) async {
      await auth.signOut();
      await auth.signInOrUpWithEmailAndPassword(
        email: email,
        password: password,
      );
    }

    // The admin creates the entity and sends an invite, through the api:
    // the server writes with its admin credentials.
    await signIn(adminEmail);
    var entityId = (await client.createEntity(
      entity: FsProject()..name.v = 'email invite rules',
    )).id;
    var inviteId = await client.createEntityEmailInvite(
      entityId: entityId,
      email: invitedEmail,
      fsUserAccess: TkCmsFsUserAccess()..read.v = true,
    );
    var inviteRef = projectDb.fsEmailInviteRef(inviteId).raw(firestore);
    var collectionRef = projectDb.fsEmailInviteCollectionRef.raw(firestore);

    Future<void> expectDenied(
      Future<void> Function() action,
      String what,
    ) async {
      try {
        await action();
      } catch (e) {
        expect(_isPermissionDenied(e), isTrue, reason: '$what: $e');
        return;
      }
      fail('$what should have been denied');
    }

    Future<void> expectAllDenied(String email) async {
      await signIn(email);
      await expectDenied(() => inviteRef.get(), '$email get');
      await expectDenied(
        () => collectionRef.where('email', isEqualTo: email).get(),
        '$email query by email',
      );
      await expectDenied(
        () => collectionRef.where('entityId', isEqualTo: entityId).get(),
        '$email query by entity',
      );
      await expectDenied(
        () => inviteRef.update({'status': 'accepted'}),
        '$email update',
      );
      await expectDenied(
        () => inviteRef.set({
          'entityId': entityId,
          'email': email,
          'status': 'pending',
        }),
        '$email set',
      );
      await expectDenied(
        () => collectionRef.doc('other_invite').set({
          'entityId': entityId,
          'email': email,
          'status': 'pending',
        }),
        '$email create',
      );
      await expectDenied(() => inviteRef.delete(), '$email delete');
    }

    // The admin of the entity, a stranger, the invitee: all denied.
    await expectAllDenied(adminEmail);
    await expectAllDenied(strangerEmail);
    await expectAllDenied(invitedEmail);

    // The api still works for the admin, and cleans up.
    await signIn(adminEmail);
    expect(
      (await client.listEntityEmailInvites(
        entityId: entityId,
      )).map((e) => e.inviteId.v),
      [inviteId],
    );
    await client.deleteEntityEmailInvite(
      entityId: entityId,
      inviteId: inviteId,
    );
    await client.deleteEntity(entityId: entityId);
    await client.purgeEntity(entityId: entityId);
  });
}
