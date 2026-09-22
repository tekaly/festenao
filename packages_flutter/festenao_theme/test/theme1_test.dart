import 'package:festenao_theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('themeData1', () {
    test('keeps the font of every text style, labelSmall included', () {
      var theme = themeData1(fontFamily: 'Test');
      var textTheme = theme.textTheme;
      // The small labels are what badges and section headers are drawn with,
      // and they used to lose the family to a colour override.
      expect(textTheme.labelSmall?.fontFamily, 'Test');
      expect(textTheme.bodyMedium?.fontFamily, 'Test');
      expect(textTheme.titleLarge?.fontFamily, 'Test');
      // And the colour it is overridden for is still there.
      expect(
        textTheme.labelSmall?.color,
        isNot(themeData1().textTheme.bodyMedium?.color),
      );
    });

    test('is light or dark as asked, on the seed it is given', () {
      expect(themeData1().colorScheme.brightness, Brightness.dark);
      expect(themeDataLight1().colorScheme.brightness, Brightness.light);
      expect(
        themeData1(seedColor: Colors.amber).colorScheme.primary,
        isNot(themeData1().colorScheme.primary),
      );
    });
  });
}
