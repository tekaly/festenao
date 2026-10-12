import 'package:festenao_jaspr/festenao_jaspr.dart';
import 'package:test/test.dart';

void main() {
  group('SiteLang', () {
    test('codes', () {
      expect(SiteLang.values.map((lang) => lang.code), ['en', 'fr']);
      expect(SiteLang.fr.ogLocale, 'fr_FR');
      expect(SiteLang.en.other, SiteLang.fr);
      expect(SiteLang.fr.other, SiteLang.en);
      expect(SiteLang.fr.name, 'Français');
    });
  });

  group('Tr', () {
    test('of', () {
      const text = Tr('Hello', 'Bonjour');
      expect(text.of(SiteLang.en), 'Hello');
      expect(text.of(SiteLang.fr), 'Bonjour');
      expect(const Tr.same('Youpi').of(SiteLang.fr), 'Youpi');
    });
  });

  group('languageCookieScript', () {
    test('own host', () {
      expect(
        languageCookieScript(SiteLang.fr),
        "document.cookie='firebase-language-override=fr;path=/;"
        "max-age=31536000;samesite=lax'",
      );
    });
    test('shared domain', () {
      expect(
        languageCookieScript(SiteLang.en, cookieDomain: 'youpi.app'),
        "document.cookie='firebase-language-override=en;path=/;"
        "max-age=31536000;samesite=lax'"
        r'+(/(^|\.)youpi\.app$/.test(location.hostname)'
        "?';domain=youpi.app':'')",
      );
    });
  });

  group('jsonLdEncode', () {
    test('a closing tag cannot end the script', () {
      expect(jsonLdEncode({'name': '</script>'}), r'{"name":"<\/script>"}');
    });
  });
}
