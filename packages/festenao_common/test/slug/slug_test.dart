import 'package:festenao_common/festenao_slug.dart';
import 'package:test/test.dart';

void main() {
  group('festenaoSlugify', () {
    test('text', () {
      expect(
        festenaoSlugify('Solaris Music Festival 2025'),
        'solaris-music-festival-2025',
      );
      expect(festenaoSlugify('  Café  crème & Œuf!! '), 'cafe-creme-oeuf');
      expect(festenaoSlugify('Salle n°2 (étage)'), 'salle-n-2-etage');
      expect(festenaoSlugify('---'), '');
      expect(festenaoSlugify('---', fallback: 'x'), 'x');
    });
    test('max length at a word boundary', () {
      var slug = festenaoSlugify('word ' * 20);
      expect(slug.length, lessThanOrEqualTo(festenaoSlugMaxLength));
      expect(slug, isNot(endsWith('-')));
      expect(slug, startsWith('word-word'));
      expect(festenaoSlugify('a' * 50).length, festenaoSlugMaxLength);
    });
  });
  group('options', () {
    const options = festenaoSlugOptionsDefault;
    test('check', () {
      expect(options.check('solaris-2025'), isNull);
      expect(options.check('ab'), FestenaoSlugError.tooShort);
      expect(options.check('a' * 41), FestenaoSlugError.tooLong);
      expect(options.check('Solaris'), FestenaoSlugError.invalidCharacters);
      expect(options.check('a--b'), FestenaoSlugError.invalidCharacters);
      expect(options.check('-ab'), FestenaoSlugError.invalidCharacters);
      expect(options.check('admin'), FestenaoSlugError.reserved);
      expect(const FestenaoSlugOptions(reserved: {}).check('admin'), isNull);
    });
    test('candidates', () {
      expect(options.candidates('fest', count: 3).toList(), [
        'fest',
        'fest-2',
        'fest-3',
      ]);
      expect(options.candidates('ab', count: 2).toList(), ['ab-2']);
      expect(options.candidates('admin', count: 2).toList(), ['admin-2']);
      var long = 'a' * 40;
      expect(options.candidates(long, count: 2).last.length, 40);
    });
    test('parse', () {
      String? parse(String input) => options.parse(input, pathSegments: ['e']);
      expect(parse('solaris-2025'), 'solaris-2025');
      expect(parse(' Solaris-2025 '), 'solaris-2025');
      expect(
        parse('https://quick-covoit.web.app/e/solaris-2025'),
        'solaris-2025',
      );
      expect(
        parse('https://quick-covoit.web.app/e/solaris-2025/trip/x'),
        'solaris-2025',
      );
      expect(parse('/e/solaris-2025'), 'solaris-2025');
      expect(parse('https://quick-covoit.web.app/p/solaris-2025'), isNull);
      expect(parse('https://quick-covoit.web.app/e/'), isNull);
      expect(parse('not a slug'), isNull);
      expect(parse(''), isNull);
    });
  });
}
