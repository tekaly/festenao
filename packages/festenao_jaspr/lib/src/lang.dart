/// The languages of the sites and the text type that carries them all.
library;

/// A language of the site. English is the default (served at the root),
/// French lives under `/fr/` and is served to French browsers through
/// Firebase Hosting i18n rewrites.
enum SiteLang {
  /// English, the default.
  en('en', 'en_US', 'English'),

  /// French.
  fr('fr', 'fr_FR', 'Français');

  const SiteLang(this.code, this.ogLocale, this.name);

  /// The html `lang` and `hreflang` code.
  final String code;

  /// The OpenGraph locale.
  final String ogLocale;

  /// The name of the language in itself, for the language link.
  final String name;

  /// The other language (the sites have two).
  SiteLang get other => this == SiteLang.en ? SiteLang.fr : SiteLang.en;
}

/// A text in every language of the site: a missing translation does not
/// compile.
class Tr {
  /// The English text.
  final String en;

  /// The French text.
  final String fr;

  /// A text in both languages.
  const Tr(this.en, this.fr);

  /// The same text in both languages (a name, a url).
  const Tr.same(String text) : en = text, fr = text;

  /// The text in [lang].
  String of(SiteLang lang) => switch (lang) {
    SiteLang.en => en,
    SiteLang.fr => fr,
  };
}
