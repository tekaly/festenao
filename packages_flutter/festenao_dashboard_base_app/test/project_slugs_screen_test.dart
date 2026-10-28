import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_common/festenao_slug.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:festenao_dashboard_base_app/screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

/// The memory database timers run in the test zone, the firestore snapshots
/// for real: both clocks move.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(initFestenaoFsBuilders);
  late FestenaoFirestoreDatabase db;

  Future<String> createProject(WidgetTester tester, String name) async =>
      (await tester.runAsync(
        () => db.projectDb.createEntity(
          userId: 'u1',
          entity: FsProject()..name.v = name,
        ),
      ))!;

  Future<List<String>> urlSlugs(WidgetTester tester, String projectId) async =>
      (await tester.runAsync(
        () async =>
            (await db.projectDb.fsEntityRef(projectId).get(db.firestore))
                .urlSlugs,
      ))!;

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    bool canSetSlug = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dashboardCanSetSlugProvider.overrideWithValue(canSetSlug)],
        child: MaterialApp(
          localizationsDelegates: festenaoAdminAppAllLocalizationsDelegates,
          supportedLocales: festenaoAdminAppSupportedLocales,
          home: screen,
        ),
      ),
    );
    await _settle(tester);
  }

  setUp(() async {
    db = FestenaoFirestoreDatabase(
      firebaseContext: (await initFirebaseServicesMemory()).initContext(),
      flavorContext: AppFlavorContext.test,
    );
    globalFestenaoFirestoreDatabaseOrNull = db;
  });
  tearDown(() {
    globalFestenaoFirestoreDatabaseOrNull = null;
  });

  testWidgets('the urls of a project: add, make current, remove', (
    tester,
  ) async {
    var projectId = await createProject(tester, 'Trad hiv');
    await pumpScreen(tester, DashboardProjectSlugsScreen(projectId: projectId));
    expect(
      find.text('No url of its own: the project opens at its id'),
      findsOneWidget,
    );

    Future<void> add(String slug) async {
      await tester.enterText(find.byType(TextField), slug);
      await _settle(tester);
      await tester.tap(find.text('Add the url'));
      await _settle(tester);
    }

    await add('tradhiv');
    expect(await urlSlugs(tester, projectId), ['tradhiv']);
    expect(find.text('Current'), findsOneWidget);
    await add('tradhiv2027');
    expect(await urlSlugs(tester, projectId), ['tradhiv', 'tradhiv2027']);
    expect(find.textContaining('/p/tradhiv2027'), findsOneWidget);

    // The second one becomes the current url.
    await tester.tap(find.byType(PopupMenuButton<String>).at(1));
    await _settle(tester);
    await tester.tap(find.text('Make it the current url'));
    await _settle(tester);
    expect(await urlSlugs(tester, projectId), ['tradhiv2027', 'tradhiv']);

    // The previous one removed, after a confirmation.
    await tester.tap(find.byType(PopupMenuButton<String>).at(1));
    await _settle(tester);
    await tester.tap(find.text('Remove'));
    await _settle(tester);
    expect(find.textContaining('Its links stop working'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await _settle(tester);
    expect(await urlSlugs(tester, projectId), ['tradhiv2027']);
    expect(
      await tester.runAsync(() => db.resolveProjectSlug('tradhiv')),
      isNull,
    );
  });

  testWidgets('the urls of a project, without the slug right', (tester) async {
    var projectId = await createProject(tester, 'Blog');
    await tester.runAsync(() => db.setProjectSlug(projectId, 'blog'));
    await pumpScreen(
      tester,
      DashboardProjectSlugsScreen(projectId: projectId),
      canSetSlug: false,
    );
    expect(find.textContaining('/p/blog'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(
      find.textContaining('Only the app admins and the users allowed'),
      findsOneWidget,
    );
  });

  testWidgets('every url in use', (tester) async {
    var blogId = await createProject(tester, 'Blog');
    await tester.runAsync(() async {
      await db.setProjectSlug(blogId, 'blog');
      await db.addProjectSlug(blogId, 'my-blog');
      await db.slugRegistry().claim(
        slug: 'an-event',
        entityType: 'event',
        entityId: 'e1',
      );
    });
    await pumpScreen(tester, const DashboardSlugsScreen());
    expect(find.text('/p/an-event'), findsOneWidget);
    expect(find.text('/p/blog'), findsOneWidget);
    expect(find.text('/p/my-blog'), findsOneWidget);
    // The extra url is an alias, the project named.
    expect(find.text('Alias'), findsOneWidget);
    expect(find.text('Blog · project $blogId'), findsNWidgets(2));
    expect(find.text('event e1'), findsOneWidget);

    // Released: the project copy follows.
    await tester.tap(find.byType(PopupMenuButton<String>).at(2));
    await _settle(tester);
    await tester.tap(find.text('Release'));
    await _settle(tester);
    await tester.tap(find.text('Release'));
    await _settle(tester);
    expect(find.text('/p/my-blog'), findsNothing);
    expect(await urlSlugs(tester, blogId), ['blog']);
    expect(
      await tester.runAsync(() => db.resolveProjectSlug('my-blog')),
      isNull,
    );
  });
}
