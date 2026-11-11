// ignore_for_file: avoid_print

import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:tkcms_common/tkcms_auth.dart';

/// A festenao server and its client in memory: an owner creates a project,
/// invites a guest and publishes the project; the guest accepts the invite
/// and, being a writer only, may not unpublish it.
///
/// `dart run example/main.dart`, nothing is written on disk.
Future<void> main() async {
  var context = await initFestenaoTestServerContextAllMemory();
  var auth = context.clientContext.firebaseAuth!;
  var client = context.projectApiClient;
  var projectDb = context.fsDatabase.projectDb;

  await auth.signInOrUpWithEmailAndPassword(
    email: 'owner@test.local',
    password: 'test1234',
  );
  var project = await client.createEntity(entity: FsProject()..name.v = 'Demo');
  var inviteId = await client.createEntityInvite(
    entityId: project.id,
    fsUserAccess: TkCmsFsUserAccess()
      ..read.v = true
      ..write.v = true,
  );
  // The creator is an admin of the project: it may publish it.
  var isPublic = await client.setEntityPublic(
    entityId: project.id,
    public: true,
  );
  print('public: $isPublic'); // true

  await auth.signOut();
  await auth.signInOrUpWithEmailAndPassword(
    email: 'guest@test.local',
    password: 'test1234',
  );
  await client.acceptEntityInvite(entityId: project.id, inviteId: inviteId);
  var access = await projectDb
      .fsEntityUserAccessRef(project.id, auth.currentUser!.uid)
      .get(projectDb.firestore);
  // guest may write: true, admin: false
  print('guest may write: ${access.write.v}, admin: ${access.admin.v}');

  // A writer is not an admin: publishing is refused.
  try {
    await client.setEntityPublic(entityId: project.id, public: false);
  } on ApiException catch (e) {
    print(e.error?.code.v); // permission-denied
  }
  await context.close();
}
