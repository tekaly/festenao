import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'lang.dart';

/// The default alt texts of the badges, the stores' own wording.
const googlePlayBadgeAlt = Tr(
  'Get it on Google Play',
  'Disponible sur Google Play',
);

/// See [googlePlayBadgeAlt].
const appStoreBadgeAlt = Tr(
  'Download on the App Store',
  "Télécharger dans l'App Store",
);

/// The official Google Play and App Store badges, as their owners ship them
/// (trimmed of their transparent margin, nothing redrawn). The site serves
/// them as `/badges/google-play-<lang>.png` (161×48) and
/// `/badges/app-store-<lang>.svg` (144×48 in English, 152×48 in French).
class StoreBadges extends StatelessComponent {
  /// The language of the badges.
  final SiteLang lang;

  /// The Google Play listing (in [lang]), no badge when null.
  final String? playStoreUrl;

  /// The App Store listing, no badge when null.
  final String? appStoreUrl;

  /// Badges.
  const StoreBadges({
    super.key,
    required this.lang,
    this.playStoreUrl,
    this.appStoreUrl,
  });

  @override
  Component build(BuildContext context) {
    var appleWidth = lang == SiteLang.fr ? 152 : 144;
    return div(classes: 'badges', [
      if (playStoreUrl case var url?)
        a(href: url, classes: 'badge', [
          img(
            src: '/badges/google-play-${lang.code}.png',
            alt: googlePlayBadgeAlt.of(lang),
            width: 161,
            height: 48,
          ),
        ]),
      if (appStoreUrl case var url?)
        a(href: url, classes: 'badge', [
          img(
            src: '/badges/app-store-${lang.code}.svg',
            alt: appStoreBadgeAlt.of(lang),
            width: appleWidth,
            height: 48,
          ),
        ]),
    ]);
  }
}
