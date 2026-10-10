import 'package:festenao_theme/fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The text measured: 18 characters, 360 wide in the test font (squares).
const _text = 'Festival iiii MMMM';
const _testFontWidth = 360.0;

double _width(String family, {FontWeight? weight, FontStyle? style}) {
  var painter = TextPainter(
    text: TextSpan(
      text: _text,
      style: TextStyle(
        fontFamily: family,
        fontSize: 20,
        fontWeight: weight,
        fontStyle: style,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  var width = painter.width;
  painter.dispose();
  return width;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bare families draw the festenao fonts once loaded', () async {
    expect(_width(poppinsFontFamily), _testFontWidth);
    expect(_width(jetBrainsMonoFontFamily), _testFontWidth);

    await loadFestenaoFonts();

    var regular = _width(poppinsFontFamily);
    var medium = _width(poppinsFontFamily, weight: FontWeight.w500);
    var bold = _width(poppinsFontFamily, weight: FontWeight.w700);
    var italic = _width(poppinsFontFamily, style: FontStyle.italic);
    expect(regular, lessThan(_testFontWidth));
    expect(medium, greaterThan(regular));
    expect(bold, greaterThan(medium));
    expect(italic, isNot(regular));
    // A monospace font: every character as wide.
    expect(
      _width(jetBrainsMonoFontFamily),
      moreOrLessEquals(_text.length * 12.0, epsilon: 0.01),
    );

    // The extra bold weight, added to the family on demand.
    var extraBold = _width(poppinsFontFamily, weight: FontWeight.w800);
    expect(extraBold, bold);
    await loadFestenaoFonts(extra: [poppinsExtraBoldFont]);
    expect(
      _width(poppinsFontFamily, weight: FontWeight.w800),
      greaterThan(bold),
    );
  });

  test('a font is loaded once, under another family when asked', () async {
    expect(loadFestenaoFont(poppinsFont), same(loadFestenaoFont(poppinsFont)));
    expect(_width('monospace'), _testFontWidth);
    await loadFestenaoFont(jetBrainsMonoFont, family: 'monospace');
    expect(_width('monospace'), _width(jetBrainsMonoFontFamily));
  });

  test('a missing file is reported, not thrown', () async {
    var errors = <FlutterErrorDetails>[];
    var onError = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await loadFestenaoFont((
        family: 'Missing',
        package: 'festenao_theme',
        files: ['fonts/missing.ttf', 'fonts/missing_too.ttf'],
      ));
    } finally {
      FlutterError.onError = onError;
    }
    expect(errors, hasLength(1));
    expect(errors.first.library, 'festenao_theme');
  });
}
