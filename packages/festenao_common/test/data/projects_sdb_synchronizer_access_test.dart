import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:test/test.dart';

void main() {
  late TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> fsProjects;
  late UserProjectsSdb projectsSdb;
  late UserProjectsSdbSynchronizer synchronizer;
  var userId = 'test_user';
  var projectId = 'test_project';

  setUpAll(initFestenaoFsBuilders);
  setUp(() async {
    // ignore: deprecated_member_use
    var firestore = newFirestoreMemory();
    projectsSdb = UserProjectsSdb(
      name: 'access_test',
      factory: newSdbFactoryMemory(),
    );
    await projectsSdb.ready;
    fsProjects = TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>(
      entityCollectionInfo: projectCollectionInfo,
      firestore: firestore,
      rootDocument: fsAppRoot('test'),
    );
    synchronizer = UserProjectsSdbSynchronizer(
      projectsSdb: projectsSdb,
      fsProjects: fsProjects,
    );
    await fsProjects.createEntity(
      userId: userId,
      entity: FsProject()..name.setValue('project'),
      entityId: projectId,
    );
  });
  tearDown(() async {
    synchronizer.dispose();
    await projectsSdb.close();
  });

  Future<void> setAccess(TkCmsFsUserAccess? access) async {
    var ref = fsProjects.fsUserEntityAccessRef(userId, projectId);
    if (access == null) {
      await ref.delete(fsProjects.firestore);
    } else {
      await ref.set(fsProjects.firestore, access);
    }
  }

  test('syncUserProjects applies a revoked right', () async {
    await synchronizer.syncUserProjects(userId: userId);
    var project = (await projectsSdb.getProjects(userId: userId)).single;
    expect(project.isAdmin, isTrue);
    await setAccess(TkCmsFsUserAccess()..read.v = true);
    await synchronizer.syncUserProjects(userId: userId);
    project = (await projectsSdb.getProjects(userId: userId)).single;
    expect(project.isRead, isTrue);
    expect(project.isWrite, isFalse);
    expect(project.isAdmin, isFalse);
    expect(project.admin.v, isNull);
    expect(project.write.v, isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('syncOne applies a revoked right', () async {
    await synchronizer.syncOne(userId: userId, projectId: projectId);
    expect(
      (await projectsSdb.getProject(projectId, userId: userId))!.isAdmin,
      isTrue,
    );
    await setAccess(TkCmsFsUserAccess()..read.v = true);
    await synchronizer.syncOne(userId: userId, projectId: projectId);
    var project = (await projectsSdb.getProject(projectId, userId: userId))!;
    expect(project.isRead, isTrue);
    expect(project.isAdmin, isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('syncOne drops a project the user lost access to', () async {
    await synchronizer.syncOne(userId: userId, projectId: projectId);
    expect(await projectsSdb.getProject(projectId, userId: userId), isNotNull);
    await setAccess(null);
    await synchronizer.syncOne(userId: userId, projectId: projectId);
    expect(await projectsSdb.getProject(projectId, userId: userId), isNull);
    // As syncUserProjects does.
    await synchronizer.syncUserProjects(userId: userId);
    expect(await projectsSdb.getProjects(userId: userId), isEmpty);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
