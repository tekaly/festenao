# Festenao explorers & cms demo

Everything the explorers of `festenao_common_flutter` reach, and the cms of
`festenao_cms_flutter` on a small festival site, on content built at startup
**in memory**: nothing is written to the disk, and modifications are
lost on restart — which is what makes it safe to edit anything in it.

```sh
flutter run -d linux      # or -d chrome
```

The platform runners are not in the repository — `linux/` and `web/` are
gitignored here, as they are for the other examples — so a fresh clone
regenerates them first:

```sh
flutter create --project-name festenao_dashboard_app_demo \
    --platforms=linux,web --org com.tekaly .
```

## What the menu offers

| Entry | On |
|---|---|
| Firestore explorer | an in-memory firestore: three collections, a sub collection, and a document holding every firestore type |
| File system explorer | an in-memory `fs_shim` file system: a json, a yaml, a text and a binary document, a sub directory, and the two databases below |
| Sdb explorer | the sdb databases **found** in that file system, not a path typed by hand |
| Sembast explorer | the sembast ones, told apart from the sdb ones by what each file holds |
| CMS pages | the pages of the festival site: publish toggles, create, preview, edit (markdown or html body, item link, SEO fields) |
| CMS site | the html the pages render to, navigated like the web site — see below |
| CMS site, browser rendering | on the web only: the same html drawn by the browser itself, css included |
| CMS database | the raw `cms_page` records, in the object explorer |
| Every database | both kinds together |
| Edit an object in memory | the editor on a value, answering what it became |

Everything is read write, `Sdb explorer` and `Sembast explorer` going through
`listFileSystemDatabases`, which walks the tree and opens each candidate to
tell what it is — so the list is what can really be browsed rather than what is
merely named `.db`.

## The CMS site

`CMS site` (or the globe button of `CMS pages`, or of a page preview) opens
`CmsSiteBrowserScreen` on `https://festival.example.com/`. Nothing is served
there: each url is rendered on the fly from the pages in memory by a
`CmsSiteHandler`, exactly what the cloud function would answer (see
`cmsdemo` in `festenao_dartff`) — the index, the pages,
`sitemap.xml`, `robots.txt`, a 404 for the rest. Links within the site are
followed, the others only shown; back, forward and the address bar work as in
a browser, and an edit in `CMS pages` shows at once.

Three view modes:

- **Rendered** — the body as widgets, the default templates drawn with the app
  theme (Flutter runs no css).
- **Html** — the document as served.
- **SEO** — title and description with their length, canonical url, language,
  indexing, open graph and twitter tags, and the JSON-LD.

The seeded pages cover every kind: free pages (`about`, a `program` table,
`practical`), an event with its details and `Event` structured data, a
location, an activity, an offer, an html page (`partners`), a no index one
(`legal`, out of the sitemap) and a draft (`line-up-2027`, a 404 until the
**Drafts** chip serves it, then rendered no index).

### On the web: the browser's own rendering

```sh
flutter run -d chrome
```

Flutter runs no css, so the Rendered view above approximates the templates.
On the web the browser can draw the real thing: **CMS site, browser
rendering** in the menu, the globe-arrow button of **CMS site** (the same
session: history and drafts toggle shared), or **Open in a new tab**. The
page sits in an iframe sandboxed with `allow-scripts` only — an opaque origin
that reaches nothing of the app — and its links are followed within the site,
the others opening a tab of their own.

## The CMS site served over http

The same pages, served by the dart http functions a deployment runs
(`festenao_dartff`, on its admin sdk http runner), from a standalone local
server:

```sh
dart run bin/server.dart          # http://localhost:8040/cmsdemo/
dart run bin/server_ff_app.dart   # the festenao functions too, see below
```

- `bin/server.dart` — the demo site alone, as the function `cmsdemo` (what
  the deployed `cmsdemo` serves at `https://<hosting>/cmsdemo/`).
- `bin/server_ff_app.dart` — a dev `FfApp` (`commanddartv2dev`,
  `callcommanddartv2dev`, `ampdev`, `cmsdev`) on in memory firebase
  services, the demo pages synced into a demo project
  (`fillDemoCmsProject`) whose site `cmsdev` serves at
  `http://localhost:8040/cmsdev/demo_festival/content/` — what the deployed
  `cmsdev` serves at `https://<hosting>/cms/<projectId>/<dataId>/` — plus
  the demo site as `cmsdemo`.

Both take another port as first argument, keep everything in memory, and are
built on the shared helpers of `festenao_dartff`: `declareRunner`,
`declareCmsSiteRunner` (registration) and `serveFestenaoFunctionsHttp` (the
server). The links of a site follow the url it is reached at.
`test/demo_server_test.dart` serves both in memory and crawls them.

## What it is built from

- `lib/src/demo_data.dart` builds it all, reusing the shared demo content
  (`demoJsonContent`, `fillDemoSembastDatabase`, `demoSdbDatabaseSchema`,
  `fillDemoFirestore`…), so the demo and the `+` menu of the file system
  explorer show the same thing.
- `festenao_demo` (`packages/festenao_common/example/demo`) holds the cms
  content, free of Flutter and shared with the `cmsdemo` cloud function: the
  site (`demoCmsSite`), its pages (`demoCmsPages`), the details and
  structured data of the items they present (`demoCmsPageOptions`), in an
  in memory sdb (`DemoCms`); `lib/src/demo_cms.dart` adds the items the
  page editor offers.
- `lib/src/demo_server.dart` holds the two servers of `bin/`.
- `lib/src/demo_cms_navigation.dart` wires the cms screens together.
- `lib/src/demo_home_page.dart` is the menu.

See `packages/festenao_common/doc/` for what each explorer does.

## Screenshots

```sh
flutter test tool/screenshot_test.dart
```

Writes one png per screen to `.local/screenshots_1` (gitignored). It renders
through the flutter test pipeline rather than a running window: the widgets and
the rendering are the real ones, nothing needs a display, and each screen is
reached on purpose rather than by driving a window. The text and icon fonts are
loaded from the flutter sdk, without which the test harness draws every glyph
as a box.
