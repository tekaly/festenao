import 'package:festenao_common/festenao_cms.dart';
import 'package:test/test.dart';

void main() {
  group('cmsSlugify', () {
    test('basic', () {
      expect(cmsSlugify('Hello World'), 'hello-world');
      expect(cmsSlugify('  Café  crème & Œuf!! '), 'cafe-creme-oeuf');
      expect(cmsSlugify('Salle n°2 (étage)'), 'salle-n-2-etage');
      expect(cmsSlugify('---'), 'page');
      expect(cmsSlugify('', fallback: 'x'), 'x');
    });
    test('max length', () {
      var slug = cmsSlugify('word ' * 40);
      expect(slug.length, lessThanOrEqualTo(cmsSlugMaxLength));
      expect(slug.endsWith('-'), isFalse);
    });
  });

  group('CmsPageSdb', () {
    late SdbDatabase db;
    late CmsPageSdb pageSdb;
    setUp(() async {
      var factory = newSdbFactoryMemory();
      db = await factory.openDatabase(
        'cms_test.db',
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(stores: [cmsPageStoreSchema]),
        ),
      );
      pageSdb = CmsPageSdb(db: db);
    });
    tearDown(() async {
      await db.close();
    });

    test('add sets slug and timestamps', () async {
      var page = await pageSdb.addPage(
        SdbCmsPage()
          ..title.v = 'Le Grand Étang'
          ..body.v = '# Hello',
      );
      expect(page.slug.v, 'le-grand-etang');
      expect(page.created.v, isNotNull);
      expect(page.updated.v, isNotNull);
      expect(page.publishedAt.v, isNull);
      expect(page.isPublished, isFalse);
      expect((await pageSdb.getPageBySlug('le-grand-etang'))?.id, page.id);
      expect(await pageSdb.getPageBySlug('nope'), isNull);
    });

    test('slug unicity', () async {
      var page1 = await pageSdb.addPage(SdbCmsPage()..title.v = 'Dup');
      var page2 = await pageSdb.addPage(SdbCmsPage()..title.v = 'Dup');
      var page3 = await pageSdb.addPage(
        SdbCmsPage()
          ..title.v = 'Other'
          ..slug.v = 'dup',
      );
      expect(page1.slug.v, 'dup');
      expect(page2.slug.v, 'dup-2');
      expect(page3.slug.v, 'dup-3');

      // Renaming to an existing slug bumps it, keeping its own is fine.
      await pageSdb.updatePage(page3.id, (page) => page.slug.v = 'dup');
      expect((await pageSdb.getPage(page3.id))!.slug.v, 'dup-3');
      await pageSdb.updatePage(page3.id, (page) => page.title.v = 'Other 2');
      expect((await pageSdb.getPage(page3.id))!.slug.v, 'dup-3');
    });

    test('publish and lists', () async {
      var page1 = await pageSdb.addPage(
        SdbCmsPage()
          ..title.v = 'B'
          ..order.v = 2,
      );
      var page2 = await pageSdb.addPage(
        SdbCmsPage()
          ..title.v = 'A'
          ..order.v = 1
          ..itemKind.v = cmsItemKindLocation
          ..itemId.v = 'loc1',
      );
      expect((await pageSdb.getPages()).map((e) => e.id), [page2.id, page1.id]);
      expect(await pageSdb.getPages(publishedOnly: true), isEmpty);
      await pageSdb.setPublished(page1.id, true);
      var published = await pageSdb.getPages(publishedOnly: true);
      expect(published.map((e) => e.id), [page1.id]);
      expect(published.first.publishedAt.v, isNotNull);
      expect(
        (await pageSdb.getPagesForItem(
          itemKind: cmsItemKindLocation,
          itemId: 'loc1',
        )).map((e) => e.id),
        [page2.id],
      );
      await pageSdb.deletePage(page1.id);
      expect(await pageSdb.getPage(page1.id), isNull);
    });

    test('update unknown', () async {
      expect(await pageSdb.updatePage('nope', (page) {}), isNull);
    });
  });
}
