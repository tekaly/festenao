import 'package:festenao_theme/design.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The WCAG contrast ratio of two opaque colours.
double _contrast(Color a, Color b) {
  var la = a.computeLuminance();
  var lb = b.computeLuminance();
  var light = la > lb ? la : lb;
  var dark = la > lb ? lb : la;
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  group('presets', () {
    test('ids are unique', () {
      var ids = festenaoThemePresets.map((preset) => preset.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(festenaoThemePresetById('arcade'), festenaoThemeArcade);
      expect(festenaoThemePresetById('unknown'), festenaoThemeFestenao);
    });

    for (var preset in festenaoThemePresets) {
      for (var brightness in Brightness.values) {
        group('${preset.id} ${brightness.name}', () {
          var theme = preset.themeData(brightness);
          var tokens = theme.extension<FestenaoTokens>()!;
          var p = tokens.palette;

          test('builds with its tokens', () {
            expect(theme.brightness, brightness);
            expect(p.brightness, brightness);
            expect(theme.scaffoldBackgroundColor, p.paper);
            expect(theme.colorScheme.primary, p.accent);
            expect(theme.colorScheme.surface, p.card);
            expect(theme.cardTheme.color, p.card);
            expect(p.categories, hasLength(6));
            // The surfaces never take the accent (no seed tint).
            expect(theme.appBarTheme.backgroundColor, p.paper);
            expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
          });

          test('every text style has a family', () {
            var styles = theme.textTheme;
            for (var style in [
              styles.displaySmall,
              styles.headlineSmall,
              styles.titleLarge,
              styles.titleMedium,
              styles.bodyLarge,
              styles.bodyMedium,
              styles.bodySmall,
              styles.labelLarge,
              styles.labelMedium,
              styles.labelSmall,
            ]) {
              expect(style?.fontFamily, isNotNull);
            }
          });

          test('text reads on the surfaces', () {
            expect(_contrast(p.ink, p.paper), greaterThanOrEqualTo(7));
            expect(_contrast(p.ink, p.card), greaterThanOrEqualTo(7));
            expect(_contrast(p.ink2, p.card), greaterThanOrEqualTo(4.5));
            expect(_contrast(p.ink3, p.card), greaterThanOrEqualTo(3));
            expect(_contrast(p.accentText, p.card), greaterThanOrEqualTo(3));
            for (var status in [p.ok, p.warn, p.bad, p.info, p.muted]) {
              expect(_contrast(status, p.card), greaterThanOrEqualTo(3));
            }
          });

          test('a button label reads on the accent', () {
            expect(_contrast(p.onAccent, p.accent), greaterThanOrEqualTo(4.5));
          });
        });
      }
    }
  });

  group('tokens', () {
    test('fallback from any theme', () {
      var theme = ThemeData(colorSchemeSeed: Colors.teal);
      var tokens = FestenaoTokens.fallback(theme);
      expect(tokens.accent, theme.colorScheme.primary);
      expect(tokens.card, theme.colorScheme.surface);
    });

    test('soft tints follow the brightness', () {
      var light = festenaoThemeFestenao.palette(Brightness.light);
      var dark = festenaoThemeFestenao.palette(Brightness.dark);
      expect(light.accentSoft.a, closeTo(0.12, 0.01));
      expect(dark.accentSoft.a, closeTo(0.22, 0.01));
    });

    test('a seed preset keeps the neutral paper', () {
      var violet = festenaoThemePresetById('violet');
      expect(
        violet.palette(Brightness.light).paper,
        festenaoNeutralLight.paper,
      );
      expect(violet.palette(Brightness.dark).paper, festenaoNeutralDark.paper);
    });
  });
}
