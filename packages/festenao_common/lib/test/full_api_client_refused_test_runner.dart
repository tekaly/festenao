import 'package:dev_test/test.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

import 'festenao_test_server_test_runner.dart';

bool _isPermissionDenied(Object e) =>
    e is FirestoreException && e.code == FirestoreErrorCode.permissionDenied;

/// The full api context (`festenao_firebase_full_api_context`): the client
/// firestore is refused everything, reads included, whoever it is (the
/// entity admin, a public entity reader, signed out). The api is the only way
/// in.
///
/// Only meaningful where the rules apply (the emulator): an in memory
/// firestore refuses nothing.
void appFullApiClientRefusedTestRunner(
  Future<FestenaoTestServerContext> Function() initAllContext,
) {
  late FestenaoTestServerContext context;

  setUpAll(() async {
    context = await initAllContext();
  });

  test(
    'the client reads and writes nothing, not even the entity admin',
    () async {
      var client = context.projectApiClient;
      var auth = context.clientContext.firebaseAuth!;
      var firestore = context.clientContext.firestore!;
      var projectDb = context.fsDatabase.projectDb;
      var adminEmail = 'fullapiadmin@festenao-rules-test.local';
      var password = 'test1234';

      Future<String> signInAdmin() async {
        await auth.signOut();
        var userCredential = await auth.signInOrUpWithEmailAndPassword(
          email: adminEmail,
          password: password,
        );
        return userCredential.user.uid;
      }

      // The api creates the entity (and its admin access rows), an invite and
      // the public flag: the server writes with its admin credentials.
      var adminUserId = await signInAdmin();
      var entityId = (await client.createEntity(
        entity: FsProject()..name.v = 'full api',
      )).id;
      var inviteId = await client.createEntityInvite(
        entityId: entityId,
        fsUserAccess: TkCmsFsUserAccess()..read.v = true,
      );
      expect(
        await client.setEntityPublic(entityId: entityId, public: true),
        isTrue,
      );

      var entityRef = projectDb.fsEntityRef(entityId).raw(firestore);
      var entityCollectionPath = projectDb.fsEntityCollectionRef.path;
      // `app/<app>`, the parent of the entity collection.
      var topPath = entityCollectionPath.substring(
        0,
        entityCollectionPath.lastIndexOf('/'),
      );
      var refs = [
        firestore.doc(topPath),
        entityRef,
        firestore.doc('${entityRef.path}/data/d1'),
        projectDb.fsEntityUserAccessRef(entityId, adminUserId).raw(firestore),
        projectDb.fsUserEntityAccessRef(adminUserId, entityId).raw(firestore),
        projectDb.fsEntityPublicAccessRef(entityId).raw(firestore),
        projectDb.fsInviteIdRef(inviteId).raw(firestore),
        projectDb.fsInviteEntityRef(inviteId, entityId).raw(firestore),
        firestore.doc('$topPath/user_prv/$adminUserId'),
        firestore.doc('public/get/doc/doc1'),
      ];

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

      Future<void> expectAllDenied(String who) async {
        for (var ref in refs) {
          await expectDenied(() => ref.get(), '$who get ${ref.path}');
          await expectDenied(
            () => ref.set({'probe': who}),
            '$who set ${ref.path}',
          );
          await expectDenied(() => ref.delete(), '$who delete ${ref.path}');
        }
        await expectDenied(
          () => projectDb.fsEntityCollectionRef.raw(firestore).get(),
          '$who list',
        );
      }

      // The entity admin (of a public entity), then signed out: all denied.
      await expectAllDenied('entity admin');
      await auth.signOut();
      await expectAllDenied('signed out');

      // The api still works for the admin, and cleans up.
      await signInAdmin();
      await client.deleteEntity(entityId: entityId);
      await client.purgeEntity(entityId: entityId);
    },
  );
}
