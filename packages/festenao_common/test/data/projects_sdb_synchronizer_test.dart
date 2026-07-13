import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/demo/demo_constants.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';

import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:test/test.dart';

Future<void> main() async {
  late TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> fsProjectsDb;
  late UserProjectsSdb projectsDb;
  var userId = 'test_user';
  var projectId = 'test_project';
  setUpAll(() async {
    initFestenaoFsBuilders();
  });
  setUp(() async {
    // ignore: deprecated_member_use
    var firestore = newFirestoreMemory().debugQuickLoggerWrapper();
    var dbFactory = newSdbFactoryMemory();

    projectsDb = UserProjectsSdb(name: 'my_projects', factory: dbFactory);
    await projectsDb.ready;
    fsProjectsDb = TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>(
      entityCollectionInfo: projectCollectionInfo,
      firestore: firestore,
      rootDocument: fsAppRoot('test'),
    );
  });
  test('syncOne', () async {
    expect(fsProjectsDb.fsEntityCollectionRef.path, 'app/test/project');
    var synchronizer = UserProjectsSdbSynchronizer(
      projectsSdb: projectsDb,
      fsProjects: fsProjectsDb,
    );
    var fsProject = FsProject()..name.setValue('test project');
    var projectUid = await fsProjectsDb.createEntity(
      userId: userId,
      entity: fsProject,
      entityId: projectId,
    );
    expect(projectUid, projectId);
    await synchronizer.syncOne(userId: userId, projectId: projectId);
    expect(await projectsDb.getProject(projectId, userId: userId), isNotNull);
    await fsProjectsDb.deleteEntity(projectUid, userId: userId);
    await synchronizer.syncOne(userId: userId, projectId: projectId);
    expect(await projectsDb.getProject(projectId, userId: userId), isNull);
    synchronizer.dispose();
  });
  test('syncUserProjects', () async {
    var synchronizer = UserProjectsSdbSynchronizer(
      projectsSdb: projectsDb,
      fsProjects: fsProjectsDb,
    );
    var firestore = fsProjectsDb.firestore;

    // No access yet: user marked ready with an empty project list
    await synchronizer.syncUserProjects(userId: userId);
    expect(await projectsDb.projectsUserReady(userId: userId), isNotNull);
    expect(await projectsDb.getProjects(userId: userId), isEmpty);

    // Create a project with admin access
    await fsProjectsDb.createEntity(
      userId: userId,
      entity: FsProject()..name.setValue('test project'),
      entityId: projectId,
    );
    await synchronizer.syncUserProjects(userId: userId);
    var dbProject = (await projectsDb.getProjects(userId: userId)).single;
    expect(dbProject.name.v, 'test project');
    expect(dbProject.fsId, projectId);
    expect(dbProject.isAdmin, isTrue);

    // Rename the project
    await fsProjectsDb
        .fsEntityRef(projectId)
        .set(firestore, FsProject()..name.setValue('renamed project'));
    await synchronizer.syncUserProjects(userId: userId);
    dbProject = (await projectsDb.getProjects(userId: userId)).single;
    expect(dbProject.name.v, 'renamed project');

    // Local records can be keyed by a different identity id
    await synchronizer.syncUserProjects(
      userId: userId,
      identityId: 'local_identity',
    );
    dbProject = (await projectsDb.getProjects(userId: 'local_identity')).single;
    expect(dbProject.name.v, 'renamed project');

    // Delete the project
    await fsProjectsDb.deleteEntity(projectId, userId: userId);
    await synchronizer.syncUserProjects(userId: userId);
    expect(await projectsDb.getProjects(userId: userId), isEmpty);
    synchronizer.dispose();
  });
  test('autoSyncOne', () async {
    var synchronizer = ProjectsDbSingleProjectAutoSynchronizer(
      projectsDb: projectsDb,
      fsProjects: fsProjectsDb,
      projectId: testProjectId,
      userId: userId,
    );
    var fsProject = FsProject()..name.setValue('test project');
    var projectUid = await fsProjectsDb.createEntity(
      userId: userId,
      entity: fsProject,
      entityId: projectId,
    );
    // ignore: avoid_print
    print('projectUid: $projectUid');
    await sleep(1000);
    synchronizer.dispose();
  });
}
