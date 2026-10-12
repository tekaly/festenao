# festenao_jaspr

Shared [jaspr](https://jaspr.site) components of the festenao and youpi
static sites (jaspr `mode: static`): what every site page needs, the design
left to each site.

- `SiteLang` and `Tr`: English (default, at the root) and French (under
  `/fr/`), a text in both or it does not compile.
- `SiteHead` from `SiteHeadData`: title, description, canonical, `hreflang`
  pairs plus `x-default`, robots noindex, OpenGraph, Twitter, JSON-LD.
- `LanguageLink`: the link to the other language that also sets the
  `firebase-language-override` cookie, so that Firebase Hosting i18n
  rewrites keep serving the chosen language.
- `FaqList` (native `details`), `rich` (`**bold**` and `[text](url)`),
  `siteImage` (sized, lazy, 2x), `StoreBadges`, `jsonLdScript`.
- `package:festenao_jaspr/server.dart` (server only, `dart:io`):
  `siteDocument` (theme colour, fonts preload, stylesheet inlined) and
  `MarkdownFile` (legal pages from `content/legal/*.md`).

Build and deploy the site with `tekartik_jaspr_build`
(`tekartik/app_build.dart`, `packages/jaspr_build`): it makes the i18n copies
from the `hreflang` links this package writes.

## Setup

```yaml
dependencies:
  festenao_jaspr:
    git:
      url: https://github.com/tekaly/festenao
      path: packages/festenao_jaspr
```

The package depends on `jaspr`, `markdown` and `path` only, on purpose: the
sites are standalone packages resolving `jaspr_builder` (analyzer 12). Never
add festenao_common, tkcms_common or anything pulling the Firebase admin
sdk. It has no `@client` component: an island needs `jaspr_builder` in the
package that declares it, so islands stay in the sites.
