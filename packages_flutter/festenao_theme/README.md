# festenao_theme

The look of the festenao Flutter apps: theme presets (light and dark), the
design tokens a screen reads (`context.festenao`), a small widget kit, a
theme switcher kept in the app preferences, and the Poppins and JetBrains
Mono fonts, registered at runtime.

Flutter only, on [`material_ui`](https://pub.dev/packages/material_ui) (the
Material library that replaces `package:flutter/material.dart`). Every
platform (Android, iOS, macOS, Linux, Windows, web): plain Dart and font
assets, no plugin.

## Getting started

Not on pub.dev, add it as a git dependency, with `material_ui`:

```yaml
dependencies:
  material_ui: ">=1.5.0"
  festenao_theme:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_theme
```

Load the fonts before `runApp`, then give the `MaterialApp` the light and dark
theme of a preset:

```dart
import 'package:festenao_theme/design.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Poppins and JetBrains Mono, under the names the themes ask for.
  await loadFestenaoFonts();
  runApp(const MyApp());
}

// Built once, not in build().
final _lightTheme = festenaoThemeFestenao.themeData(Brightness.light);
final _darkTheme = festenaoThemeFestenao.themeData(Brightness.dark);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: _lightTheme,
    darkTheme: _darkTheme,
    home: const HomeScreen(),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The tokens of the current theme: right in every preset and brightness.
    var t = context.festenao;
    return Scaffold(
      appBar: AppBar(title: const Text('Festival')),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          color: t.soft(t.ok),
          child: Text('Arrived', style: TextStyle(color: t.ok)),
        ),
      ),
    );
  }
}
```

## Libraries

| Import | What | Use it for |
|---|---|---|
| `package:festenao_theme/design.dart` | Presets, palettes, tokens, the theme builder; re-exports the font loader | Every app: the theme and the tokens |
| `package:festenao_theme/kit.dart` | `Fk*` widgets on the tokens (page, header, cards, rows, pills, grid) | Screens that follow the theme without styling by hand |
| `package:festenao_theme/switcher.dart` | `FestenaoThemeController`, its store, the switcher buttons and settings | Letting the user choose a preset and light, dark or system |
| `package:festenao_theme/fonts.dart` | The font families, `loadFestenaoFonts`, the licenses | Only when you need the family names (`poppinsFontFamily`) |
| `package:festenao_theme/theme.dart` | The older seed theme (`themeData1`, `themeDataLight1`, Poppins variants) | Existing apps not moved to the presets yet |
| `package:festenao_theme/legacy_material.dart` | `legacyMaterialScreen`, `legacyMaterialLeaf` | Hosting a third party widget still on `package:flutter/material.dart` |

## Design: presets, palettes, tokens

The design spec behind it: [`doc/design_spec.md`](../../doc/design_spec.md).
A neutral paper and ink, one accent for the action, the selection and what
is live, fixed status and category colours.

- `FestenaoThemePreset`: a named theme, light and dark; `themeData(brightness)`
  builds its `ThemeData` (each call builds a new one: keep it).
  `festenaoThemePresets` holds the hand made ones (Festenao, Basalte · Plein
  jour, Arcade, Obsidian, Guinguette, Nocturne, Contraste, Papier, Ardoise)
  and the seed ones (Violet, Teal, Coral, Forest, Ocean, Graphite, Lagon).
  - Contraste: black on white (white on black, yellow accent), for the sun
    or a low vision;
  - Papier: cream paper, brown ink, terracotta, for long reading;
  - Ardoise: cool slate and teal, a calm tool (admin, dashboards).
- `festenaoThemePresetById('ardoise')`: one preset (the Festenao one for an
  unknown id); `festenaoThemePresetsByIds(['festenao', 'obsidian'])`: the
  presets of those ids, in that order, the list an app offers.
- `FestenaoThemePreset.seed(id:, name:, description:, seed:)`: your own
  preset, the accent derived from a seed colour on the neutral paper.
- `FestenaoPalette`: the colours of a theme in one brightness (paper, card,
  sunk, lines, ink 1 to 3, accent, status, six categories);
  `FestenaoPalette.fromSeed` for a seed colour on the neutral paper.
- `festenaoThemeDataFromPalette(palette)`: the Material theme of a palette,
  every component themed from it, `FestenaoTokens` attached as an extension.
- `FestenaoTokens` (`context.festenao`): the palette (`t.ink`, `t.ok`,
  `t.accent`, `t.soft(color)`, `t.category(i)`), the radii (`t.radii.card`),
  `t.cardShadow`, `t.labelStyle(context)`. Under a theme not built by
  festenao, they are derived from its colour scheme.

## Kit

`package:festenao_theme/kit.dart`: widgets drawn with the tokens, so a screen
follows the preset and the brightness.

```dart
import 'package:festenao_theme/kit.dart';
import 'package:material_ui/material_ui.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Access')),
    body: FkPage(
      children: [
        FkHeader(
          title: 'Members',
          subtitle: '2 people',
          actions: [
            FilledButton(onPressed: () {}, child: const Text('Invite')),
          ],
        ),
        const FkGrid(
          children: [
            FkStatTile(label: 'Arrived', value: '12', suffix: '/ 40', icon: Icons.check, progress: 0.3, status: FkStatus.ok),
            FkStatTile(label: 'To check', value: '3', icon: Icons.flag, status: FkStatus.warn),
          ],
        ),
        const FkSectionTitle('People'),
        FkListCard(
          children: [
            FkRow(
              leading: const FkAvatar('Camille Martin'),
              title: 'Camille Martin',
              subtitle: 'camille@example.com',
              badges: const [FkStatusPill('Admin', status: FkStatus.accent)],
              onTap: () {},
            ),
            const FkRow(leading: FkAvatar('Ines', category: 1), title: 'Ines'),
          ],
        ),
      ],
    ),
  );
}
```

- Layout: `FkPage` (scrolls, pads, caps the width), `FkHeader`,
  `FkSectionTitle`, `FkGrid` (1 to `maxColumns` columns of at least
  `minTileWidth`), `FkTwoPanes` (side by side from 860 wide, stacked below),
  `FkWidth.of(width)` (compact, medium from 600, expanded from 1000).
- Content: `FkCard`, `FkListCard` with `FkRow` / `FkKeyValueRow`,
  `FkStatusPill` (`FkStatus.ok`, `warn`, `bad`, `info`, `muted`, `accent`),
  `FkIconBox`, `FkAvatar` (initials from `fkInitials`), `FkStatTile`,
  `FkTimeTile`, `FkEmpty`.

## Fonts

The themes ask for the bare `Poppins` and `JetBrains Mono` families. The
files are assets of this package: `loadFestenaoFonts()` registers them
under those names at runtime (and adds their licenses). Nothing to declare
in the app pubspec, await it before `runApp`:

```dart
import 'package:festenao_theme/design.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var fonts = loadFestenaoFonts(); // started early, overlaps the other init
  // ... firebase, databases
  await fonts;
  runApp(const Placeholder());
}
```

- `loadFestenaoFonts(extra: [poppinsExtraBoldFont])` adds Poppins 800.
- `loadFestenaoFont(jetBrainsMonoFont, family: 'monospace')` registers a
  font under another family name too.
- Text drawn before the load completes uses the platform font; a failure is
  reported (`FlutterError.reportError`), never thrown, and not retried.
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
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_prefs/prefs.dart';

Future<void> runThemedApp(Prefs prefs) async {
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
        home: Scaffold(
          // Anywhere below, the controller comes from the FestenaoThemeScope.
          appBar: AppBar(
            title: const Text('Settings'),
            actions: const [
              FestenaoThemeButton(), // presets and modes in a menu
              FestenaoThemeModeButton(), // system, light, dark
            ],
          ),
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: FestenaoThemeSettings(), // chips and segments
          ),
        ),
      ),
    ),
  );
}
```

- `FestenaoThemeController`: `presets` (never empty), `preset` (the chosen
  one, the first offered when the stored one is not offered any more),
  `mode`, `theme` / `darkTheme` (built once per preset), `selectPreset`,
  `nextPreset`, `selectMode`, `nextMode`, `load`.
- `FestenaoThemeStore`: `from(read:, write:)` on any preferences, `memory()`
  for tests and demos. Each change is written at once, not awaited.
- The widgets speak English, or French under a French locale
  (`FestenaoThemeSwitcherTexts.en` / `.fr`, or `texts:`).
- With a single preset offered, the widgets only offer the mode.
- `FestenaoPresetSwatch`: the accent of a preset on its paper.

## Older theme (`theme.dart`)

`themeData1()` (dark, despite its name) and `themeDataLight1()` build a
Material 3 theme from one seed colour (Material blue by default) with
floating snack bars, outlined inputs and seed coloured buttons;
`poppinsThemeData1()` / `poppinsThemeDataLight1()` add the Poppins family
(`loadFestenaoFonts()` first). New code uses the presets of `design.dart`.

## Pitfalls

- Import `package:material_ui/material_ui.dart`, not
  `package:flutter/material.dart`: the types differ, a `ThemeData` of this
  package does not fit the `MaterialApp` of `flutter/material.dart` (and its
  `Colors.blue` is not equal to material_ui's). A third party widget still on
  `flutter/material.dart` goes in `legacyMaterialScreen` / `legacyMaterialLeaf`.
- `controller.load()` replaces the current choice: call it before `runApp`,
  not after the user could change the theme.
- `FkGrid` (and the other `Fk*` layouts built on a `LayoutBuilder`) needs a
  bounded width: in a horizontal `ListView` or an unconstrained `Row` child,
  `FkGrid` throws (`Infinity` columns). Wrap it in a `SizedBox` or an
  `Expanded`.
- The tokens switch at the middle of a theme animation (they do not fade
  with the Material colours).
- Build the `ThemeData` once (a final field, the controller), not in
  `build()`.

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

Package skill: [`skills/festenao-theme-setup/SKILL.md`](skills/festenao-theme-setup/SKILL.md).
