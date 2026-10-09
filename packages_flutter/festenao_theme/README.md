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
  Obsidian, Guinguette, Nocturne) and seed ones (Violet, Teal, Coral, Forest,
  Ocean, Graphite, Lagon).

Apps declare the `Poppins` and `JetBrains Mono` fonts in their own pubspec
(see `example/pubspec.yaml`).

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
