import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/switcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The menu item showing [text].
Finder _menuItem(String text) => find.descendant(
  of: find.byType(CheckedPopupMenuItem<Object>),
  matching: find.text(text),
);

/// An app on [controller] showing the switcher widgets.
Widget _app(FestenaoThemeController controller, {Locale? locale}) =>
    FestenaoThemeBuilder(
      controller: controller,
      builder: (context, controller) => MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: controller.theme,
        darkTheme: controller.darkTheme,
        themeMode: controller.mode,
        home: Scaffold(
          appBar: AppBar(
            actions: const [FestenaoThemeModeButton(), FestenaoThemeButton()],
          ),
          body: const SingleChildScrollView(child: FestenaoThemeSettings()),
        ),
      ),
    );

void main() {
  group('choice', () {
    test('encode and decode', () {
      const choice = FestenaoThemeChoice(
        presetId: 'obsidian',
        mode: ThemeMode.dark,
      );
      expect(choice.encode(), 'obsidian|dark');
      expect(FestenaoThemeChoice.decode('obsidian|dark'), choice);
      expect(FestenaoThemeChoice.decode(null), isNull);
      expect(FestenaoThemeChoice.decode('obsidian'), isNull);
      expect(FestenaoThemeChoice.decode('obsidian|dim'), isNull);
      expect(FestenaoThemeChoice.decode('|dark'), isNull);
    });
  });

  group('controller', () {
    test('presets by ids, in that order, unknown skipped', () {
      expect(festenaoThemePresetsByIds(['contrast', 'nope', 'festenao']), [
        festenaoThemeContrast,
        festenaoThemeFestenao,
      ]);
    });

    test('defaults: every preset, the first one, the system mode', () {
      var controller = FestenaoThemeController();
      expect(controller.presets, festenaoThemePresets);
      expect(controller.preset, festenaoThemePresets.first);
      expect(controller.mode, ThemeMode.system);
      expect(controller.theme.brightness, Brightness.light);
      expect(controller.darkTheme.brightness, Brightness.dark);
      // Built once.
      expect(identical(controller.theme, controller.theme), isTrue);
    });

    test('an app list, next preset and mode, saved', () async {
      var store = FestenaoThemeStore.memory();
      var controller = FestenaoThemeController(
        presets: [festenaoThemeArdoise, festenaoThemeObsidian],
        store: store,
      );
      expect(controller.preset, festenaoThemeArdoise);
      expect(() => FestenaoThemeController(presets: []), throwsArgumentError);

      controller.nextPreset();
      expect(controller.preset, festenaoThemeObsidian);
      controller.nextPreset();
      expect(controller.preset, festenaoThemeArdoise);
      controller.selectPreset(festenaoThemeObsidian);
      controller.nextMode();
      expect(controller.mode, ThemeMode.light);
      controller.nextMode();
      expect(controller.mode, ThemeMode.dark);
      await pumpEventQueue();
      expect(await store.read(), 'obsidian|dark');
      controller.nextMode();
      expect(controller.mode, ThemeMode.system);
    });

    test('load: the stored choice, a preset not offered falls back', () async {
      var presets = [festenaoThemeFestenao, festenaoThemePapier];
      var controller = FestenaoThemeController(
        presets: presets,
        store: FestenaoThemeStore.memory('papier|dark'),
      );
      await controller.load();
      expect(controller.preset, festenaoThemePapier);
      expect(controller.mode, ThemeMode.dark);

      controller = FestenaoThemeController(
        presets: presets,
        store: FestenaoThemeStore.from(
          read: () => 'arcade|light',
          write: (_) {},
        ),
      );
      await controller.load();
      expect(controller.preset, festenaoThemeFestenao);
      expect(controller.mode, ThemeMode.light);

      // Nothing stored, garbage: unchanged.
      for (var stored in [null, 'garbage']) {
        controller = FestenaoThemeController(
          presets: presets,
          initial: festenaoThemePapier,
          store: FestenaoThemeStore.memory(stored),
        );
        await controller.load();
        expect(controller.preset, festenaoThemePapier);
        expect(controller.mode, ThemeMode.system);
      }
    });
  });

  group('widgets', () {
    testWidgets('the menu chooses a preset and a mode', (tester) async {
      var controller = FestenaoThemeController(
        presets: festenaoThemePresetsByIds(['festenao', 'ardoise', 'contrast']),
      );
      await tester.pumpWidget(_app(controller));
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).colorScheme.primary,
        festenaoThemeFestenao.palette(Brightness.light).accent,
      );

      await tester.tap(find.byType(FestenaoThemeButton));
      await tester.pumpAndSettle();
      // The offered presets only.
      expect(_menuItem('Ardoise'), findsOneWidget);
      expect(_menuItem('Contraste'), findsOneWidget);
      expect(find.text('Arcade'), findsNothing);
      await tester.tap(_menuItem('Ardoise'));
      await tester.pumpAndSettle();
      expect(controller.preset, festenaoThemeArdoise);
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).colorScheme.primary,
        festenaoThemeArdoise.palette(Brightness.light).accent,
      );

      await tester.tap(find.byType(FestenaoThemeButton));
      await tester.pumpAndSettle();
      await tester.tap(_menuItem('Dark'));
      await tester.pumpAndSettle();
      expect(controller.mode, ThemeMode.dark);
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.dark,
      );
    });

    testWidgets('the settings chips and segments, in French', (tester) async {
      var controller = FestenaoThemeController(
        presets: festenaoThemePresetsByIds(['festenao', 'papier']),
      );
      await tester.pumpWidget(_app(controller, locale: const Locale('fr')));
      expect(find.text('Thème'), findsOneWidget);
      expect(find.text('Apparence'), findsOneWidget);
      expect(find.text(festenaoThemeFestenao.description), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Papier'));
      await tester.pump();
      expect(controller.preset, festenaoThemePapier);
      expect(find.text(festenaoThemePapier.description), findsOneWidget);

      await tester.tap(find.text('Sombre'));
      await tester.pump();
      expect(controller.mode, ThemeMode.dark);

      // The mode button cycles: dark → system.
      await tester.tap(find.byType(FestenaoThemeModeButton));
      await tester.pump();
      expect(controller.mode, ThemeMode.system);
    });

    testWidgets('a single preset: no preset choice', (tester) async {
      var controller = FestenaoThemeController(
        presets: [festenaoThemeObsidian],
      );
      await tester.pumpWidget(_app(controller));
      expect(find.byType(ChoiceChip), findsNothing);
      await tester.tap(find.byType(FestenaoThemeButton));
      await tester.pumpAndSettle();
      expect(_menuItem('Obsidian'), findsNothing);
      expect(_menuItem('Light'), findsOneWidget);
    });
  });
}
