# festenao_cms_flutter

The editor side of the festenao mini CMS (`festenao_common/festenao_cms.dart`):
WordPress like pages an admin writes in the app, rendered to static SEO
friendly html by a cloud function (`CmsRenderer`).

- `CmsPagesScreen` — the page list (published toggle, create, open).
- `CmsPageEditScreen` — the page form: title, slug, summary, markdown or html
  body with a live preview, order, item link (location, activity, event,
  offer), tags, SEO fields, publish.
- `CmsPagePreviewScreen` — the page as the reader sees it (markdown or html
  rendered).
- `CmsSiteBrowserScreen` — the html site the pages render to, generated on
  the fly through a `CmsSiteHandler` (what the cloud function serves: index,
  pages, `sitemap.xml`, `robots.txt`, 404) and navigated like a web site:
  address bar, history, links followed within the site, and three view modes
  — rendered, html source, SEO head (title, description, canonical, open
  graph, JSON-LD). A drafts toggle serves the unpublished pages at their url.
- `CmsSiteWebViewScreen` (web) — the same pages drawn by the browser itself,
  css included, in a sandboxed iframe; it shares its history with the site
  browser (a `CmsSiteBrowserController`), which opens it from its app bar.
  `cmsSiteOpenInNewTab` shows them in a new browser tab instead.

The screens read their `CmsPageSdb` from `cmsPageSdbProvider`, a riverpod
provider the host app overrides with `cmsPageSdbScope`:

```dart
cmsPageSdbScope(
  sdb: calendarSdb.pages,   // any CmsPageSdb on a database including cmsPageStoreSchema
  child: const CmsPagesScreen(),
)
```

Navigation is plain `Navigator` pushes by default; a go_router host passes
`onOpenPage`/`onCreatePage` callbacks and wires its own routes, and
`onBrowseSite` (list) / `onViewHtml` (preview) to open the site browser:

```dart
var renderer = CmsRenderer(site: CmsSite(name: 'My site', baseUrl: siteUrl));
cmsPageSdbScope(
  sdb: sdb,
  child: CmsSiteBrowserScreen(
    renderer: renderer,
    initialPath: CmsSiteBrowserScreen.pagePath(renderer, page), // '' for the index
  ),
);
```

The rendered view uses `flutter_widget_from_html_core` (no webview, so it runs
on linux and web alike); Flutter runs no css, so the default templates are
drawn with the app theme and the Html view is the exact output. On the web,
the browser rendering shows the real thing: the iframe is sandboxed with
`allow-scripts` only, so the page runs in an opaque origin and reaches nothing
of the app (no parent access, no storage, no cookies, no navigation of the
app, no popup, no form); a small script added to the page posts the taps on
its links, which the app follows within the site (the others open in a new
tab).

```sh
flutter test                              # the screens (vm)
flutter test --platform chrome test/browser   # the browser rendering
``` The
`festenao_dashboard_base_app/example/demo` app has a seeded site to try it on.
