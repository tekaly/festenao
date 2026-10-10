import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/festenao_slug.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

void main() {
  setUpAll(initFestenaoFsBuilders);

  testWidgets('a project with its modules and its url', (tester) async {
    late WidgetRef widgetRef;
    late FestenaoFirestoreDatabase db;
    late UserProjectsSdb projectsSdb;
    await tester.runAsync(() async {
      var firebaseContext = (await initFirebaseServicesMemory()).initContext();
      db = FestenaoFirestoreDatabase(
        firebaseContext: firebaseContext,
        flavorContext: AppFlavorContext.test,
      );
      globalFestenaoFirestoreDatabaseOrNull = db;
      projectsSdb = UserProjectsSdb(
        name: 'projects',
        factory: newSdbFactoryMemory(),
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpdIdentityProvider.overrideWithValue(
            const TkCmsFbIdentityServiceAccount(projectId: 'test'),
          ),
          rpdUserProjectsDbProvider.overrideWithValue(projectsSdb),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    var userId = TkCmsFbIdentityServiceAccount.userLocalId;
    await tester.runAsync(() async {
      var projectId = await dashboardCreateProject(
        widgetRef,
        name: 'Festival des Tilleuls',
        slug: 'tilleuls',
        modules: ['meals'],
      );
      var fsProject = await db.projectDb
          .fsEntityRef(projectId)
          .get(db.firestore);
      expect(fsProject.name.v, 'Festival des Tilleuls');
      expect(fsProject.modules.v, ['meals']);
      expect(fsProject.slug.v, 'tilleuls');
      expect(await db.resolveProjectSlug('tilleuls'), projectId);
      var local = (await projectsSdb.getProject(projectId, userId: userId))!;
      expect(local.name.v, 'Festival des Tilleuls');
      expect(local.modules.v, ['meals']);
      expect(local.isAdmin, isTrue);

      // The url is taken: nothing is created.
      await expectLater(
        dashboardCreateProject(widgetRef, name: 'Other', slug: 'tilleuls'),
        throwsA(isA<FestenaoSlugTakenException>()),
      );
      expect(await projectsSdb.getProjects(userId: userId), hasLength(1));
    });
    globalFestenaoFirestoreDatabaseOrNull = null;
  });
}
