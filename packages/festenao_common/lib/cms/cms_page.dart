import 'package:festenao_common/festenao_sdb.dart';

/// Body format: markdown (the default).
const cmsPageBodyFormatMarkdown = 'markdown';

/// Body format: raw html, only for trusted (admin) content.
const cmsPageBodyFormatHtml = 'html';

/// All the body formats.
const cmsPageBodyFormats = [cmsPageBodyFormatMarkdown, cmsPageBodyFormatHtml];

/// A free standing page (about, contact...).
const cmsItemKindPage = 'page';

/// A page presenting a location (a place, a venue, a site).
const cmsItemKindLocation = 'location';

/// A page presenting an activity (something one can book or attend).
const cmsItemKindActivity = 'activity';

/// A page presenting an event (a dated activity).
const cmsItemKindEvent = 'event';

/// A page presenting an offer (a product, a tariff).
const cmsItemKindOffer = 'offer';

/// All the item kinds.
const cmsItemKinds = [
  cmsItemKindPage,
  cmsItemKindLocation,
  cmsItemKindActivity,
  cmsItemKindEvent,
  cmsItemKindOffer,
];

/// Maximum length of a generated slug.
const cmsSlugMaxLength = 80;

/// An image of a page.
///
/// [mediaId] references a festenao media file (see `FestenaoMediaSdb`), [url]
/// is an absolute url usable as is; a renderer resolves the media id to a url
/// when only the former is set.
class CvCmsImage extends CvModelBase {
  /// Festenao media file id.
  final mediaId = CvField<String>('mediaId');

  /// Absolute url, when known.
  final url = CvField<String>('url');

  /// Alternative text (accessibility and SEO).
  final alt = CvField<String>('alt');

  /// Optional caption.
  final caption = CvField<String>('caption');

  /// Width in pixels, when known.
  final width = CvField<int>('width');

  /// Height in pixels, when known.
  final height = CvField<int>('height');

  @override
  CvFields get fields => [mediaId, url, alt, caption, width, height];
}

/// A CMS page: what a static, SEO friendly html page is rendered from.
///
/// Lives in a (typically synced) sdb next to the content it presents, one
/// store per database ([cmsPageStore]). A page either stands on its own
/// ([cmsItemKindPage]) or presents an item of the content database
/// ([itemKind] + [itemId]: a location, an activity, an event, an offer), in
/// which case the renderer can enrich it with structured data.
class SdbCmsPage extends ScvStringRecordBase {
  /// Url slug, unique within the database (`/page/<slug>`).
  final slug = CvField<String>('slug');

  /// Page title (h1).
  final title = CvField<String>('title');

  /// Short summary, used as the default meta description and in lists.
  final summary = CvField<String>('summary');

  /// The body, see [bodyFormat].
  final body = CvField<String>('body');

  /// [cmsPageBodyFormatMarkdown] (default) or [cmsPageBodyFormatHtml].
  final bodyFormat = CvField<String>('bodyFormat');

  /// Main image (open graph image, page header).
  final heroImage = CvModelField<CvCmsImage>('heroImage');

  /// Gallery images.
  final images = CvModelListField<CvCmsImage>('images');

  /// What this page presents, see [cmsItemKinds].
  final itemKind = CvField<String>('itemKind');

  /// Id of the presented item in the content database, when any.
  final itemId = CvField<String>('itemId');

  /// Free tags.
  final tags = CvListField<String>('tags');

  /// Only published pages are served.
  final published = CvField<bool>('published');

  /// When the page was first published.
  final publishedAt = CvField<SdbTimestamp>('publishedAt');

  /// Title tag override (defaults to [title]).
  final seoTitle = CvField<String>('seoTitle');

  /// Meta description override (defaults to [summary]).
  final seoDescription = CvField<String>('seoDescription');

  /// Canonical url override (defaults to the page url on the site).
  final canonicalUrl = CvField<String>('canonicalUrl');

  /// True to ask robots not to index the page.
  final noIndex = CvField<bool>('noIndex');

  /// Position in lists (menus, index).
  final order = CvField<int>('order');

  /// Language code (`fr`, `en`), defaults to the site language.
  final lang = CvField<String>('lang');

  /// Free extra data handed to the templates.
  final data = CvField<Map>('data');

  /// Creation time.
  final created = CvField<SdbTimestamp>('created');

  /// Last update time.
  final updated = CvField<SdbTimestamp>('updated');

  @override
  CvFields get fields => [
    slug,
    title,
    summary,
    body,
    bodyFormat,
    heroImage,
    images,
    itemKind,
    itemId,
    tags,
    published,
    publishedAt,
    seoTitle,
    seoDescription,
    canonicalUrl,
    noIndex,
    order,
    lang,
    data,
    created,
    updated,
  ];
}

/// Page helpers.
extension SdbCmsPageExt on SdbCmsPage {
  /// True when the page is served.
  bool get isPublished => published.v ?? false;

  /// True when the body is markdown (the default).
  bool get isMarkdown =>
      (bodyFormat.v ?? cmsPageBodyFormatMarkdown) == cmsPageBodyFormatMarkdown;

  /// The title tag text.
  String get displayTitle => seoTitle.v ?? title.v ?? slug.v ?? '';

  /// The item kind, [cmsItemKindPage] when unset.
  String get kind => itemKind.v ?? cmsItemKindPage;

  /// All the images, hero first.
  List<CvCmsImage> get allImages => [?heroImage.v, ...?images.v];
}

/// Page model instance for field name access.
final sdbCmsPageModel = SdbCmsPage();

/// Page store.
final cmsPageStore = scvStringStoreFactory.store<SdbCmsPage>('cms_page');

/// Slug index (not unique at the schema level, [CmsPageSdb] enforces it).
final cmsPageSlugIndex = cmsPageStore.index<String>('slug');

/// Page store schema, to add to the content database schema.
final cmsPageStoreSchema = cmsPageStore.schema(
  indexes: [cmsPageSlugIndex.schema(keyPath: sdbCmsPageModel.slug.name)],
);

var _cmsBuildersInitialized = false;

/// Register the cms model builders.
void initFestenaoCmsBuilders() {
  if (_cmsBuildersInitialized) {
    return;
  }
  _cmsBuildersInitialized = true;
  cvAddConstructors([SdbCmsPage.new, CvCmsImage.new]);
}

const _accentMap = <String, String>{
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'æ': 'ae',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'œ': 'oe',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ß': 'ss',
};

/// Make a url slug out of [text]: lower case ascii letters, digits and dashes.
///
/// Accents are stripped (`Café` gives `cafe`), anything else becomes a dash,
/// dashes are collapsed and trimmed, and the result is capped to
/// [cmsSlugMaxLength]. Returns [fallback] (defaults to `page`) when nothing
/// usable remains.
String cmsSlugify(String text, {String fallback = 'page'}) {
  var sb = StringBuffer();
  var lastDash = true;
  for (var rune in text.toLowerCase().runes) {
    var char = String.fromCharCode(rune);
    char = _accentMap[char] ?? char;
    for (var c in char.codeUnits) {
      var isAlnum = (c >= 0x30 && c <= 0x39) || (c >= 0x61 && c <= 0x7a);
      if (isAlnum) {
        sb.writeCharCode(c);
        lastDash = false;
      } else if (!lastDash) {
        sb.write('-');
        lastDash = true;
      }
    }
  }
  var slug = sb.toString();
  if (slug.endsWith('-')) {
    slug = slug.substring(0, slug.length - 1);
  }
  if (slug.length > cmsSlugMaxLength) {
    slug = slug.substring(0, cmsSlugMaxLength);
    var lastDashIndex = slug.lastIndexOf('-');
    if (lastDashIndex > cmsSlugMaxLength ~/ 2) {
      slug = slug.substring(0, lastDashIndex);
    }
  }
  return slug.isEmpty ? fallback : slug;
}

/// Typed access to the pages of a content database.
///
/// Works on any [SdbDatabase] whose schema includes [cmsPageStoreSchema]: a
/// synced project/calendar database, or a plain local one.
class CmsPageSdb {
  /// The database.
  final SdbDatabase db;

  /// Typed access to the pages of [db].
  CmsPageSdb({required this.db}) {
    initFestenaoCmsBuilders();
  }

  List<SdbCmsPage> _sorted(List<SdbCmsPage> list) => list..sort(_compare);

  static int _compare(SdbCmsPage a, SdbCmsPage b) {
    var cmp = (a.order.v ?? 0).compareTo(b.order.v ?? 0);
    if (cmp != 0) {
      return cmp;
    }
    return (a.title.v ?? '').compareTo(b.title.v ?? '');
  }

  List<SdbCmsPage> _filter(
    List<SdbCmsPage> list, {
    required bool publishedOnly,
  }) => publishedOnly ? list.where((page) => page.isPublished).toList() : list;

  /// Every page (or only the published ones), by order then title.
  Stream<List<SdbCmsPage>> onPages({bool publishedOnly = false}) => cmsPageStore
      .onRecords(db)
      .map((list) => _sorted(_filter(list, publishedOnly: publishedOnly)));

  /// Every page (or only the published ones), by order then title.
  Future<List<SdbCmsPage>> getPages({bool publishedOnly = false}) async =>
      _sorted(
        _filter(
          await cmsPageStore.findRecords(db),
          publishedOnly: publishedOnly,
        ),
      );

  /// The pages presenting an item.
  Future<List<SdbCmsPage>> getPagesForItem({
    required String itemKind,
    required String itemId,
  }) async => _sorted(
    await cmsPageStore.findRecords(
      db,
      filter: SdbFilter.and([
        SdbFilter.equals(sdbCmsPageModel.itemKind.name, itemKind),
        SdbFilter.equals(sdbCmsPageModel.itemId.name, itemId),
      ]),
    ),
  );

  /// One page.
  Stream<SdbCmsPage?> onPage(String id) => cmsPageStore.record(id).onRecord(db);

  /// One page, one shot.
  Future<SdbCmsPage?> getPage(String id) => cmsPageStore.record(id).get(db);

  /// The page of a slug, null when none.
  Future<SdbCmsPage?> getPageBySlug(String slug) => txnGetPageBySlug(db, slug);

  /// The page of a slug within [client], null when none.
  Future<SdbCmsPage?> txnGetPageBySlug(SdbClient client, String slug) async {
    var indexRecord = await cmsPageSlugIndex.record(slug).get(client);
    return indexRecord?.record;
  }

  /// A slug derived from [base] that no other page (than [excludePageId])
  /// uses: `base`, then `base-2`, `base-3`...
  Future<String> txnUniqueSlug(
    SdbClient client,
    String base, {
    String? excludePageId,
  }) async {
    var slug = cmsSlugify(base);
    var candidate = slug;
    var index = 1;
    while (true) {
      var existing = await txnGetPageBySlug(client, candidate);
      if (existing == null || existing.id == excludePageId) {
        return candidate;
      }
      index++;
      candidate = '$slug-$index';
    }
  }

  /// Add a page.
  ///
  /// The slug is derived from the title when missing and made unique either
  /// way; the timestamps are set.
  Future<SdbCmsPage> addPage(SdbCmsPage page) async {
    return await cmsPageStore.inTransaction(db, SdbTransactionMode.readWrite, (
      txn,
    ) async {
      var now = SdbTimestamp.now();
      page.slug.v = await txnUniqueSlug(txn, page.slug.v ?? page.title.v ?? '');
      page.created.v ??= now;
      page.updated.v = now;
      if (page.isPublished) {
        page.publishedAt.v ??= now;
      }
      return await cmsPageStore.add(txn, page);
    });
  }

  /// Update a page in place: [update] modifies the current record.
  ///
  /// A changed slug is made unique, the update timestamp is set. No-op when
  /// the page does not exist.
  Future<SdbCmsPage?> updatePage(
    String id,
    void Function(SdbCmsPage page) update,
  ) async {
    return await cmsPageStore.inTransaction(db, SdbTransactionMode.readWrite, (
      txn,
    ) async {
      var existing = await cmsPageStore.record(id).get(txn);
      if (existing == null) {
        return null;
      }
      var previousSlug = existing.slug.v;
      update(existing);
      var slug = existing.slug.v;
      if (slug == null || slug.isEmpty) {
        slug = existing.title.v ?? '';
      }
      if (slug != previousSlug) {
        existing.slug.v = await txnUniqueSlug(txn, slug, excludePageId: id);
      }
      var now = SdbTimestamp.now();
      existing.updated.v = now;
      if (existing.isPublished) {
        existing.publishedAt.v ??= now;
      }
      await cmsPageStore.record(id).put(txn, existing);
      return existing;
    });
  }

  /// Publish or unpublish a page.
  Future<void> setPublished(String id, bool published) async {
    await updatePage(id, (page) => page.published.v = published);
  }

  /// Delete a page.
  Future<void> deletePage(String id) => cmsPageStore.record(id).delete(db);
}
