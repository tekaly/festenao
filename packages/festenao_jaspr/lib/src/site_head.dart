/// The head of a page: title, description, canonical url, hreflang
/// alternates, robots, OpenGraph and Twitter tags, JSON-LD.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'json_ld.dart';
import 'lang.dart';

/// The share image of a page (OpenGraph, Twitter).
class SiteImage {
  /// Its absolute url.
  final String url;

  /// Its width in pixels (1200 for the usual 1200×630).
  final int width;

  /// Its height in pixels.
  final int height;

  /// What it shows.
  final String alt;

  /// A share image.
  const SiteImage({
    required this.url,
    required this.width,
    required this.height,
    required this.alt,
  });
}

/// What the head of a page says.
class SiteHeadData {
  /// The language of the page.
  final SiteLang lang;

  /// The name of the site (`og:site_name`).
  final String siteName;

  /// The title, 50 to 60 characters at most.
  final String title;

  /// The description, about 150 characters.
  final String description;

  /// The absolute canonical url, null for a page served at any url (404).
  final String? url;

  /// The absolute url of the page in each language it exists in. With two
  /// or more, `hreflang` links are written for each, plus `x-default` on
  /// the English one.
  final Map<SiteLang, String> alternates;

  /// Search engines must stay away (dev site, 404 page).
  final bool noIndex;

  /// The share image.
  final SiteImage? image;

  /// The JSON-LD of the page, if any.
  final Map<String, Object?>? jsonLd;

  /// A head.
  const SiteHeadData({
    required this.lang,
    required this.siteName,
    required this.title,
    required this.description,
    this.url,
    this.alternates = const {},
    this.noIndex = false,
    this.image,
    this.jsonLd,
  });
}

Component _property(String property, String content) =>
    meta(attributes: {'property': property}, content: content);

/// The head of a page from [data], merged by jaspr into the document head.
class SiteHead extends StatelessComponent {
  /// What the head says.
  final SiteHeadData data;

  /// A head.
  const SiteHead(this.data, {super.key});

  @override
  Component build(BuildContext context) {
    var lang = data.lang;
    var image = data.image;
    var alternates = data.alternates.length > 1;
    var xDefault = data.alternates[SiteLang.en];
    return Document.head(
      title: data.title,
      meta: {
        'description': data.description,
        if (data.noIndex) 'robots': 'noindex, nofollow',
        'twitter:card': image != null ? 'summary_large_image' : 'summary',
        'twitter:title': data.title,
        'twitter:description': data.description,
        'twitter:image': ?image?.url,
      },
      children: [
        if (data.url case var url?) link(rel: 'canonical', href: url),
        if (alternates) ...[
          for (var MapEntry(key: alternate, value: href)
              in data.alternates.entries)
            link(
              rel: 'alternate',
              href: href,
              attributes: {'hreflang': alternate.code},
            ),
          if (xDefault != null)
            link(
              rel: 'alternate',
              href: xDefault,
              attributes: const {'hreflang': 'x-default'},
            ),
        ],
        _property('og:type', 'website'),
        _property('og:site_name', data.siteName),
        _property('og:title', data.title),
        _property('og:description', data.description),
        if (data.url case var url?) _property('og:url', url),
        if (image != null) ...[
          _property('og:image', image.url),
          _property('og:image:width', '${image.width}'),
          _property('og:image:height', '${image.height}'),
          _property('og:image:alt', image.alt),
        ],
        _property('og:locale', lang.ogLocale),
        if (alternates)
          for (var alternate in data.alternates.keys)
            if (alternate != lang)
              _property('og:locale:alternate', alternate.ogLocale),
        if (data.jsonLd case var jsonLd?) jsonLdScript(jsonLd),
      ],
    );
  }
}
