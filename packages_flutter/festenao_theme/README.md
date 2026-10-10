# festenao_theme

```yaml
  festenao_theme:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_theme
```

## Design: presets, palettes, tokens

The design spec behind it: [`doc/design_spec.md`](../../doc/design_spec.md).

`package:festenao_theme/design.dart` builds the look shared by the festenao
apps: a neutral paper and ink, one accent for the action, the selection and
what is live, fixed status and category colours.

```dart
import 'package:festenao_theme/design.dart';

MaterialApp(
  theme: festenaoThemeArcade.themeData(Brightness.light),
  darkTheme: festenaoThemeArcade.themeData(Brightness.dark),
);

// In a widget: the tokens of the current theme.
var t = context.festenao;
Container(color: t.soft(t.ok), child: Text('Arrivé', style: TextStyle(color: t.ok)));
```

- `FestenaoPalette`: the colours of a theme in one brightness (paper, card,
  sunk, lines, ink 1 to 3, accent, status, six categories),
  `FestenaoPalette.fromSeed` for a seed colour on the neutral paper.
- `festenaoThemeDataFromPalette`: the Material theme of a palette, every
  component themed from it, `FestenaoTokens` attached as an extension.
- `FestenaoThemePreset`: a named theme, light and dark. `festenaoThemePresets`
  holds the hand made ones (Festenao, Basalte · Plein jour, Arcade,
  Obsidian, Guinguette, Nocturne, Contraste, Papier, Ardoise) and seed ones
  (Violet, Teal, Coral, Forest, Ocean, Graphite, Lagon).
  - Contraste: black on white (white on black, yellow accent), for the sun
    or a low vision;
  - Papier: cream paper, brown ink, terracotta, for long reading;
  - Ardoise: cool slate and teal, a calm tool (admin, dashboards).
- `festenaoThemePresetsByIds(['festenao', 'obsidian'])`: the presets of
  those ids, in that order, to build the list an app offers.

## Fonts

The themes ask for the bare `Poppins` and `JetBrains Mono` families. The
files are assets of this package: `loadFestenaoFonts()` registers them
under those names at runtime (and adds their licenses). Nothing to declare
in the app pubspec, await it before `runApp`:

```dart
import 'package:festenao_theme/design.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var fonts = loadFestenaoFonts(); // started early, overlaps the other init
  // ... firebase, databases
  await fonts;
  runApp(const MyApp());
}
```

- `loadFestenaoFonts(extra: [poppinsExtraBoldFont])` adds Poppins 800.
- `loadFestenaoFont(jetBrainsMonoFont, family: 'monospace')` registers a
  font under another family name too.
- Text drawn before the load completes uses the platform font; a failure is
  reported (`FlutterError.reportError`), never thrown.
- `flutter test` draws every family as squares until fonts are loaded:
  widget tests are unchanged, a test wanting the real fonts awaits
  `loadFestenaoFonts()` (`test/fonts_test.dart`).

Why not a `fonts:` section: a family declared by a package is only reachable
as `packages/festenao_theme/<family>`, and on the web every declared family is
downloaded before the first frame ([`doc/font_managment.md`](../../doc/font_managment.md)).

## Theme switcher

`package:festenao_theme/switcher.dart` lets the user choose among the
presets the app offers (all by default, or its own list, its own presets
included), and light, dark or the system mode, kept in the app's
preferences.

```dart
import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/switcher.dart';

var controller = FestenaoThemeController(
  presets: festenaoThemePresetsByIds(['festenao', 'ardoise', 'contrast']),
  // One string (`ardoise|dark`), here in tekartik prefs.
  store: FestenaoThemeStore.from(
    read: () => prefs.getString('theme'),
    write: (value) => prefs.setString('theme', value),
  ),
);
await controller.load(); // before runApp: no flash of the default theme

runApp(
  FestenaoThemeBuilder(
    controller: controller,
    builder: (context, controller) => MaterialApp(
      theme: controller.theme,
      darkTheme: controller.darkTheme,
      themeMode: controller.mode,
      home: const HomeScreen(),
    ),
  ),
);

// Anywhere below (the controller comes from the FestenaoThemeScope):
AppBar(actions: const [FestenaoThemeButton()]);  // presets and modes in a menu
const FestenaoThemeModeButton();                 // system → light → dark
const FestenaoThemeSettings();                   // chips and segments, for a settings screen
```

- `FestenaoThemeController`: `presets` (never empty), `preset` (the chosen
  one, the first offered when the stored one is not offered any more),
  `mode`, `theme` / `darkTheme` (built once per preset), `selectPreset`,
  `nextPreset`, `selectMode`, `nextMode`, `load`.
- `FestenaoThemeStore`: `from(read:, write:)` on any preferences, `memory()`
  for tests and demos.
- The widgets speak English, or French under a French locale
  (`FestenaoThemeSwitcherTexts.en` / `.fr`, or `texts:`).
- With a single preset offered, the widgets only offer the mode.
- `FestenaoPresetSwatch`: the accent of a preset on its paper.

## Gallery

`example/` is a gallery of every preset, light and dark, on sample screens
(a festival day, the access of a project, the kit), phone, tablet and desk
layouts.

```bash
cd example
flutter create --platforms=linux,web .   # once: the platform folders are not tracked
flutter run -d linux        # or -d chrome
flutter test tool/screenshot_test.dart   # every preset into .local/themes
python3 -I tool/contact_sheet.py         # side by side sheets + index.html
```
