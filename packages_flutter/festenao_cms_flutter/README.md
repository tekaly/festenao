# festenao_cms_flutter

The editor side of the festenao mini CMS (`festenao_common/festenao_cms.dart`):
WordPress like pages an admin writes in the app, rendered to static SEO
friendly html by a cloud function (`CmsRenderer`).

- `CmsPagesScreen` — the page list (published toggle, create, open).
- `CmsPageEditScreen` — the page form: title, slug, summary, markdown body with
  a live preview, item link (location, activity, event, offer), tags, SEO
  fields, publish.
- `CmsPagePreviewScreen` — the page as the reader sees it (markdown rendered).

The screens read their `CmsPageSdb` from `cmsPageSdbProvider`, a riverpod
provider the host app overrides with `cmsPageSdbScope`:

```dart
cmsPageSdbScope(
  sdb: calendarSdb.pages,   // any CmsPageSdb on a database including cmsPageStoreSchema
  child: const CmsPagesScreen(),
)
```

Navigation is plain `Navigator` pushes by default; a go_router host passes
`onOpenPage`/`onCreatePage` callbacks and wires its own routes.
