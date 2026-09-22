import 'package:festenao_theme/theme.dart';
import 'package:flutter/material.dart';

/// One theme the demo can be looked at in.
///
/// The explorers take no colour of their own — every badge, border and status
/// line asks the theme for one — so swapping the theme is the way to see that
/// they follow it.
class DemoTheme {
  /// What the menu displays.
  final String name;

  /// A line under it.
  final String description;

  /// The theme itself, built when it is picked.
  final ThemeData Function() build;

  /// Theme [name].
  const DemoTheme({
    required this.name,
    required this.description,
    required this.build,
  });
}

/// The themes the demo offers: the material defaults and the festenao poppins
/// ones, light and dark.
List<DemoTheme> demoThemes() => [
  DemoTheme(
    name: 'Material light',
    description: 'The flutter default, teal seeded',
    build: () =>
        ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
  ),
  DemoTheme(
    name: 'Material dark',
    description: 'The same, in the dark',
    build: () => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
    ),
  ),
  DemoTheme(
    name: 'Festenao poppins light',
    description: 'poppinsThemeDataLight1, the festenao blue',
    build: poppinsThemeDataLight1,
  ),
  DemoTheme(
    name: 'Festenao poppins dark',
    description: 'poppinsThemeData1, the festenao blue',
    build: poppinsThemeData1,
  ),
  DemoTheme(
    name: 'Festenao poppins amber',
    description: 'The poppins rules on another seed',
    build: () => poppinsThemeData1(seedColor: Colors.amber),
  ),
];
