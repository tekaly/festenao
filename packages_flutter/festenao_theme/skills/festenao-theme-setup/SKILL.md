---
name: festenao-theme-setup
description: >-
  Use when giving a Festenao/Tekaly Flutter app (material_ui) its look with
  festenao_theme: the presets of package:festenao_theme/design.dart
  (festenaoThemePresets, festenaoThemeFestenao, festenaoThemePresetById,
  festenaoThemePresetsByIds, FestenaoThemePreset.seed, preset.themeData),
  FestenaoPalette and festenaoThemeDataFromPalette, the FestenaoTokens read
  with context.festenao (ink, ok, warn, bad, accent, soft, category, radii),
  the Fk* widget kit of kit.dart (FkPage, FkHeader, FkCard, FkListCard, FkRow,
  FkStatusPill, FkGrid, FkStatTile, FkAvatar), the theme switcher of
  switcher.dart (FestenaoThemeController, FestenaoThemeStore,
  FestenaoThemeBuilder, FestenaoThemeButton, FestenaoThemeModeButton,
  FestenaoThemeSettings), loadFestenaoFonts() registering Poppins and
  JetBrains Mono at runtime, and the older seed theme of theme.dart
  (themeData1, themeDataLight1, poppinsThemeData1).
---

# App theme (festenao_theme)

`festenao_theme` gives the festenao Flutter apps one look: named presets
(light and dark) on a neutral paper and ink with one accent, the design
tokens a screen reads, a small widget kit drawn with them, a theme switcher
kept in the app preferences, and the Poppins and JetBrains Mono fonts. It is
built on `material_ui`, the Material library that replaces
`package:flutter/material.dart`. Every Flutter platform, no plugin.

## Guidelines

* Dependency (not on pub.dev, git only), with `material_ui`:

  ```yaml
  dependencies:
    material_ui: ">=1.5.0"
    festenao_theme:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_theme
  ```

* Import `package:material_ui/material_ui.dart`, never
  `package:flutter/material.dart`: the types differ (a `ThemeData` of this
  package is not the `ThemeData` of `flutter/material.dart`, their
  `Colors.blue` and enums are not equal). A third party widget still on
  `flutter/material.dart` goes in `legacyMaterialScreen(screen)` /
  `legacyMaterialLeaf(widget)` of `package:festenao_theme/legacy_material.dart`.
* Libraries: `design.dart` (presets, palettes, tokens, theme builder, and the
  font loader re-exported), `kit.dart` (the `Fk*` widgets), `switcher.dart`
  (controller and widgets), `fonts.dart` (family names such as
  `poppinsFontFamily`, licenses), `theme.dart` (the older seed theme). Never
  import `package:festenao_theme/src/...`.
* Fonts: `await loadFestenaoFonts()` in `main`, after
  `WidgetsFlutterBinding.ensureInitialized()` and before `runApp` (start it
  early, it can overlap the other init). It registers Poppins (400, italic,
  500, 600, 700) and JetBrains Mono NL (400 to 700) under the bare names
  `Poppins` and `JetBrains Mono`, once, and adds their OFL licenses. The app
  pubspec declares nothing. Text drawn before it completes uses the platform
  font; a failure is reported with `FlutterError.reportError`, never thrown,
  not retried. `loadFestenaoFonts(extra: [poppinsExtraBoldFont])` adds 800;
  `loadFestenaoFont(jetBrainsMonoFont, family: 'monospace')` registers a font
  under another name too. Do not declare these fonts in a `fonts:` section,
  nor use `TextStyle(package: 'festenao_theme')`.
* Presets: `festenaoThemePresets` (Festenao, Basalte, Arcade, Obsidian,
  Guinguette, Nocturne, Contraste `contrast`, Papier, Ardoise, then the seed
  ones Violet, Teal, Coral, Forest, Ocean, Graphite, Lagon), each a
  `FestenaoThemePreset` with an `id` (stored in preferences), a `name`, a
  `description`. `preset.themeData(Brightness.light)` builds a new
  `ThemeData` on each call: build it once (a final field, or the
  controller). `festenaoThemePresetById(id)` gives the Festenao preset for an
  unknown id; `festenaoThemePresetsByIds(['festenao', 'obsidian'])` skips the
  unknown ones. Your own: `FestenaoThemePreset.seed(id:, name:, description:,
  seed:, variant:)`, or hand made with `light:` / `dark:` palettes.
* Tokens: `context.festenao` (or `FestenaoTokens.of(context)`) gives the
  palette of the current theme: `ink`, `ink2`, `ink3`, `paper`, `card`,
  `sunk`, `line`, `lineStrong`, `accent`, `onAccent`, `accentText`, `ok`,
  `warn`, `bad`, `info`, `muted`, `soft(color)` (a tint for a badge
  background), `category(i)` (six colours, cycling), `radii`, `cardShadow`,
  `labelStyle(context)`, `upperLabels`. Read them instead of hard coded
  colours: a screen then follows every preset and brightness. Under a theme
  not built by festenao they are derived from its colour scheme.
* Kit (`kit.dart`): `FkPage(children:)` (scrolls, pads, caps the width),
  `FkHeader(title:, subtitle:, badge:, actions:)`, `FkSectionTitle`,
  `FkCard`, `FkListCard(children: [FkRow(...), FkKeyValueRow(...)])`,
  `FkStatusPill(label, status: FkStatus.ok)`, `FkIconBox`, `FkAvatar(name,
  category:)`, `FkStatTile`, `FkTimeTile`, `FkGrid(children:, minTileWidth:,
  maxColumns:)`, `FkTwoPanes(main:, side:)`, `FkEmpty`, `fkInitials(name)`,
  `FkWidth.of(width)` (compact, medium from 600, expanded from 1000). The
  layouts use a `LayoutBuilder`: they need a bounded width (`FkGrid` in a
  horizontal list throws, `Infinity` columns).
* Switcher (`switcher.dart`): `FestenaoThemeController(presets:, initial:,
  mode:, store:)` (presets never empty, all by default), `await
  controller.load()` before `runApp` (it replaces the current choice: later,
  it would undo a change of the user), then `FestenaoThemeBuilder(controller:,
  builder: (context, controller) => MaterialApp(theme: controller.theme,
  darkTheme: controller.darkTheme, themeMode: controller.mode))`. Below it,
  `FestenaoThemeButton()` (presets and modes in a menu),
  `FestenaoThemeModeButton()` (system, light, dark) and
  `FestenaoThemeSettings()` find the controller in the `FestenaoThemeScope`.
  `FestenaoThemeStore.from(read:, write:)` keeps one string (`ardoise|dark`)
  in any preferences, `memory()` for tests; writes are not awaited. A stored
  preset not offered any more falls back to the first offered. Texts in
  English or French (locale), or `texts:`.
* Older seed theme (`theme.dart`), for apps not moved to the presets:
  `themeData1({textTheme, fontFamily, brightness, seedColor})` is **dark** by
  default, `themeDataLight1({textTheme, fontFamily, seedColor})` the light
  one (no `brightness` parameter); `seedColor` defaults to `Colors.blue`.
  Everything follows the seed: `ColorScheme.fromSeed`, floating snack bars
  (`elevation: 20`) on the seed colour, `FloatingLabelBehavior.always` and
  an outlined input border, the `labelSmall` colour, elevated buttons
  (`horizontal: 32, vertical: 24` padding, w600 label) and the FAB, with a
  black or white foreground; a grey divider;
  `VisualDensity.adaptivePlatformDensity`. `poppinsThemeData1()` /
  `poppinsThemeDataLight1()` add `fontFamily: festenaoPoppinsFontFamily`
  (`'Poppins'`, call `loadFestenaoFonts()` first).
  `colorFestenaoFormBlueSelected` is `Colors.blue[300]`, a nullable `Color?`.
  `theme.dart` also exports the font loader and `addPoppinsLicense` /
  `addJetBrainsMonoLicense`; the other colours of its source are not
  exported.
* Tests: `flutter test` draws every family as squares until the fonts are
  loaded; widget tests need nothing, a test wanting the real fonts awaits
  `loadFestenaoFonts()`. Theme builders are plain functions, a `test()` is
  enough.

## Examples

### An app on a preset, with the switcher

```dart
import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/switcher.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var fonts = loadFestenaoFonts();
  var controller = FestenaoThemeController(
    presets: festenaoThemePresetsByIds(['festenao', 'ardoise', 'contrast']),
    // FestenaoThemeStore.from(read:, write:) on the app preferences.
    store: FestenaoThemeStore.memory(),
  );
  await controller.load();
  await fonts;
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
}

/// Reads the tokens, never a hard coded colour.
class HomeScreen extends StatelessWidget {
  /// Constructor.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: const [FestenaoThemeButton()],
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.soft(t.ok),
            borderRadius: BorderRadius.circular(t.radii.pill),
          ),
          child: Text('Arrived', style: TextStyle(color: t.ok)),
        ),
      ),
    );
  }
}
```

### A screen with the kit

```dart
import 'package:festenao_theme/kit.dart';
import 'package:material_ui/material_ui.dart';

/// A page of members: header, stat tiles, a list card.
class MembersScreen extends StatelessWidget {
  /// Constructor.
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
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
            FkStatTile(
              label: 'Arrived',
              value: '12',
              suffix: '/ 40',
              icon: Icons.check,
              progress: 0.3,
              status: FkStatus.ok,
            ),
            FkStatTile(
              label: 'To check',
              value: '3',
              icon: Icons.flag,
              status: FkStatus.warn,
            ),
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
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            const FkKeyValueRow(label: 'Id', value: 'a1b2c3'),
          ],
        ),
      ],
    ),
  );
}
```

### A preset of your own

```dart
import 'package:festenao_theme/design.dart';
import 'package:material_ui/material_ui.dart';

/// A seed preset: the accent derived from one colour on the neutral paper.
const myPreset = FestenaoThemePreset.seed(
  id: 'mine',
  name: 'Mine',
  description: 'A green accent',
  seed: Color(0xFF2E7D32),
);

/// The presets offered: two festenao ones and mine.
final myPresets = [
  ...festenaoThemePresetsByIds(['festenao', 'contrast']),
  myPreset,
];

/// A theme from a palette tuned by hand.
final myTheme = festenaoThemeDataFromPalette(
  festenaoNeutralLight.copyWith(
    accent: const Color(0xFF7048C2),
    accentText: const Color(0xFF5A35A8),
  ),
  radii: const FestenaoRadii(card: 20),
);
```

### The older seed theme

```dart
import 'package:festenao_theme/theme.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadFestenaoFonts();
  runApp(const MyApp());
}

/// themeData1 is the dark one, themeDataLight1 the light one; built once.
final _lightTheme = poppinsThemeDataLight1(seedColor: Colors.deepPurple);
final _darkTheme = poppinsThemeData1(seedColor: Colors.deepPurple);

/// App using the seed theme.
class MyApp extends StatelessWidget {
  /// Constructor.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: _lightTheme,
    darkTheme: _darkTheme,
    home: Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Container(
        // Nullable: Colors.blue[300].
        color: colorFestenaoFormBlueSelected ?? Colors.blue,
        child: const ListTile(title: Text('Selected answer')),
      ),
    ),
  );
}
```

### Testing

```dart
import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/switcher.dart';
import 'package:festenao_theme/theme.dart' show themeData1, themeDataLight1;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('a preset carries its tokens', () {
    var theme = festenaoThemeArdoise.themeData(Brightness.dark);
    var tokens = theme.extension<FestenaoTokens>()!;
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, tokens.accent);
  });

  test('the switcher keeps the choice', () async {
    var store = FestenaoThemeStore.memory();
    var controller = FestenaoThemeController(
      presets: [festenaoThemeArdoise, festenaoThemeObsidian],
      store: store,
    );
    controller.selectPreset(festenaoThemeObsidian);
    controller.selectMode(ThemeMode.dark);
    await pumpEventQueue(); // the write is not awaited
    expect(await store.read(), 'obsidian|dark');
  });

  test('the older theme follows the seed', () {
    expect(themeData1().brightness, Brightness.dark);
    var light = themeDataLight1(seedColor: Colors.green);
    expect(light.snackBarTheme.backgroundColor, Colors.green);
    expect(light.snackBarTheme.behavior, SnackBarBehavior.floating);
  });
}
```
