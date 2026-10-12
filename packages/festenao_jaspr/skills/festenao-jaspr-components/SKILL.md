---
name: festenao-jaspr-components
description: >-
  Use when writing the pages of a jaspr static site (jaspr mode: static) with
  package:festenao_jaspr: SiteLang and Tr (English default, French under
  /fr/), SiteHead and SiteHeadData (canonical, hreflang pairs and x-default,
  robots noindex, OpenGraph, Twitter, SiteImage, JSON-LD), LanguageLink and
  languageCookieScript (the firebase-language-override cookie of Firebase
  Hosting i18n rewrites), FaqList and FaqItem, rich, siteImage, StoreBadges,
  jsonLdScript, and package:festenao_jaspr/server.dart (siteDocument,
  MarkdownFile, markdownFileHtml). Building and deploying the site is
  tekartik_jaspr_build's job.
---

# festenao_jaspr components

The components every page of a festenao or youpi static site needs; the
design (CSS, header and footer layout, copy) stays in each site. Pages are
rendered by `jaspr build` on the server; this package has no client code.

```dart
import 'package:festenao_jaspr/festenao_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

const siteUrl = 'https://example.youpi.app';

class HomePage extends StatelessComponent {
  final SiteLang lang;

  const HomePage({super.key, required this.lang});

  @override
  Component build(BuildContext context) {
    return Component.fragment([
      SiteHead(
        SiteHeadData(
          lang: lang,
          siteName: 'Example',
          title: const Tr('Example', 'Exemple').of(lang),
          description: const Tr('An app.', 'Une appli.').of(lang),
          url: lang == SiteLang.en ? '$siteUrl/' : '$siteUrl/fr/',
          alternates: const {
            SiteLang.en: '$siteUrl/',
            SiteLang.fr: '$siteUrl/fr/',
          },
        ),
      ),
      Document.html(attributes: {'lang': lang.code}),
      LanguageLink(
        to: lang.other,
        href: lang.other == SiteLang.en ? '/' : '/fr/',
        cookieDomain: 'youpi.app',
      ),
      main_(rich(const Tr('**Free**, no account.', '**Gratuit**, sans compte.').of(lang))),
    ]);
  }
}
```

## Guidelines

### Languages

* Every text is a `Tr(en, fr)`: a missing translation does not compile.
  `Tr.same` for names and urls.
* English lives at the root, French under `/fr/` (localized slugs allowed,
  `/legal/` and `/fr/mentions-legales/`). Each page writes both urls in
  `SiteHeadData.alternates`, absolute: `SiteHead` adds `x-default` on the
  English one, and tekartik_jaspr_build reads the `hreflang="fr"` link to
  make the copy Firebase Hosting serves to French browsers.
* Always use `LanguageLink` for the switch: its `onclick` stores the choice
  in the `firebase-language-override` cookie, which Hosting reads before the
  browser's `Accept-Language`. Pass `cookieDomain` (`youpi.app`) so that one
  choice holds across the sites of the domain.

### Head

* One `SiteHead` per page, in the page component; jaspr merges it into the
  document head.
* A page with a url of its own gets `url` (canonical) and `alternates`; the
  404 page gets neither and `noIndex: true`.
* `noIndex` on every page of a dev or not launched site (from the site's
  `<PREFIX>_SITE_NOINDEX` define).
* `image` (1200×630 usually) makes the Twitter card `summary_large_image`;
  without it the card is `summary`.
* `jsonLd` takes a map; `jsonLdEncode` escapes `</` so the json cannot close
  its script.

### Server only

* Import `package:festenao_jaspr/server.dart` only from server code
  (`main.server.dart`, the document, pages that read files): it uses
  `dart:io`. Paths are relative to the site package, the current directory
  of `jaspr build`, `jaspr serve` and the tests.
* `siteDocument` inlines `styles/site.css` by default (`cssPath: null` for
  none) and preloads the given font urls.

### What not to put here

* No `@client` component: islands need `jaspr_builder` in the declaring
  package; keep them in the site.
* No dependency beyond jaspr, markdown and path: the sites resolve
  `jaspr_builder` (analyzer 12).

## Examples

### The document and a markdown legal page

```dart
import 'package:festenao_jaspr/server.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

Component exampleDocument() => siteDocument(
  title: 'Example',
  themeColor: '#ffffff',
  colorScheme: 'light dark',
  preloadFonts: const ['/fonts/poppins-regular.woff2'],
  body: div(classes: 'wrap page', [
    MarkdownFile('content/legal/notice.en.md', classes: 'legal'),
  ]),
);
```

### A FAQ and store badges

```dart
import 'package:festenao_jaspr/festenao_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

Component support(SiteLang lang) => div([
  const FaqList(
    items: [
      (
        id: 'account',
        question: 'Do I need an account?',
        answer: 'No: tap **Create** and share the link.',
      ),
    ],
  ),
  StoreBadges(
    lang: lang,
    playStoreUrl: 'https://play.google.com/store/apps/details?id=com.example',
    appStoreUrl: 'https://apps.apple.com/app/example/id1',
  ),
]);
```

### Testing a page

```dart
@TestOn('vm')
library;

import 'package:festenao_jaspr/server.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_test/server_test.dart';

void main() {
  setUpAll(() {
    Jaspr.initializeApp(options: const ServerOptions());
  });
  testServer('home', (tester) async {
    tester.pumpComponent(
      siteDocument(title: 'Example', cssPath: null, body: Component.text('hi')),
    );
    var response = await tester.request('/');
    expect(response.statusCode, 200);
  });
}
```

## Common mistakes

* `'Document' is defined in ... markdown`: importing `package:markdown`
  next to jaspr; import it with `show markdownToHtml`.
* A French browser keeps getting English after the switch to French: the
  link was a plain `a`, not a `LanguageLink` (no cookie).
* The site fails to resolve after adding a festenao package next to this
  one: that package pulls analyzer 13 through the Firebase admin sdk.

## More

* Package README and CHANGELOG.
