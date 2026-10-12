import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'lang.dart';

/// The cookie Firebase Hosting reads before `Accept-Language` to pick the
/// language of its i18n rewrites.
const firebaseLanguageOverrideCookie = 'firebase-language-override';

/// One year, in seconds.
const _maxAge = 365 * 24 * 3600;

/// The inline script that sets [firebaseLanguageOverrideCookie] to [lang]
/// for a year, on [cookieDomain] when the page is served from it or one of
/// its subdomains (so one choice holds across `*.youpi.app`), on the page's
/// own host otherwise.
String languageCookieScript(SiteLang lang, {String? cookieDomain}) {
  var cookie =
      "'$firebaseLanguageOverrideCookie=${lang.code};path=/;"
      "max-age=$_maxAge;samesite=lax'";
  if (cookieDomain == null) {
    return 'document.cookie=$cookie';
  }
  var hostRegExp = '/(^|\\.)${RegExp.escape(cookieDomain)}\$/';
  return 'document.cookie=$cookie'
      "+($hostRegExp.test(location.hostname)?';domain=$cookieDomain':'')";
}

/// The link to the page in the [to] language. A click also stores the
/// choice in [firebaseLanguageOverrideCookie], so that Firebase Hosting
/// keeps serving that language whatever the browser asks for. Without
/// JavaScript the link still works, the choice is just not kept.
class LanguageLink extends StatelessComponent {
  /// The language of the target page.
  final SiteLang to;

  /// The url of the page in [to].
  final String href;

  /// See [languageCookieScript].
  final String? cookieDomain;

  /// The css classes.
  final String classes;

  /// The text, the language name in itself by default.
  final String? label;

  /// A language link.
  const LanguageLink({
    super.key,
    required this.to,
    required this.href,
    this.cookieDomain,
    this.classes = 'lang-switch',
    this.label,
  });

  @override
  Component build(BuildContext context) => a(
    href: href,
    classes: classes,
    attributes: {
      'hreflang': to.code,
      'lang': to.code,
      'onclick': languageCookieScript(to, cookieDomain: cookieDomain),
    },
    [.text(label ?? to.name)],
  );
}
