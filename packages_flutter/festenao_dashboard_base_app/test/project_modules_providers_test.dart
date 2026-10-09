import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_modules.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

void main() {
  setUpAll(initFestenaoFsBuilders);

  test('the modules of a project follow its local mirror', () async {
    var firebaseContext = (await initFirebaseServicesMemory()).initContext();
    var db = FestenaoFirestoreDatabase(
      firebaseContext: firebaseContext,
      flavorContext: AppFlavorContext.test,
    );
    // The signed in identity: a service account, whose user id is fixed.
    var userId = TkCmsFbIdentityServiceAccount.userLocalId;
    var projectId = await db.projectDb.createEntity(
      userId: userId,
      entity: FsProject()..name.v = 'Festival',
    );
    var projectsSdb = UserProjectsSdb(
      name: 'projects',
      factory: newSdbFactoryMemory(),
    );
    var container = ProviderContainer(
      overrides: [
        rpdIdentityProvider.overrideWithValue(
          const TkCmsFbIdentityServiceAccount(projectId: 'test'),
        ),
        rpdUserProjectsDbProvider.overrideWithValue(projectsSdb),
      ],
    );
    addTearDown(container.dispose);
    var values = <List<String>?>[];
    container.listen(
      projectModulesProvider(projectId),
      (_, next) => values.add(next.value),
      fireImmediately: true,
    );

    await db.setProjectModulesAndMirror(
      projectId,
      [dashboardModuleContent],
      projectsSdb: projectsSdb,
      userId: userId,
    );
    await container.read(projectModulesProvider(projectId).future);
    for (var i = 0; i < 20 && values.lastOrNull?.isEmpty != false; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(values.last, [dashboardModuleContent]);

    await db.setProjectModulesAndMirror(
      projectId,
      null,
      projectsSdb: projectsSdb,
      userId: userId,
    );
    for (var i = 0; i < 20 && values.last != null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(values.last, isNull);
  });

  test('signed out: every module', () async {
    var container = ProviderContainer(
      overrides: [rpdIdentityProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);
    // Kept alive while read (the provider is auto disposed).
    container.listen(projectModulesProvider('p'), (_, _) {});
    expect(await container.read(projectModulesProvider('p').future), isNull);
  });
}
