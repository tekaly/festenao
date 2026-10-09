import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/festenao_modules.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

void main() {
  setUpAll(initFestenaoFsBuilders);

  test('every module when null', () {
    expect(festenaoProjectHasModule(null, 'quizz'), isTrue);
    expect(festenaoProjectHasModule(['quizz'], 'quizz'), isTrue);
    expect(festenaoProjectHasModule(['quizz'], 'blog'), isFalse);
    expect(festenaoProjectHasModule([], 'blog'), isFalse);
    expect(festenaoProjectModulesEquals(null, null), isTrue);
    expect(festenaoProjectModulesEquals(['a'], null), isFalse);
    expect(festenaoProjectModulesEquals(['a', 'b'], ['a', 'b']), isTrue);
    expect(festenaoProjectModulesEquals(['a', 'b'], ['b', 'a']), isFalse);
  });

  test('set, read and mirror locally', () async {
    var firebaseContext = (await initFirebaseServicesMemory()).initContext();
    var db = FestenaoFirestoreDatabase(
      firebaseContext: firebaseContext,
      flavorContext: AppFlavorContext.test,
    );
    const userId = 'u1';
    var projectId = await db.projectDb.createEntity(
      userId: userId,
      entity: FsProject()..name.v = 'Festival',
    );
    expect(await db.getProjectModules(projectId), isNull);

    var projectsSdb = UserProjectsSdb(
      name: 'projects',
      factory: newSdbFactoryMemory(),
    );
    var synchronizer = UserProjectsSdbSynchronizer(
      projectsSdb: projectsSdb,
      fsProjects: db.projectDb,
    );
    await synchronizer.syncUserProjects(userId: userId);
    var local = (await projectsSdb.getProject(projectId, userId: userId))!;
    expect(local.modules.v, isNull);
    expect(local.hasModule('meals'), isTrue);

    await db.setProjectModules(projectId, ['meals', 'nights']);
    var fsProject = await db.projectDb.fsEntityRef(projectId).get(db.firestore);
    expect(fsProject.modules.v, ['meals', 'nights']);
    expect(fsProject.name.v, 'Festival');
    expect(fsProject.hasModule('team'), isFalse);

    // The full sync and the single project one both mirror it.
    await synchronizer.syncUserProjects(userId: userId);
    local = (await projectsSdb.getProject(projectId, userId: userId))!;
    expect(local.modules.v, ['meals', 'nights']);
    expect(local.hasModule('team'), isFalse);

    await db.setProjectModules(projectId, ['meals']);
    await synchronizer.syncOne(userId: userId, projectId: projectId);
    local = (await projectsSdb.getProject(projectId, userId: userId))!;
    expect(local.modules.v, ['meals']);
    expect(local.name.v, 'Festival');

    // Back to every module.
    await db.setProjectModules(projectId, null);
    expect(await db.getProjectModules(projectId), isNull);
    await synchronizer.syncOne(userId: userId, projectId: projectId);
    local = (await projectsSdb.getProject(projectId, userId: userId))!;
    expect(local.modules.v, isNull);
    synchronizer.dispose();
    await projectsSdb.close();
  });
}
