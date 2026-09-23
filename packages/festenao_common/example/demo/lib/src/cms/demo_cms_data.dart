/// The cms content of the demo, free of Flutter: a small summer festival
/// site, shown by the dashboard demo app, served by its local servers and by
/// the `cmsdemo` cloud function.
library;

import 'package:festenao_common/festenao_cms.dart';

/// The default base url of the demo site: nothing is served there, the site
/// browser of the dashboard demo renders every url of it from the pages in
/// memory.
final demoCmsBaseUrl = Uri.parse('https://festival.example.com/');

/// The name of the demo site.
const demoCmsSiteName = 'Festenao summer festival';

/// The demo site, a small summer festival, at [baseUrl] ([demoCmsBaseUrl]
/// by default; the url of the function serving it otherwise).
CmsSite demoCmsSite({Uri? baseUrl}) {
  var site = CmsSite(
    name: demoCmsSiteName,
    baseUrl: baseUrl ?? demoCmsBaseUrl,
    language: 'en',
    description:
        'Three days of music, workshops and night markets by the lake.',
  );
  return CmsSite(
    name: site.name,
    baseUrl: site.baseUrl,
    language: site.language,
    description: site.description,
    nav: [
      CmsNavLink(label: 'Home', url: site.url('')),
      CmsNavLink(label: 'About', url: site.pageUrl('about')),
      CmsNavLink(label: 'Program', url: site.pageUrl('program')),
      CmsNavLink(label: 'Tickets', url: site.pageUrl('weekend-pass')),
      CmsNavLink(label: 'Practical', url: site.pageUrl('practical')),
    ],
  );
}

/// The pages of the demo, one of each kind and format, a no index one and a
/// draft.
List<SdbCmsPage> demoCmsPages() => [
  SdbCmsPage()
    ..slug.v = 'about'
    ..title.v = 'About the festival'
    ..summary.v =
        'Three days of music, workshops and night markets by the lake.'
    ..body.v = '''
The **Festenao summer festival** is run by volunteers since 2012, on the
shore of the lake, from Friday evening to Sunday night.

## What to expect

- Concerts on two stages, from folk to electro
- [Night workshops](night-workshops) for all ages
- A night market with local food and crafts

See the [program](program), then grab a [weekend pass](weekend-pass).
'''
    ..tags.v = ['festival', 'music']
    ..order.v = 1
    ..published.v = true,
  SdbCmsPage()
    ..slug.v = 'program'
    ..title.v = 'Program'
    ..summary.v = 'Who plays when, and where.'
    ..body.v = '''
| Day | Time | What | Where |
|---|---|---|---|
| Friday | 20:00 | [Opening night concert](opening-night-concert) | [Main stage](main-stage) |
| Saturday | 14:00 | [Night workshops](night-workshops) start | Workshop tent |
| Sunday | 18:00 | Closing parade | Along the lake |

> The program may change with the weather: check this page on the day.
'''
    ..order.v = 2
    ..published.v = true,
  SdbCmsPage()
    ..slug.v = 'opening-night-concert'
    ..title.v = 'Opening night concert'
    ..summary.v = 'The festival opens with the lake orchestra.'
    ..body.v = '''
The lake orchestra and its guests open the festival on the main stage.

Doors open at **19:00**, the concert starts at 20:00. Included in the
[weekend pass](weekend-pass).
'''
    ..itemKind.v = cmsItemKindEvent
    ..itemId.v = 'opening-night'
    ..tags.v = ['concert']
    ..order.v = 10
    ..published.v = true,
  SdbCmsPage()
    ..slug.v = 'main-stage'
    ..title.v = 'The main stage'
    ..summary.v = 'Open air, facing the lake, 2000 standing places.'
    ..body.v = '''
The main stage stands on the meadow by the lake, a ten minutes walk from the
station. Seats are available for people with reduced mobility, ask the
volunteers at the entrance.
'''
    ..itemKind.v = cmsItemKindLocation
    ..itemId.v = 'main-stage'
    ..order.v = 20
    ..published.v = true,
  SdbCmsPage()
    ..slug.v = 'night-workshops'
    ..title.v = 'Night workshops'
    ..summary.v = 'Drums, dance and lanterns, from dusk to midnight.'
    ..body.v = '''
Every evening in the workshop tent: a drum circle, a dance class and a lantern
workshop for the children. No booking needed, come as you are.
'''
    ..itemKind.v = cmsItemKindActivity
    ..itemId.v = 'night-workshops'
    ..tags.v = ['workshop', 'family']
    ..order.v = 30
    ..published.v = true,
  SdbCmsPage()
    ..slug.v = 'weekend-pass'
    ..title.v = 'Weekend pass'
    ..summary.v = 'Every concert and workshop of the three days.'
    ..body.v = '''
The weekend pass opens every stage and every workshop from Friday to Sunday.
Children under 12 enter for free.
'''
    ..itemKind.v = cmsItemKindOffer
    ..itemId.v = 'weekend-pass'
    ..order.v = 40
    ..published.v = true,
  SdbCmsPage()
    ..slug.v = 'practical'
    ..title.v = 'Practical information'
    ..summary.v = 'Getting there, sleeping there, and what to bring.'
    ..body.v = '''
## Getting there

By train to the lake station, then a ten minutes walk. The
[map](https://www.openstreetmap.org/) shows the way (an external link: the
site browser shows it but does not leave the site).

## What to bring

1. Your pass, printed or on your phone
2. A reusable cup
3. Something warm for the night
'''
    ..order.v = 50
    ..published.v = true,
  SdbCmsPage()
    ..slug.v = 'partners'
    ..title.v = 'Our partners'
    ..summary.v = 'The ones who make it possible.'
    ..bodyFormat.v = cmsPageBodyFormatHtml
    ..body.v = '''
<p>This page is written in <b>html</b> rather than markdown, which only the
entity admins can do.</p>
<ul>
<li><a href="https://example.com/brewery">The lake brewery</a></li>
<li><a href="https://example.com/radio">Radio Festenao</a></li>
</ul>
'''
    ..order.v = 60
    ..published.v = true,
  SdbCmsPage()
    ..slug.v = 'legal'
    ..title.v = 'Legal notice'
    ..summary.v = 'Who publishes this site.'
    ..body.v = 'Published by the Festenao association, for the demo only.'
    ..noIndex.v = true
    ..order.v = 90
    ..published.v = true,
  SdbCmsPage()
    ..slug.v = 'line-up-2027'
    ..title.v = 'Line-up 2027'
    ..summary.v = 'Not announced yet: a draft.'
    ..body.v = 'The first names will be announced in **January**.'
    ..order.v = 100
    ..published.v = false,
];

/// The details and structured data of the pages presenting an item, as an
/// app derives them from its own content (here, written by hand).
CmsPageRenderOptionsBuilder demoCmsPageOptions(CmsRenderer renderer) => (page) {
  var url = renderer.pageUrl(page);
  var description = renderer.description(page);
  var mainStage = CmsStructuredData.place(
    name: 'The main stage',
    address: CmsStructuredData.postalAddress(
      streetAddress: '1 lake meadow',
      locality: 'Annecy',
      country: 'FR',
    ),
    geo: CmsStructuredData.geo(latitude: 45.899, longitude: 6.129),
  );
  return switch ((page.kind, page.itemId.v)) {
    (cmsItemKindEvent, 'opening-night') => CmsPageRenderOptions(
      ogType: 'event',
      details: const [
        CmsPageDetail(label: 'Date', value: '2027-07-09 20:00'),
        CmsPageDetail(label: 'Location', value: 'The main stage'),
        CmsPageDetail(label: 'Price', value: 'Weekend pass'),
      ],
      structuredData: CmsStructuredData.event(
        name: page.title.v ?? '',
        startDate: '2027-07-09T20:00:00+02:00',
        endDate: '2027-07-09T23:30:00+02:00',
        description: description,
        url: url,
        location: mainStage,
        performer: 'The lake orchestra',
        organizer: renderer.site.name,
        offers: [
          CmsStructuredData.offer(
            price: 60,
            currency: 'EUR',
            url: renderer.site.pageUrl('weekend-pass'),
          ),
        ],
      ),
    ),
    (cmsItemKindLocation, 'main-stage') => CmsPageRenderOptions(
      ogType: 'place',
      details: const [
        CmsPageDetail(label: 'Address', value: '1 lake meadow, Annecy'),
        CmsPageDetail(label: 'Capacity', value: '2000'),
      ],
      structuredData: {...mainStage, 'description': description, 'url': url},
    ),
    (cmsItemKindOffer, 'weekend-pass') => CmsPageRenderOptions(
      details: const [
        CmsPageDetail(label: 'Price', value: '60 €'),
        CmsPageDetail(label: 'Children under 12', value: 'Free'),
      ],
      structuredData: CmsStructuredData.product(
        name: page.title.v ?? '',
        description: description,
        url: url,
        offer: CmsStructuredData.offer(
          price: 60,
          currency: 'EUR',
          url: url,
          availability: 'https://schema.org/InStock',
        ),
      ),
    ),
    _ => const CmsPageRenderOptions(),
  };
};

/// The CMS of the demo: its pages in an in memory sdb, and the renderer of
/// the site they make.
class DemoCms {
  /// The content database.
  final SdbDatabase database;

  /// The pages of [database].
  final CmsPageSdb pages;

  /// The renderer of the [demoCmsSite].
  final CmsRenderer renderer;

  /// The details and structured data of the pages presenting an item.
  late final CmsPageRenderOptionsBuilder pageOptions = demoCmsPageOptions(
    renderer,
  );

  /// The cms on [database], its site at [baseUrl] ([demoCmsBaseUrl] by
  /// default).
  DemoCms({required this.database, Uri? baseUrl})
    : pages = CmsPageSdb(db: database),
      renderer = CmsRenderer(site: demoCmsSite(baseUrl: baseUrl));

  /// Opens an in memory database and fills it with [demoCmsPages], the site
  /// at [baseUrl] ([demoCmsBaseUrl] by default).
  static Future<DemoCms> create({Uri? baseUrl}) async {
    initFestenaoCmsBuilders();
    var database = await newSdbFactoryMemory().openDatabase(
      'cms_demo.db',
      options: SdbOpenDatabaseOptions(
        version: 1,
        schema: SdbDatabaseSchema(stores: [cmsPageStoreSchema]),
      ),
    );
    var cms = DemoCms(database: database, baseUrl: baseUrl);
    for (var page in demoCmsPages()) {
      await cms.pages.addPage(page);
    }
    return cms;
  }
}
