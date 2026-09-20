---
name: festenao-cms-flutter-screens
description: >-
  Use when adding the festenao mini CMS editor to a Flutter app with
  festenao_cms_flutter: cmsPageSdbScope and cmsPageSdbProvider giving the
  screens their CmsPageSdb, cmsPagesProvider and cmsPageProvider(id),
  CmsPagesScreen (page list, publish toggle, create), CmsPageEditScreen
  (title, slug, summary, markdown body with live preview, item link through
  CmsLinkableItem, tags, SEO fields, publish), CmsPagePreviewScreen,
  CmsPageView and CmsPageBodyView, wiring them with Navigator or a router
  (onOpenPage, onCreatePage, onEditPage, onSaved), opening a database with
  cmsPageStoreSchema (SdbCmsPage, addPage, updatePage, setPublished) and
  widget testing them.
---

# Festenao CMS editor screens (festenao_cms_flutter)

`festenao_cms_flutter` is the editor side of the festenao mini CMS
(`festenao_common/festenao_cms.dart`): WordPress like pages an admin writes
in the app, stored in the content database next to what they present, and
rendered to static SEO friendly html by a cloud function (`CmsRenderer`).
Three material screens over riverpod: list, edit with live preview, preview.

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
  and the sdb api (`SdbDatabase`, `SdbFactory`, `SdbOpenDatabaseOptions`,
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
* `CmsPagesScreen(title:, onOpenPage:, onCreatePage:, canEdit:)`: the
  list by order then title, a publish `Switch` per page and a create FAB
  (`canEdit: true`), `Navigator` pushes of `CmsPageEditScreen` unless the
  callbacks are given (a router host gives both).
* `CmsPageEditScreen(pageId:, initialItem:, linkableItems:, readOnly:,
  onSaved:)`: `pageId` null creates; the slug follows the title until
  edited; the Preview tab renders the draft live; save writes through
  `cmsPageSdbProvider` then `onSaved(context, page)` or pops with the page;
  delete (existing page) asks confirmation then pops. `CmsLinkableItem(kind:,
  id:, name:)` lists the host content (events, locations...) the "Presents"
  picker offers, filtered by the chosen kind; an empty list shows a free
  text id field. `initialItem` pre-fills kind, id and title: the "write a
  page about this event" entry.
* `CmsPagePreviewScreen(pageId:, onEditPage:)` shows the page as a reader
  sees it (edit button when the callback is given); `CmsPageView(page:)` is
  the same without scaffold (used by the editor preview);
  `CmsPageBodyView(page:, shrinkWrap:)` renders markdown with
  `festenao_markdown` and shows raw html bodies as text (only the web
  renderer shows html).
* Access: `canEdit: false` (list) and `readOnly: true` (edit) for members
  without write access; buttons and switches disappear, the form stays
  readable.
* Widget tests: open a memory database under `tester.runAsync` (sdb
  transactions need the real event loop), pump with a loop mixing a
  `runAsync` delay and `pump`, and `pumpAndSettle` after a route transition
  before tapping.

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
* Writing html in the body and expecting the app preview to render it (the
  web renderer does, the app shows the source).
