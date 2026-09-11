import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pump until [finder] matches [matcher].
///
/// The database is opened under [WidgetTester.runAsync] so its transactions
/// complete on the real event loop: each iteration gives it a real tick, then
/// pumps a frame.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Matcher matcher = findsWidgets,
}) async {
  for (var i = 0; i < 50; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (matcher.matches(finder, {})) {
      return;
    }
  }
  fail('$finder not matching $matcher');
}

Future<CmsPageSdb> openTestSdb(WidgetTester tester, String name) async {
  late CmsPageSdb sdb;
  await tester.runAsync(() async {
    var db = await newSdbFactoryMemory().openDatabase(
      name,
      options: SdbOpenDatabaseOptions(
        version: 1,
        schema: SdbDatabaseSchema(stores: [cmsPageStoreSchema]),
      ),
    );
    sdb = CmsPageSdb(db: db);
    addTearDown(() => db.close());
  });
  return sdb;
}

void main() {
  testWidgets('pages list, publish toggle, edit', (tester) async {
    var sdb = await openTestSdb(tester, 'cms.db');
    await tester.runAsync(() async {
      await sdb.addPage(
        SdbCmsPage()
          ..title.v = 'Hello'
          ..summary.v = 'World',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: cmsPageSdbScope(sdb: sdb, child: const CmsPagesScreen()),
      ),
    );
    await pumpUntil(tester, find.text('Hello'));
    expect(find.byType(Switch), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await pumpUntil(
      tester,
      find.byWidgetPredicate((widget) => widget is Switch && widget.value),
    );
    await tester.runAsync(() async {
      expect((await sdb.getPages(publishedOnly: true)).length, 1);
    });

    await tester.tap(find.text('Hello'));
    await pumpUntil(tester, find.byType(CmsPageEditScreen));
    await pumpUntil(tester, find.text('/page/'));
    // Let the route transition finish (taps are ignored meanwhile).
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Hi there',
    );
    await tester.tap(find.byIcon(Icons.save));
    // Saved and popped back to the list.
    await pumpUntil(
      tester,
      find.byType(CmsPageEditScreen),
      matcher: findsNothing,
    );
    await pumpUntil(tester, find.text('Hi there'));
    await tester.runAsync(() async {
      var page = (await sdb.getPages()).single;
      expect(page.title.v, 'Hi there');
      // Slug kept (edited flag set on load).
      expect(page.slug.v, 'hello');
      expect(page.isPublished, isTrue);
    });
  });

  testWidgets('create page', (tester) async {
    var sdb = await openTestSdb(tester, 'cms2.db');

    await tester.pumpWidget(
      MaterialApp(
        home: cmsPageSdbScope(
          sdb: sdb,
          child: const CmsPageEditScreen(pageId: null),
        ),
      ),
    );
    await pumpUntil(tester, find.text('New page'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Le Café',
    );
    await tester.pump();
    expect(find.text('le-cafe'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Body (markdown)'),
      '# Welcome',
    );
    await tester.tap(find.byIcon(Icons.save));
    await pumpUntil(
      tester,
      find.byType(CmsPageEditScreen),
      matcher: findsNothing,
    );
    await tester.runAsync(() async {
      var page = (await sdb.getPages()).single;
      expect(page.slug.v, 'le-cafe');
      expect(page.body.v, '# Welcome');
      expect(page.isPublished, isFalse);
    });
  });
}
