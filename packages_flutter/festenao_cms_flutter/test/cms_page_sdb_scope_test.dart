// The page providers follow a cmsPageSdbScope put below the ProviderScope
// of the app (they were read from the app scope, in error).
import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<CmsPageSdb> _open(WidgetTester tester) async {
  late CmsPageSdb pages;
  await tester.runAsync(() async {
    var db = await newSdbFactoryMemory().openDatabase(
      'content.db',
      options: SdbOpenDatabaseOptions(
        version: 1,
        schema: SdbDatabaseSchema(stores: [cmsPageStoreSchema]),
      ),
    );
    pages = CmsPageSdb(db: db);
    addTearDown(() => db.close());
    await pages.addPage(SdbCmsPage()..title.v = 'Hello');
  });
  return pages;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('cmsPageSdbScope as the only ProviderScope', (tester) async {
    var pages = await _open(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: cmsPageSdbScope(sdb: pages, child: const CmsPagesScreen()),
      ),
    );
    await _settle(tester);
    expect(find.text('Hello'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 60)));
  testWidgets('cmsPageSdbScope below the app ProviderScope', (tester) async {
    var pages = await _open(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: cmsPageSdbScope(sdb: pages, child: const CmsPagesScreen()),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('Hello'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
