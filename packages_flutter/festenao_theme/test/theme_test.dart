import 'package:festenao_theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dark and light share the rules', () {
    var dark = themeData1();
    var light = themeDataLight1();
    expect(dark.brightness, Brightness.dark);
    expect(light.brightness, Brightness.light);
    for (var theme in [dark, light]) {
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(theme.snackBarTheme.backgroundColor, Colors.blue);
      expect(theme.inputDecorationTheme.border, isA<OutlineInputBorder>());
      expect(theme.floatingActionButtonTheme.backgroundColor, Colors.blue);
    }
  });

  test('a seed color and a font family', () {
    var theme = themeDataLight1(seedColor: Colors.green, fontFamily: 'Custom');
    expect(theme.brightness, Brightness.light);
    expect(theme.snackBarTheme.backgroundColor, Colors.green);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Custom');
    // A light seed: dark text on it.
    expect(theme.floatingActionButtonTheme.foregroundColor, Colors.black);
  });
}
