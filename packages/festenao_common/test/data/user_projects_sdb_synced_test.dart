import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:test/test.dart';

Future<void> main() async {
  var userId = 'test_user';
  test('fsUserPrvProjectsPath', () {
    expect(
      fsUserPrvProjectsPath(app: 'test', userId: userId),
      'app/test/user_prv/test_user/data/projects',
    );
  });
  test('userSynced', () async {
    var firestore = newFirestoreMemory();
    var factory = newSdbFactoryMemory();
    var db = UserProjectsSdb.userSynced(
      factory: factory,
      name: 'projects.db',
      firestore: firestore,
      app: 'test',
      userId: userId,
    );
    expect(db.isSynced, isTrue);
    expect(db.userId, userId);
    await db.ready;

    // The local factory is sandboxed to the user id
    expect(
      await db.factory.getDatabaseFullPath('projects.db'),
      contains(userId),
    );

    // Add a project locally and synchronize
    await db.addProject(
      SdbUserProject()
        ..uid.v = 'project_1'
        ..userId.v = userId
        ..name.v = 'Project 1',
    );
    await db.synchronize();

    // Data lands in firestore under app/<app>/user_prv/<userId>/data/projects
    var dataDocs = await firestore
        .collection('app/test/user_prv/$userId/data/projects/data')
        .get();
    expect(dataDocs.docs, isNotEmpty);
    var metaInfo = await firestore
        .doc('app/test/user_prv/$userId/data/projects/meta/info')
        .get();
    expect(metaInfo.exists, isTrue);

    await db.close();
  });
  test('manager', () async {
    var firestore = newFirestoreMemory();
    var factory = newSdbFactoryMemory();
    var manager = UserProjectsSdbManager(
      factory: factory,
      firestore: firestore,
      app: 'test',
      name: 'projects.db',
    );
    var localDb = await manager.setCurrentUser(null);
    expect(localDb.isSynced, isFalse);
    expect(localDb.userId, isNull);
    expect(globalProjectsSdbOrNull, localDb);

    var user1Db = await manager.setCurrentUser('user1');
    expect(user1Db.isSynced, isTrue);
    expect(user1Db.userId, 'user1');
    expect(globalProjectsSdbOrNull, user1Db);
    expect(manager.currentDb, user1Db);

    // Same user: same database
    expect(await manager.setCurrentUser('user1'), user1Db);

    // Other user: new sandboxed database
    var user2Db = await manager.setCurrentUser('user2');
    expect(user2Db, isNot(user1Db));
    expect(
      await user2Db.factory.getDatabaseFullPath('projects.db'),
      isNot(await user1Db.factory.getDatabaseFullPath('projects.db')),
    );

    await manager.close();
    expect(globalProjectsSdbOrNull, isNull);
  });
}
