import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SdbDatabase db;
  late CmsPageSdb sdb;

  setUp(() async {
    db = await newSdbFactoryMemory().openDatabase(
      'cms.db',
      options: SdbOpenDatabaseOptions(
        version: 1,
        schema: SdbDatabaseSchema(stores: [cmsPageStoreSchema]),
      ),
    );
    sdb = CmsPageSdb(db: db);
  });
  tearDown(() async {
    await db.close();
  });

  Widget app(Widget child) => MaterialApp(
    home: cmsPageSdbScope(sdb: sdb, child: child),
  );

  testWidgets('pages list, publish toggle, edit', (tester) async {
    await sdb.addPage(
      SdbCmsPage()
        ..title.v = 'Hello'
        ..summary.v = 'World',
    );
    await tester.pumpWidget(app(const CmsPagesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect((await sdb.getPages(publishedOnly: true)).length, 1);

    await tester.tap(find.text('Hello'));
    await tester.pumpAndSettle();
    expect(find.byType(CmsPageEditScreen), findsOneWidget);
    expect(find.text('/page/'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Hi there',
    );
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    var page = (await sdb.getPages()).single;
    expect(page.title.v, 'Hi there');
    // Slug kept (edited flag set on load).
    expect(page.slug.v, 'hello');
  });

  testWidgets('create page', (tester) async {
    await tester.pumpWidget(app(const CmsPageEditScreen(pageId: null)));
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    var page = (await sdb.getPages()).single;
    expect(page.slug.v, 'le-cafe');
    expect(page.body.v, '# Welcome');
    expect(page.isPublished, isFalse);
  });
}
