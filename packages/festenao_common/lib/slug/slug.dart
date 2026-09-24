/// Slugs: the configurable, human readable part of an url
/// (`https://<hosting>/e/<slug>`), and the rules they follow.
///
/// A slug is lower case ascii letters, digits and single dashes, starting
/// and ending with a letter or a digit, [FestenaoSlugOptions.minLength] to
/// [FestenaoSlugOptions.maxLength] long, and not one of the reserved words
/// (the first segments of the app routes). See `slug_registry.dart` for the
/// firestore registry making a slug unique.
library;

/// Default minimum length of a slug.
const festenaoSlugMinLength = 3;

/// Default maximum length of a slug.
const festenaoSlugMaxLength = 40;

/// Words commonly reserved: route segments and words that would be
/// confusing in a shared link. Pass your own set to [FestenaoSlugOptions]
/// when an app has other top level routes.
const festenaoSlugReservedWords = <String>{
  'about',
  'account',
  'admin',
  'api',
  'app',
  'debug',
  'demo',
  'edit',
  'join',
  'login',
  'new',
  'settings',
  'share',
  'test',
};

/// Why a text is not a valid slug.
enum FestenaoSlugError {
  /// Shorter than [FestenaoSlugOptions.minLength].
  tooShort,

  /// Longer than [FestenaoSlugOptions.maxLength].
  tooLong,

  /// Something else than lower case letters, digits and single inner
  /// dashes.
  invalidCharacters,

  /// One of [FestenaoSlugOptions.reserved].
  reserved,
}

final _slugRegExp = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

const _accentMap = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'æ': 'ae',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'œ': 'oe',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ß': 'ss',
};

/// Make a slug out of a free [text] (a name, a title): lower case ascii
/// letters, digits and dashes.
///
/// Accents are stripped (`Café` gives `cafe`), anything else becomes a dash,
/// dashes are collapsed and trimmed, and the result is capped to
/// [maxLength], at a word boundary when one is past the middle. Returns
/// [fallback] when nothing usable remains. The result may still be an
/// invalid slug (too short, reserved): check it with
/// [FestenaoSlugOptions.check].
String festenaoSlugify(
  String text, {
  int maxLength = festenaoSlugMaxLength,
  String fallback = '',
}) {
  var sb = StringBuffer();
  var lastDash = true;
  for (var rune in text.toLowerCase().runes) {
    var char = String.fromCharCode(rune);
    char = _accentMap[char] ?? char;
    for (var c in char.codeUnits) {
      var isAlnum = (c >= 0x30 && c <= 0x39) || (c >= 0x61 && c <= 0x7a);
      if (isAlnum) {
        sb.writeCharCode(c);
        lastDash = false;
      } else if (!lastDash) {
        sb.write('-');
        lastDash = true;
      }
    }
  }
  var slug = sb.toString();
  if (slug.endsWith('-')) {
    slug = slug.substring(0, slug.length - 1);
  }
  if (slug.length > maxLength) {
    slug = slug.substring(0, maxLength);
    var lastDashIndex = slug.lastIndexOf('-');
    if (lastDashIndex > maxLength ~/ 2) {
      slug = slug.substring(0, lastDashIndex);
    } else if (slug.endsWith('-')) {
      slug = slug.substring(0, slug.length - 1);
    }
  }
  return slug.isEmpty ? fallback : slug;
}

/// The slug rules of an app.
class FestenaoSlugOptions {
  /// Minimum length.
  final int minLength;

  /// Maximum length.
  final int maxLength;

  /// Words a slug cannot be.
  final Set<String> reserved;

  /// The slug rules of an app.
  const FestenaoSlugOptions({
    this.minLength = festenaoSlugMinLength,
    this.maxLength = festenaoSlugMaxLength,
    this.reserved = festenaoSlugReservedWords,
  });

  /// Why [slug] is not a valid slug, null when it is one.
  FestenaoSlugError? check(String slug) {
    if (slug.length < minLength) {
      return FestenaoSlugError.tooShort;
    }
    if (slug.length > maxLength) {
      return FestenaoSlugError.tooLong;
    }
    if (!_slugRegExp.hasMatch(slug)) {
      return FestenaoSlugError.invalidCharacters;
    }
    if (reserved.contains(slug)) {
      return FestenaoSlugError.reserved;
    }
    return null;
  }

  /// True when [slug] is a valid slug.
  bool isValid(String slug) => check(slug) == null;

  /// [festenaoSlugify] within [maxLength].
  String slugify(String text, {String fallback = ''}) =>
      festenaoSlugify(text, maxLength: maxLength, fallback: fallback);

  /// The slugs tried for [base] (typically [slugify] of a name) when it is
  /// taken: `base`, `base-2`, `base-3`... [count] of them, each within
  /// [maxLength]. A too short base is padded (`ab` gives `ab-1`...).
  Iterable<String> candidates(String base, {int count = 20}) sync* {
    if (base.length >= minLength && isValid(base)) {
      yield base;
    }
    for (var i = 2; i <= count; i++) {
      var suffix = '-$i';
      var head = base;
      if (head.length + suffix.length > maxLength) {
        head = head
            .substring(0, maxLength - suffix.length)
            .replaceAll(RegExp(r'-+$'), '');
      }
      var candidate = head.isEmpty ? 'x$suffix' : '$head$suffix';
      if (isValid(candidate)) {
        yield candidate;
      }
    }
  }

  /// The slug an url or a text typed by someone points to, null when
  /// [input] is neither.
  ///
  /// Accepts a full link (`https://<hosting>/e/my-event/trip/x`) or a path
  /// (`/e/my-event`) whose segment after one of [pathSegments] is the slug,
  /// or the slug itself (`My-Event`: case and surrounding spaces ignored).
  String? parse(String input, {required List<String> pathSegments}) {
    var text = input.trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.contains('/')) {
      var uri = Uri.tryParse(text);
      if (uri == null) {
        return null;
      }
      var segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      String? found;
      for (var i = 0; i < segments.length - 1; i++) {
        if (pathSegments.contains(segments[i])) {
          found = segments[i + 1];
          break;
        }
      }
      if (found == null) {
        return null;
      }
      text = found;
    }
    var slug = text.toLowerCase();
    return isValid(slug) ? slug : null;
  }
}

/// The default slug rules.
const festenaoSlugOptionsDefault = FestenaoSlugOptions();
