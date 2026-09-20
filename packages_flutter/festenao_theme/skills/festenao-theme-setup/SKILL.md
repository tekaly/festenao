---
name: festenao-theme-setup
description: >-
  Use when giving a Festenao/Tekaly Flutter app its ThemeData: themeData1
  (dark) and themeDataLight1 (light), their Poppins variants
  poppinsThemeData1 / poppinsThemeDataLight1, the seedColor, fontFamily,
  textTheme and brightness parameters, the festenaoPoppinsFontFamily getter
  (google_fonts), colorFestenaoFormBlueSelected, and
  addPoppinsLicense()/poppinsFontFamily from
  package:festenao_theme/theme.dart and
  package:festenao_theme/fonts/poppins/poppins_font.dart.
---

# App theme (festenao_theme)

`festenao_theme` builds the shared Material 3 `ThemeData` of the festenao
apps: a color scheme seeded from one color (festenao blue by default) plus a
handful of fixed rules — floating snack bars, outlined inputs, seed colored
buttons — in a light and a dark flavour, optionally with the Poppins font.

## Guidelines

* Dependency (not on pub.dev, git only):

  ```yaml
  dependencies:
    festenao_theme:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_theme
  ```

* Imports: `package:festenao_theme/theme.dart` for the themes, and
  `package:festenao_theme/fonts/poppins/poppins_font.dart` for
  `poppinsFontFamily` and `addPoppinsLicense()`. Never import
  `package:festenao_theme/src/...`; `theme.dart` deliberately exports only
  `themeData1`, `themeDataLight1`, `poppinsThemeData1`,
  `poppinsThemeDataLight1`, `festenaoPoppinsFontFamily` and
  `colorFestenaoFormBlueSelected` — the other color constants of the source
  are private to the package.
* `ThemeData themeData1({TextTheme? textTheme, String? fontFamily, Brightness?
  brightness, Color? seedColor})` is the one builder; `brightness` defaults to
  `Brightness.dark` and `seedColor` to `Colors.blue`.
  `themeDataLight1({textTheme, fontFamily, seedColor})` is the same call with
  `Brightness.light` — it takes **no** `brightness` parameter. Pass both to
  `MaterialApp(theme: themeDataLight1(), darkTheme: themeData1(), themeMode:
  ...)`; despite the name, `themeData1()` is the *dark* one.
* Everything is derived from `seedColor`: `ColorScheme.fromSeed`, the snack bar
  background, the input `OutlineInputBorder` side, `textTheme.labelSmall`, the
  elevated button and the FAB background. The foreground on those is black or
  white depending on whether the seed is dark, so one `seedColor:` argument
  re-skins the app — do not `copyWith` a different `colorScheme` afterwards,
  the snack bar/button colors would no longer follow it.
* Fixed rules you inherit (and should not re-declare per screen):
  `SnackBarBehavior.floating` with `elevation: 20`,
  `FloatingLabelBehavior.always` and an outlined border on inputs, a grey
  `DividerThemeData`, elevated buttons with `EdgeInsets.symmetric(horizontal:
  32, vertical: 24)` padding and a `FontWeight.w600` label, and
  `VisualDensity.adaptivePlatformDensity`.
* Poppins: `poppinsThemeData1({seedColor})` /
  `poppinsThemeDataLight1({seedColor})` are `themeData1` /`themeDataLight1`
  with `fontFamily: festenaoPoppinsFontFamily`. `festenaoPoppinsFontFamily` is
  `GoogleFonts.poppins().fontFamily`, i.e. a *google_fonts* family — by default
  google_fonts downloads the font at runtime and caches it, so the first frames
  can fall back to the default font and an offline first launch keeps it. Use
  it when you build your own `ThemeData` but want the same family.
* `poppinsFontFamily` (the `'Poppins'` constant in
  `fonts/poppins/poppins_font.dart`) is the plain family name for a
  `fonts:` section registering the `.ttf` files the package ships under
  `lib/fonts/poppins/`; it is **not** interchangeable with
  `festenaoPoppinsFontFamily`, which is whatever google_fonts resolved.
* `addPoppinsLicense()` registers the OFL license text with
  `LicenseRegistry` by reading
  `packages/festenao_theme/fonts/poppins/OFL.txt` from the root bundle (the
  package declares that asset). Call it once in `main`, after
  `WidgetsFlutterBinding.ensureInitialized()`, whenever the app ships Poppins.
* `colorFestenaoFormBlueSelected` is `Colors.blue[300]` and is nullable
  (`Color?`) — it is the highlight of a selected form answer; use `??` or `!`
  where a non-null `Color` is required.
* Anti-patterns: hardcoding `Colors.blue` in widgets instead of reading
  `Theme.of(context).colorScheme`; rebuilding a theme inside `build()` on
  every frame (build it once, e.g. in a final field or a provider);
  calling `poppinsThemeData1()` in a pure `flutter_test` unit test that has no
  asset bundle for google_fonts — use `themeData1(fontFamily: 'Poppins')` or a
  widget test instead.
* Testing: the builders are plain functions, so a `flutter_test` `test()` is
  enough — assert on `theme.brightness`, `theme.snackBarTheme.backgroundColor`,
  `theme.inputDecorationTheme.border`, `theme.textTheme.bodyMedium?.fontFamily`
  as `test/theme_test.dart` does.

## Examples

### MaterialApp with the light and dark themes

```dart
import 'package:festenao_theme/theme.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

/// The themes are built once, not in build().
final _lightTheme = themeDataLight1();
final _darkTheme = themeData1();

/// themeData1() is the dark one, themeDataLight1() the light one.
class MyApp extends StatelessWidget {
  /// Constructor.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'My app',
    theme: _lightTheme,
    darkTheme: _darkTheme,
    themeMode: ThemeMode.system,
    home: const HomeScreen(),
  );
}

/// Everything below reads the theme, never a hardcoded color.
class HomeScreen extends StatelessWidget {
  /// Constructor.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Home')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Outlined, with an always floating label, from the theme.
          const TextField(decoration: InputDecoration(labelText: 'Name')),
          const Divider(),
          ElevatedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              // Floating, seed colored, from the theme.
              const SnackBar(content: Text('Saved')),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () {},
      child: const Icon(Icons.add),
    ),
  );
}
```

### Poppins and a custom seed color

```dart
import 'package:festenao_theme/fonts/poppins/poppins_font.dart';
import 'package:festenao_theme/theme.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  // rootBundle is used to read the license text.
  WidgetsFlutterBinding.ensureInitialized();
  // Register the OFL license of the shipped Poppins font.
  addPoppinsLicense();
  runApp(const MyApp());
}

/// One seed color re-skins everything: scheme, snack bars, inputs, buttons.
final _seedColor = Colors.deepPurple;
final _lightTheme = poppinsThemeDataLight1(seedColor: _seedColor);
final _darkTheme = poppinsThemeData1(seedColor: _seedColor);

/// App using the Poppins themes.
class MyApp extends StatelessWidget {
  /// Constructor.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: _lightTheme,
    darkTheme: _darkTheme,
    home: const Scaffold(body: Center(child: Text('Poppins'))),
  );
}
```

### Building on top of the theme

```dart
import 'package:festenao_theme/theme.dart';
import 'package:flutter/material.dart';

/// Same font and rules, but a text theme of your own and a green seed.
ThemeData buildAppTheme() => themeDataLight1(
  seedColor: Colors.green,
  // The google_fonts family behind the poppins themes.
  fontFamily: festenaoPoppinsFontFamily,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 15),
    titleLarge: TextStyle(fontWeight: FontWeight.w700),
  ),
);

/// A selected form answer, using the exported highlight color.
/// It is nullable (Colors.blue[300]), so provide a fallback.
class FormAnswerTile extends StatelessWidget {
  /// Answer label.
  final String label;

  /// Whether the answer is the selected one.
  final bool selected;

  /// Constructor.
  const FormAnswerTile({
    super.key,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: selected
        ? (colorFestenaoFormBlueSelected ??
              Theme.of(context).colorScheme.primaryContainer)
        : null,
    child: ListTile(title: Text(label)),
  );
}
```

### Testing the theme rules

```dart
import 'package:festenao_theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light and dark share the rules', () {
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

  test('the seed color drives the accents', () {
    // No google_fonts here: a plain family name keeps the test offline.
    var theme = themeDataLight1(seedColor: Colors.green, fontFamily: 'Custom');
    expect(theme.snackBarTheme.backgroundColor, Colors.green);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Custom');
    // A light seed gets dark foregrounds.
    expect(theme.floatingActionButtonTheme.foregroundColor, Colors.black);
  });
}
```
