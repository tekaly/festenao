import 'package:festenao_common/festenao_slug.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_dashboard_base_app/router.dart';
import 'package:festenao_dashboard_base_app/screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

void main() {
  testWidgets('/p/<slug> opens the project', (tester) async {
    late FestenaoFirestoreDatabase db;
    late String projectId;
    await tester.runAsync(() async {
      db = FestenaoFirestoreDatabase(
        firebaseContext: (await initFirebaseServicesMemory()).initContext(),
        flavorContext: AppFlavorContext.test,
      );
      projectId = await db.projectDb.createEntity(
        userId: 'u1',
        entity: FsProject()..name.v = 'Blog',
      );
      await db.setProjectSlug(projectId, 'my-blog');
    });
    var router = GoRouter(
      initialLocation: '/p/my-blog',
      routes: [
        GoRoute(
          path: '/p/:slug',
          builder: (context, state) => DashboardProjectSlugScreen(
            slug: state.pathParameters['slug']!,
            fsDatabase: db,
            projectLocation: (id) => '/project/$id',
          ),
        ),
        GoRoute(
          path: '/project/:id',
          builder: (context, state) =>
              Text('project ${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      // The fake clock too: the memory database timers run in the test zone.
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('project $projectId'), findsOneWidget);
    expect(dashboardProjectSlugLocation('my-blog'), '/p/my-blog');
    expect(festenaoProjectUrlPathSegment, 'p');
  });
}
