import 'package:festenao_common/data/src/demo/demo_constants.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/sembast/projects_db.dart';
import 'package:festenao_common/sembast/projects_db_synchronizer.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:test/test.dart';

Future<void> main() async {
  late TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> fsProjectsDb;
  late ProjectsDb projectsDb;
  var userId = 'test_user';
  var projectId = 'test_project';
  setUpAll(() async {
    initFestenaoFsBuilders();
  });
  setUp(() async {
    // ignore: deprecated_member_use
    var firestore = newFirestoreMemory().debugQuickLoggerWrapper();
    var dbFactory = newDatabaseFactoryMemory();

    projectsDb = ProjectsDb(name: 'my_projects', factory: dbFactory);
    await projectsDb.ready;
    fsProjectsDb = TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>(
      entityCollectionInfo: projectCollectionInfo,
      firestore: firestore,
      rootDocument: fsAppRoot('test'),
    );
  });
  test('syncOne', () async {
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
