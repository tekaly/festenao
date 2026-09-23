# festenao_demo

Demo data of festenao, free of Flutter, shared by the example apps, the tests
and the demo cloud functions. One library per area, `festenao_demo.dart`
exporting them all:

| Library | What |
|---|---|
| `festenao_demo_cms.dart` | a small summer festival cms site |

More areas (quizz, a `bp_app` project...) are meant to join it the same way:
a `lib/src/<area>/` folder and a `festenao_demo_<area>.dart` library.

## The cms demo

- `demoCmsSite()`, `demoCmsPages()`, `demoCmsPageOptions()`: the site, its
  pages (one of each kind and format, a no index one, a draft) and the
  details and structured data of the pages presenting an item.
- `DemoCms.create()`: the pages in an in memory sdb, with their renderer.
- `DemoCmsServer`, `demoCmsServer`: the site at whatever url a request
  reaches it, what the `cmsdemo` cloud function of `festenao_dartff`
  answers (`https://<hosting>/cmsdemo/`).
- `fillDemoCmsProject(firestore:, app:)`: the demo project in firestore, its
  document and the pages as its synced content
  (`app/<app>/project/demo_festival/data/content`), what the `cms` /
  `cmsdev` function of a `FestenaoServerApp` serves at
  `<cms>/demo_festival/content/`.

```dart
import 'package:festenao_demo/festenao_demo_cms.dart';

Future<void> main() async {
  var response = await demoCmsServer.handle(
    CmsSiteRequest.fromUrl(Uri.parse('https://example.com/page/about')),
  );
  print(response.body); // <!DOCTYPE html>...About the festival...
}
```

Used by:

- `packages/festenao_dartff`: the `cmsdemo` function, and the tests of the
  cms functions (in memory and on the emulator);
- `packages_flutter/festenao_dashboard_base_app/example/demo`: the cms
  screens and its local servers.
