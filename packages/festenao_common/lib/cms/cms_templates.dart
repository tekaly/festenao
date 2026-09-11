/// The mustache templates a [CmsRenderer] renders with.
///
/// Every template gets the values documented on the renderer; an app only
/// overrides the ones it wants to restyle, the defaults produce a small,
/// dependency free, responsive html page.
class CmsTemplates {
  /// The html document around a page or an index; receives `content` (raw
  /// html) plus the head values (title, description, canonicalUrl, jsonLd...).
  final String layout;

  /// The body of one page.
  final String page;

  /// The body of the page list.
  final String index;

  /// The body of a not found page.
  final String notFound;

  /// The css inlined in the layout.
  final String css;

  /// Templates, defaulting to the built in ones.
  const CmsTemplates({
    this.layout = cmsDefaultLayoutTemplate,
    this.page = cmsDefaultPageTemplate,
    this.index = cmsDefaultIndexTemplate,
    this.notFound = cmsDefaultNotFoundTemplate,
    this.css = cmsDefaultCss,
  });

  /// The built in templates.
  static const defaults = CmsTemplates();
}

/// Default layout: a complete html document with the SEO head.
const cmsDefaultLayoutTemplate = '''
<!DOCTYPE html>
<html lang="{{lang}}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{title}}</title>
{{#description}}<meta name="description" content="{{description}}">
{{/description}}{{#canonicalUrl}}<link rel="canonical" href="{{{canonicalUrl}}}">
{{/canonicalUrl}}{{#noIndex}}<meta name="robots" content="noindex, nofollow">
{{/noIndex}}<meta property="og:type" content="{{ogType}}">
<meta property="og:title" content="{{title}}">
{{#description}}<meta property="og:description" content="{{description}}">
{{/description}}{{#canonicalUrl}}<meta property="og:url" content="{{{canonicalUrl}}}">
{{/canonicalUrl}}<meta property="og:site_name" content="{{siteName}}">
<meta property="og:locale" content="{{lang}}">
{{#imageUrl}}<meta property="og:image" content="{{{imageUrl}}}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:image" content="{{{imageUrl}}}">
{{/imageUrl}}{{^imageUrl}}<meta name="twitter:card" content="summary">
{{/imageUrl}}<meta name="twitter:title" content="{{title}}">
{{#description}}<meta name="twitter:description" content="{{description}}">
{{/description}}{{#jsonLd}}<script type="application/ld+json">{{{jsonLd}}}</script>
{{/jsonLd}}{{#generator}}<meta name="generator" content="{{generator}}">
{{/generator}}<style>{{{css}}}</style>
</head>
<body>
<header class="site-header">
<nav aria-label="Main">
<a class="site-name" href="{{{siteUrl}}}">{{#logoUrl}}<img src="{{{logoUrl}}}" alt="" height="32"> {{/logoUrl}}{{siteName}}</a>
{{#hasNav}}<ul>{{#nav}}<li><a href="{{{url}}}">{{label}}</a></li>{{/nav}}</ul>{{/hasNav}}
</nav>
</header>
<main>
{{{content}}}
</main>
<footer class="site-footer">
{{#footerHtml}}{{{footerHtml}}}{{/footerHtml}}{{^footerHtml}}<p>&copy; {{year}} {{siteName}}</p>{{/footerHtml}}
</footer>
</body>
</html>
''';

/// Default page body.
const cmsDefaultPageTemplate = '''
<article class="page page-{{itemKind}}">
<header>
<h1>{{title}}</h1>
{{#summary}}<p class="summary">{{summary}}</p>
{{/summary}}{{#heroImage}}<figure class="hero"><img src="{{{url}}}" alt="{{alt}}"{{#width}} width="{{width}}"{{/width}}{{#height}} height="{{height}}"{{/height}}>{{#caption}}<figcaption>{{caption}}</figcaption>{{/caption}}</figure>
{{/heroImage}}</header>
{{#hasDetails}}<dl class="details">{{#details}}<dt>{{label}}</dt><dd>{{value}}</dd>{{/details}}</dl>
{{/hasDetails}}<section class="body">
{{{bodyHtml}}}
</section>
{{#hasImages}}<section class="gallery">
{{#images}}<figure><img src="{{{url}}}" alt="{{alt}}" loading="lazy"{{#width}} width="{{width}}"{{/width}}{{#height}} height="{{height}}"{{/height}}>{{#caption}}<figcaption>{{caption}}</figcaption>{{/caption}}</figure>
{{/images}}</section>
{{/hasImages}}{{#hasTags}}<p class="tags">{{#tags}}<span class="tag">{{tag}}</span> {{/tags}}</p>
{{/hasTags}}{{#publishedAt}}<p class="meta"><time datetime="{{publishedAt}}">{{publishedAt}}</time></p>
{{/publishedAt}}</article>
''';

/// Default index body: one card per page.
const cmsDefaultIndexTemplate = '''
<section class="index">
<h1>{{title}}</h1>
{{#description}}<p class="summary">{{description}}</p>
{{/description}}{{#hasPages}}<ul class="cards">
{{#pages}}<li class="card"><a href="{{{url}}}">{{#imageUrl}}<img src="{{{imageUrl}}}" alt="" loading="lazy">{{/imageUrl}}<h2>{{title}}</h2>{{#summary}}<p>{{summary}}</p>{{/summary}}</a></li>
{{/pages}}</ul>
{{/hasPages}}{{^hasPages}}<p class="empty">{{emptyMessage}}</p>
{{/hasPages}}</section>
''';

/// Default not found body.
const cmsDefaultNotFoundTemplate = '''
<section class="not-found">
<h1>{{title}}</h1>
<p>{{message}}</p>
<p><a href="{{{siteUrl}}}">{{siteName}}</a></p>
</section>
''';

/// Default css: readable defaults, one column, dark mode aware.
const cmsDefaultCss = '''
:root{--fg:#1d1d1f;--bg:#fff;--muted:#6e6e73;--link:#0a66c2;--card:#f5f5f7;--max:56rem;font-size:16px}
@media(prefers-color-scheme:dark){:root{--fg:#f5f5f7;--bg:#111;--muted:#a1a1a6;--link:#5ea9ff;--card:#1d1d1f}}
*{box-sizing:border-box}
body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;line-height:1.6;color:var(--fg);background:var(--bg)}
a{color:var(--link)}
img{max-width:100%;height:auto;border-radius:.5rem}
main,.site-header nav,.site-footer{max-width:var(--max);margin:0 auto;padding:0 1rem}
.site-header{border-bottom:1px solid var(--card)}
.site-header nav{display:flex;align-items:center;gap:1.5rem;flex-wrap:wrap;padding-top:.75rem;padding-bottom:.75rem}
.site-name{font-weight:700;text-decoration:none;color:var(--fg);display:flex;align-items:center;gap:.5rem}
.site-header ul{display:flex;gap:1rem;list-style:none;margin:0;padding:0;flex-wrap:wrap}
main{padding-top:1.5rem;padding-bottom:3rem}
h1{font-size:2rem;line-height:1.2;margin:.5rem 0}
.summary{font-size:1.15rem;color:var(--muted)}
figure{margin:1rem 0}
figcaption{font-size:.9rem;color:var(--muted)}
.details{display:grid;grid-template-columns:max-content 1fr;gap:.25rem 1rem;background:var(--card);padding:1rem;border-radius:.5rem}
.details dt{font-weight:600}
.details dd{margin:0}
.gallery{display:grid;grid-template-columns:repeat(auto-fill,minmax(14rem,1fr));gap:1rem}
.gallery figure{margin:0}
.tag{display:inline-block;background:var(--card);padding:.1rem .6rem;border-radius:1rem;font-size:.85rem}
.meta{color:var(--muted);font-size:.9rem}
.cards{list-style:none;padding:0;margin:0;display:grid;grid-template-columns:repeat(auto-fill,minmax(16rem,1fr));gap:1rem}
.card a{display:block;background:var(--card);border-radius:.75rem;padding:1rem;text-decoration:none;color:var(--fg);height:100%}
.card h2{font-size:1.2rem;margin:.5rem 0}
.card p{color:var(--muted);margin:0}
.site-footer{padding-top:1rem;padding-bottom:2rem;color:var(--muted);font-size:.9rem;border-top:1px solid var(--card)}
''';
