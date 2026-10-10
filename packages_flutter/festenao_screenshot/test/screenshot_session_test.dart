import 'dart:io';
import 'dart:typed_data';

import 'package:festenao_screenshot/festenao_screenshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

/// The width and height of a png.
(int, int) _pngSize(File file) {
  var data = ByteData.sublistView(file.readAsBytesSync());
  return (data.getUint32(16), data.getUint32(20));
}

final _directory = Directory.systemTemp.createTempSync('festenao_screenshot');

Widget _screen(String text) => MaterialApp(
  home: Scaffold(
    appBar: AppBar(title: Text(text)),
    body: const Center(child: Icon(Icons.home)),
  ),
);

void main() {
  tearDownAll(() => _directory.deleteSync(recursive: true));

  test('names', () {
    expect(screenshotNames(''), isEmpty);
    expect(screenshotNames(' a, b ,,c'), {'a', 'b', 'c'});
  });

  testWidgets('font fallbacks keep the package of a family', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            Text(
              'package',
              style: TextStyle(fontFamily: 'Poppins', package: 'my_theme'),
            ),
            Text('bare', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
    patchFontFallbacks(tester);
    TextStyle style(String text) => tester
        .renderObjectList<RenderParagraph>(find.text(text))
        .single
        .text
        .style!;
    expect(style('package').fontFamily, 'packages/my_theme/Poppins');
    expect(style('package').fontFamilyFallback, ['DejaVu Sans']);
    expect(style('bare').fontFamily, 'Roboto');
    expect(style('bare').fontFamilyFallback, ['DejaVu Sans']);
    expect(style('bare').fontSize, 12);
  });

  runScreenshots('numbered per prefix, filtered, at the pixel ratio', (
    session,
  ) async {
    await session.open(_screen('One'), size: const Size(200, 100));
    var file = (await session.shot('one'))!;
    expect(file.path, endsWith('/01_one.png'));
    expect(_pngSize(file), (400, 200));
    expect(find.text('One'), findsOneWidget);

    await session.open(_screen('Two'));
    expect(
      (await session.shot('two', prefix: 'phone'))!.path,
      endsWith('/phone_01_two.png'),
    );
    expect(session.nextFileName('three', prefix: 'phone'), 'phone_02_three');
    session.skip(prefix: 'phone');
    expect(
      (await session.shot('four', prefix: 'phone'))!.path,
      endsWith('/phone_03_four.png'),
    );
    session.resetIndex(prefix: 'phone');
    expect(session.nextFileName('again', prefix: 'phone'), 'phone_01_again');
    expect(
      (await session.shotNamed('phone_02b_variant'))!.path,
      endsWith('/phone_02b_variant.png'),
    );
    expect((await session.shot('five'))!.path, endsWith('/02_five.png'));
    expect(session.files, hasLength(5));
    expect(session.errors, isEmpty);
  }, directory: _directory);

  runScreenshots(
    'only',
    (session) async {
      await session.open(_screen('Only'), size: const Size(100, 100));
      expect(session.wantsNext('one', prefix: 'phone'), isFalse);
      expect(await session.shot('one', prefix: 'phone'), isNull);
      expect(session.wantsNext('two', prefix: 'phone'), isTrue);
      expect(
        (await session.shot('two', prefix: 'phone'))!.path,
        endsWith('/phone_02_two.png'),
      );
      expect(await session.shotNamed('phone_02b_variant'), isNull);
      expect(
        (await session.shotNamed('phone_03b_variant'))!.path,
        endsWith('/phone_03b_variant.png'),
      );
    },
    directory: Directory('${_directory.path}/only'),
    only: {'two', 'phone_03b_variant'},
  );
}
