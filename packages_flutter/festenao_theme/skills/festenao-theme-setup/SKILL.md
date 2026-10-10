---
name: festenao-theme-setup
description: >-
  Use when giving a Festenao/Tekaly Flutter app its ThemeData: themeData1
  (dark) and themeDataLight1 (light), their Poppins variants
  poppinsThemeData1 / poppinsThemeDataLight1, the seedColor, fontFamily,
  textTheme and brightness parameters, the festenaoPoppinsFontFamily
  constant, loadFestenaoFonts() registering the bundled Poppins and
  JetBrains Mono under their bare names at runtime (nothing in the app
  pubspec), colorFestenaoFormBlueSelected, and
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
  `poppinsThemeDataLight1`, `festenaoPoppinsFontFamily`,
  `colorFestenaoFormBlueSelected` and the font loader (`loadFestenaoFonts`,
  `loadFestenaoFont`, `poppinsFont`, `poppinsExtraBoldFont`,
  `jetBrainsMonoFont`) — the other color constants of the source are
  private to the package.
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
  with `fontFamily: festenaoPoppinsFontFamily`, the bare `'Poppins'` family
  (same constant as `poppinsFontFamily`). Use it when you build your own
  `ThemeData` but want the same family.
* Fonts: the package ships Poppins (400, italic, 500, 600, 700, and 800 on
  demand) and JetBrains Mono NL (400 to 700) as plain assets.
  `await loadFestenaoFonts()` in `main`, after
  `WidgetsFlutterBinding.ensureInitialized()` and before `runApp`, registers
  them under the bare names `Poppins` and `JetBrains Mono` (one
  `FontLoader` per family, once) and adds their licenses. The app pubspec
  declares nothing. Until it completes text uses the platform font; a
  failure is reported with `FlutterError.reportError`, never thrown.
  `loadFestenaoFonts(extra: [poppinsExtraBoldFont])` adds weight 800,
  `loadFestenaoFont(jetBrainsMonoFont, family: 'monospace')` registers a
  font under another name too.
* `addPoppinsLicense()` registers the OFL license text with
  `LicenseRegistry` by reading
  `packages/festenao_theme/fonts/poppins/OFL.txt` from the root bundle (the
  package declares that asset). `loadFestenaoFonts()` calls it; it adds the
  license once however often it is called.
* `colorFestenaoFormBlueSelected` is `Colors.blue[300]` and is nullable
  (`Color?`) — it is the highlight of a selected form answer; use `??` or `!`
  where a non-null `Color` is required.
* Anti-patterns: hardcoding `Colors.blue` in widgets instead of reading
  `Theme.of(context).colorScheme`; rebuilding a theme inside `build()` on
  every frame (build it once, e.g. in a final field or a provider);
  declaring Poppins in the app pubspec `fonts:` (the loader does it) or
  using `TextStyle(fontFamily: 'Poppins', package: 'festenao_theme')`: a
  package prefix leaks into every bare family merged under it
  (`'monospace'` becomes `packages/festenao_theme/monospace`).
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
import 'package:festenao_theme/theme.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  // rootBundle is used to read the font files and the license text.
  WidgetsFlutterBinding.ensureInitialized();
  // Register Poppins and JetBrains Mono under their bare names, with their
  // OFL licenses: nothing to declare in the app pubspec.
  await loadFestenaoFonts();
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
  // The bare Poppins family, registered by loadFestenaoFonts().
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
    // A plain family name: the theme only records it.
    var theme = themeDataLight1(seedColor: Colors.green, fontFamily: 'Custom');
    expect(theme.snackBarTheme.backgroundColor, Colors.green);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Custom');
    // A light seed gets dark foregrounds.
    expect(theme.floatingActionButtonTheme.foregroundColor, Colors.black);
  });
}
```
