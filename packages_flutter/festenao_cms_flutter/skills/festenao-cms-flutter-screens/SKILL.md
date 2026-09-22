---
name: festenao-cms-flutter-screens
description: >-
  Use when adding the festenao mini CMS editor to a Flutter app with
  festenao_cms_flutter: cmsPageSdbScope / cmsPageSdbProvider, CmsPagesScreen
  (list, publish toggle, create), CmsPageEditScreen (markdown or html body
  with live preview, order, item link via CmsLinkableItem, tags, SEO,
  publish), CmsPagePreviewScreen, CmsPageView, CmsPageBodyView,
  CmsSiteBrowserScreen (the generated html site navigated like a web site:
  rendered / html source / SEO head, drafts toggle, over a CmsSiteHandler),
  CmsSiteBrowserController, and on the web CmsSiteWebViewScreen /
  cmsSiteOpenInNewTab (the browser's own rendering in a sandboxed iframe),
  CmsRenderedHtmlView, CmsHtmlDocument; wiring them with Navigator or a
  router (onOpenPage, onCreatePage, onBrowseSite, onEditPage, onViewHtml,
  onSaved), opening a database with cmsPageStoreSchema and testing them on
  the vm and in chrome.
---

# Festenao CMS editor screens (festenao_cms_flutter)

`festenao_cms_flutter` is the editor side of the festenao mini CMS
(`festenao_common/festenao_cms.dart`): WordPress like pages an admin writes
in the app, stored in the content database next to what they present, and
rendered to static SEO friendly html by a cloud function (`CmsRenderer`,
`CmsSiteHandler`). Material screens over riverpod: list, edit with live
preview, preview, and a site browser showing the html the function serves.

## Guidelines

* Dependency (git, not on pub.dev); the host app needs `flutter_riverpod`
  (a `ProviderScope` at its root):
  ```yaml
  dependencies:
    festenao_cms_flutter:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_cms_flutter
  ```
* Import `package:festenao_cms_flutter/festenao_cms_flutter.dart`. It
  re-exports `festenao_common/festenao_cms.dart`: the model `SdbCmsPage`
  (`title`, `slug`, `summary`, `body`, `bodyFormat`, `heroImage`
  (`CvCmsImage`), `images`, `itemKind`, `itemId`, `tags`, `published`,
  `seoTitle`, `seoDescription`, `noIndex`, `order`, `lang`... with
  `isPublished`, `isMarkdown`, `kind`, `displayTitle`), `CmsPageSdb`,
  `cmsPageStore`, `cmsPageStoreSchema`, `cmsSlugify`, the kinds
  `cmsItemKindPage` / `Location` / `Activity` / `Event` / `Offer`
  (`cmsItemKinds`), `cmsPageBodyFormatMarkdown` / `Html`, `CmsRenderer`,
  `CmsSite`, `CmsSiteHandler` / `CmsResponse`, `CmsPageRenderOptions`,
  `CmsStructuredData`, and the sdb api (`SdbDatabase`, `SdbFactory`, `SdbOpenDatabaseOptions`,
  `SdbDatabaseSchema`, `newSdbFactoryMemory`).
* The database: add `cmsPageStoreSchema` to the `SdbDatabaseSchema(stores:
  [...])` of the content database (a synced project or calendar database, or
  a plain local one) and wrap it in `CmsPageSdb(db:)`: `onPages(publishedOnly:)`,
  `getPages`, `onPage(id)`, `getPage`, `getPageBySlug`,
  `getPagesForItem(itemKind:, itemId:)`, `addPage(page)` (slug derived from
  the title and made unique, timestamps set), `updatePage(id, (page) {...})`,
  `setPublished(id, bool)`, `deletePage(id)`.
* Scope: the screens read `cmsPageSdbProvider`, which throws `StateError`
  outside a `cmsPageSdbScope(sdb:, child:)`. A pushed route is a new
  subtree under the `Navigator`, outside that scope: wrap the pushed screen
  again (the default navigation of `CmsPagesScreen` does), or with a
  router wrap each route builder, or put the scope above the router when
  the app has a single content database.
* `CmsPagesScreen(title:, onOpenPage:, onCreatePage:, onBrowseSite:,
  canEdit:)`: the list by order then title, a publish `Switch` per page and
  a create FAB (`canEdit: true`), `Navigator` pushes of `CmsPageEditScreen`
  unless the callbacks are given (a router host gives both); `onBrowseSite`
  adds a "View the site" app bar button.
* `CmsPageEditScreen(pageId:, initialItem:, linkableItems:, readOnly:,
  onSaved:)`: `pageId` null creates; the slug follows the title until
  edited; the body format (markdown, or html for trusted content) is kept
  as loaded, and `order` sets the position in lists and in the site index;
  the Preview tab renders the draft live; save writes through
  `cmsPageSdbProvider` then `onSaved(context, page)` or pops with the page;
  delete (existing page) asks confirmation then pops. `CmsLinkableItem(kind:,
  id:, name:)` lists the host content (events, locations...) the "Presents"
  picker offers, filtered by the chosen kind; an empty list shows a free
  text id field. `initialItem` pre-fills kind, id and title: the "write a
  page about this event" entry.
* `CmsPagePreviewScreen(pageId:, onEditPage:, onViewHtml:)` shows the page
  as a reader sees it (edit and "view the generated html" buttons when the
  callbacks are given); `CmsPageView(page:)` is the same without scaffold
  (used by the editor preview); `CmsPageBodyView(page:, shrinkWrap:)`
  renders markdown with `festenao_markdown` and an html body with
  `CmsRenderedHtmlView`.
* `CmsSiteBrowserScreen(renderer:, initialPath:, includeDrafts:,
  pageOptions:, initialViewMode:, monospaceFontFamily:, onEditPage:)`: a
  mini browser on the site the pages render to. It renders every url on the
  fly through a `CmsSiteHandler(pages:, renderer:, includeDrafts:,
  pageOptions:)` on the scoped `CmsPageSdb`, so it shows exactly what the
  cloud function serves: `''` the index, `page/<slug>` a page
  (`CmsSiteBrowserScreen.pagePath(renderer, page)`), `sitemap.xml`,
  `robots.txt`, a 404 for anything else (and for a draft unless the
  "Drafts" chip is on; a served draft is rendered no index). Address bar
  (url or path), back / forward / home / reload, a "Go to" menu (index,
  sitemap, robots, copy url, copy source), a status chip (`200 ·
  text/html`), and `CmsSiteViewMode.rendered` (the body as widgets, links
  within the site followed, others only shown in a snack bar), `.source`
  (the html as served) or `.seo` (title and description with their length,
  canonical, language, indexing, open graph / twitter metas, pretty printed
  JSON-LD). A change to the pages re-renders the current document.
  `pageOptions` (a `CmsPageRenderOptionsBuilder`) gives the details and
  structured data of the pages presenting an item, as the function would.
* `CmsSiteBrowserController(pages:, renderer:, pageOptions:,
  includeDrafts:, initialPath:)` is the browsing session behind both
  browsers (a `ChangeNotifier`): `path`, `url`, `urlOf(path)`,
  `pathOfUrl(url)` (null off the site), `response`, `document`, `page`,
  `error`, `isLoading`, `includeDrafts` (settable), `go(path)`, `back()`,
  `forward()`, `reload()`, `fetch(path)` (renders without navigating); it
  re-renders when the pages change. `CmsSiteBrowserScreen` owns one; dispose
  one you create.
* Web only (`cmsHtmlFrameSupported`): `CmsSiteWebViewScreen(controller:,
  monospaceFontFamily:, onEditPage:)` draws the current document with the
  browser itself, css included, in `CmsHtmlFrame(html:, onLink:)`, a
  sandboxed iframe (`allow-scripts` only: the page runs in an opaque origin,
  out of reach of the app; a script added to it posts the taps on links,
  followed within the site, the others opened with `cmsOpenExternalUrl`).
  `CmsSiteBrowserScreen` shows a "Browser rendering" button pushing it on
  its own controller (shared history) and an "Open in a new tab" menu entry:
  `cmsSiteOpenInNewTab(controller, path:)` (false when blocked: call it from
  a tap). `cmsHtmlForBrowser(response, url)` prepares a response for the
  browser (a `<base>`, text documents wrapped). Elsewhere the frame is a
  placeholder saying so.
* `CmsRenderedHtmlView(bodyHtml:, baseUrl:, onLink:, monospaceFontFamily:)`
  renders html with `flutter_widget_from_html_core` (no webview: linux and
  web alike). Flutter runs no css, so the classes of the default templates
  (`site-header`, `cards`, `details`, `tag`, `summary`, `site-footer`,
  tables, blockquotes) are drawn with the app theme; a custom template
  renders as plain html. `CmsHtmlDocument.parse(html)` reads the head
  (`title`, `description`, `canonicalUrl`, `robots`, `isNoIndex`,
  `socialMetas`, `jsonLd`) and the `bodyHtml`; `cmsPlainTextToLinkedHtml`
  shows a text or xml document with its urls as links.
* Access: `canEdit: false` (list) and `readOnly: true` (edit) for members
  without write access; buttons and switches disappear, the form stays
  readable.
* Widget tests: open a memory database under `tester.runAsync` (sdb
  transactions need the real event loop), pump with a loop mixing a
  `runAsync` delay and `pump`, and `pumpAndSettle` after a route transition
  before tapping. A transaction started by a tap (save) runs in the test
  zone: wait for it with that pump loop, never with a lone `runAsync`
  (which deadlocks on the transaction lock). Rendered html is rich text:
  `find.text(text, findRichText: true)`, and
  `tester.tapOnText(find.textRange.ofSubstring('link text'))` to follow a
  link. The browser rendering is tested in a browser (`@TestOn('browser')`,
  `flutter test --platform chrome test/browser`); platform views are not
  attached to the page in widget tests, so the iframe setup is tested on an
  iframe added to the page by hand, its links clicked by a script of the
  page itself (the test cannot reach into an opaque origin).

## Examples

### Open a database with the page store and show the list

```dart
import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<CmsPageSdb> openCmsDb(SdbFactory factory) async {
  var db = await factory.openDatabase(
    'content.db',
    options: SdbOpenDatabaseOptions(
      version: 1,
      // Your own stores go next to it.
      schema: SdbDatabaseSchema(stores: [cmsPageStoreSchema]),
    ),
  );
  return CmsPageSdb(db: db);
}

class CmsApp extends StatelessWidget {
  final CmsPageSdb sdb;

  const CmsApp({super.key, required this.sdb});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        home: cmsPageSdbScope(
          sdb: sdb,
          child: const CmsPagesScreen(title: 'Pages'),
        ),
      ),
    );
  }
}
```

### A host owning the navigation (re-scoping each pushed screen)

```dart
import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';
import 'package:flutter/material.dart';

class CmsHost extends StatelessWidget {
  final CmsPageSdb sdb;
  final bool canEdit;

  const CmsHost({super.key, required this.sdb, required this.canEdit});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        // A new route is outside the scope: wrap again.
        builder: (_) => cmsPageSdbScope(sdb: sdb, child: screen),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return cmsPageSdbScope(
      sdb: sdb,
      child: CmsPagesScreen(
        canEdit: canEdit,
        onOpenPage: (context, page) => _push(
          context,
          CmsPagePreviewScreen(
            pageId: page.id,
            onEditPage: canEdit
                ? (context, pageId) => _push(
                    context,
                    CmsPageEditScreen(pageId: pageId),
                  )
                : null,
          ),
        ),
        onCreatePage: (context) => _push(
          context,
          CmsPageEditScreen(
            pageId: null,
            onSaved: (context, page) => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
```

### Browsing the generated site

```dart
import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';
import 'package:flutter/material.dart';

final siteRenderer = CmsRenderer(
  site: CmsSite(
    name: 'My festival',
    baseUrl: Uri.parse('https://festival.example.com/'),
    language: 'en',
    nav: const [
      CmsNavLink(label: 'Home', url: 'https://festival.example.com/'),
      CmsNavLink(
        label: 'Program',
        url: 'https://festival.example.com/page/program',
      ),
    ],
  ),
);

/// The site, from the index; or [page] as served, a draft included.
Future<void> browseSite(
  BuildContext context,
  CmsPageSdb sdb, {
  SdbCmsPage? page,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => cmsPageSdbScope(
      sdb: sdb,
      child: CmsSiteBrowserScreen(
        renderer: siteRenderer,
        initialPath: page == null
            ? ''
            : CmsSiteBrowserScreen.pagePath(siteRenderer, page),
        includeDrafts: page != null && !page.isPublished,
        initialViewMode: CmsSiteViewMode.rendered,
        // Details and JSON-LD of the pages presenting an item.
        pageOptions: (page) => page.kind == cmsItemKindEvent
            ? const CmsPageRenderOptions(
                ogType: 'event',
                details: [CmsPageDetail(label: 'Date', value: '2027-07-09')],
              )
            : const CmsPageRenderOptions(),
      ),
    ),
  ),
);
```

### The browser rendering, on its own (web)

```dart
import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';
import 'package:flutter/material.dart';

/// The site as the browser draws it, in a session closed with the screen.
Future<void> browseInBrowser(
  BuildContext context,
  CmsPageSdb sdb,
  CmsRenderer renderer,
) async {
  if (!cmsHtmlFrameSupported) {
    return;
  }
  var controller = CmsSiteBrowserController(pages: sdb, renderer: renderer);
  try {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CmsSiteWebViewScreen(controller: controller),
      ),
    );
  } finally {
    controller.dispose();
  }
}
```

### "Write a page about this event"

```dart
import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';
import 'package:flutter/material.dart';

/// The events of the content database, offered in the "Presents" picker.
List<CmsLinkableItem> eventItems(Map<String, String> eventNamesById) => [
  for (var entry in eventNamesById.entries)
    CmsLinkableItem(
      kind: cmsItemKindEvent,
      id: entry.key,
      name: entry.value,
    ),
];

Widget newEventPageScreen(
  CmsPageSdb sdb, {
  required String eventId,
  required String eventName,
  required List<CmsLinkableItem> events,
}) => cmsPageSdbScope(
  sdb: sdb,
  child: CmsPageEditScreen(
    pageId: null,
    initialItem: CmsLinkableItem(
      kind: cmsItemKindEvent,
      id: eventId,
      name: eventName,
    ),
    linkableItems: events,
  ),
);
```

### Pages created in code

```dart
import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';

Future<void> seedPages(CmsPageSdb sdb) async {
  var about = await sdb.addPage(
    SdbCmsPage()
      ..title.v = 'About us'
      ..summary.v = 'Who we are'
      ..body.v = '# About\n\nWe organize festivals.'
      ..published.v = true,
  );
  print(about.slug.v); // about-us
  await sdb.updatePage(about.id, (page) => page.tags.v = ['info']);
  var published = await sdb.getPages(publishedOnly: true);
  print(published.length);
}
```

### Widget test

```dart
import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pump until [finder] matches: a real tick for the database, then a frame.
Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (findsWidgets.matches(finder, {})) {
      return;
    }
  }
  fail('$finder not found');
}

void main() {
  testWidgets('create a page', (tester) async {
    late CmsPageSdb sdb;
    await tester.runAsync(() async {
      var db = await newSdbFactoryMemory().openDatabase(
        'cms.db',
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(stores: [cmsPageStoreSchema]),
        ),
      );
      sdb = CmsPageSdb(db: db);
      addTearDown(() => db.close());
    });

    await tester.pumpWidget(
      MaterialApp(
        home: cmsPageSdbScope(
          sdb: sdb,
          child: const CmsPageEditScreen(pageId: null),
        ),
      ),
    );
    await pumpUntil(tester, find.text('New page'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Le Café');
    await tester.pump();
    expect(find.text('le-cafe'), findsOneWidget); // derived slug
    await tester.tap(find.byIcon(Icons.save));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.runAsync(() async {
      expect((await sdb.getPages()).single.slug.v, 'le-cafe');
    });
  });
}
```

## Common mistakes

* Pushing `CmsPageEditScreen` without re-wrapping it in `cmsPageSdbScope`
  (`StateError: cmsPageSdbProvider is only readable below a cmsPageSdbScope`).
* Opening the content database without `cmsPageStoreSchema` in its schema.
* Setting `slug` by hand to something not unique: let `addPage` /
  `updatePage` derive and de-duplicate it.
* Expecting the rendered view of `CmsSiteBrowserScreen` to apply the site
  css: it approximates the default templates with the app theme; the Html
  view is the exact output, and on the web the browser rendering draws it.
* Adding `allow-same-origin` to the frame sandbox: with `allow-scripts` it
  would let the page script the app; without scripts Chrome skips even the
  app's listeners on the frame document, so the links could not be caught.
* Giving the site a base url and nav links that do not match
  (`CmsSite.baseUrl` vs `CmsNavLink.url`): the browser only follows links
  under the base url, the others are reported as not on the site.
