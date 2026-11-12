import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'cms_pages_screen_test.dart' show openTestSdb, pumpUntil;

void main() {
  testWidgets('a kind change drops the item of the previous kind', (
    tester,
  ) async {
    var sdb = await openTestSdb(tester, 'cms_kind.db');
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: cmsPageSdbScope(
          sdb: sdb,
          child: const CmsPageEditScreen(
            pageId: null,
            initialItem: CmsLinkableItem(
              kind: cmsItemKindEvent,
              id: 'concert',
              name: 'Concert',
            ),
            linkableItems: [
              CmsLinkableItem(
                kind: cmsItemKindEvent,
                id: 'concert',
                name: 'Concert',
              ),
              CmsLinkableItem(
                kind: cmsItemKindLocation,
                id: 'hall',
                name: 'Main hall',
              ),
            ],
          ),
        ),
      ),
    );
    await pumpUntil(tester, find.text('New page'));
    await tester.pumpAndSettle();
    // The event is picked
    expect(find.text('Concert'), findsWidgets);
    // Now presents a location, no location picked
    await tester.tap(find.text(cmsItemKindEvent));
    await tester.pumpAndSettle();
    await tester.tap(find.text(cmsItemKindLocation).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save'));
    await pumpUntil(
      tester,
      find.byType(CmsPageEditScreen),
      matcher: findsNothing,
    );
    await tester.runAsync(() async {
      var page = (await sdb.getPages()).single;
      expect(page.itemKind.v, cmsItemKindLocation);
      // Not the event id under the location kind
      expect(page.itemId.v, isNull);
    });
  }, timeout: const Timeout(Duration(seconds: 60)));
}
