import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/switcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The tile of [controller] in a settings page, the picker in [layout].
Widget _app(
  FestenaoThemeController controller, {
  FestenaoThemePickerLayout layout = FestenaoThemePickerLayout.grid,
  Locale? locale,
}) => FestenaoThemeBuilder(
  controller: controller,
  builder: (context, controller) => MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('fr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: controller.theme,
    darkTheme: controller.darkTheme,
    themeMode: controller.mode,
    home: Scaffold(
      body: ListView(
        children: [
          FestenaoThemeTile(
            layout: layout,
            previewContent: (context, width) => SizedBox(
              key: const ValueKey('app_preview_content'),
              width: width,
              height: width / 6,
            ),
          ),
        ],
      ),
    ),
  ),
);

FestenaoThemeController _controller() => FestenaoThemeController(
  presets: festenaoThemePresets.take(4).toList(),
  store: FestenaoThemeStore.memory(),
);

void main() {
  testWidgets('the tile cycles the themes and the modes', (tester) async {
    var controller = _controller();
    await tester.pumpWidget(_app(controller));
    var first = controller.preset;
    expect(find.text(first.name), findsOneWidget);
    expect(find.byType(FestenaoThemePreview), findsOneWidget);
    expect(find.byKey(const ValueKey('app_preview_content')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('festenao_theme_next')));
    await tester.pumpAndSettle();
    expect(controller.preset.id, isNot(first.id));
    expect(find.text(controller.preset.name), findsOneWidget);

    var mode = controller.mode;
    await tester.tap(find.byKey(const ValueKey('festenao_theme_mode')));
    await tester.pumpAndSettle();
    expect(controller.mode, isNot(mode));
  });

  testWidgets('the grid picker: every theme, a tap applies it', (tester) async {
    var controller = _controller();
    await tester.pumpWidget(_app(controller));
    await tester.tap(find.byKey(const ValueKey('festenao_theme_tile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('festenao_theme_grid')), findsOneWidget);
    var last = controller.presets.last;
    await tester.tap(find.byKey(ValueKey('festenao_theme_${last.id}')));
    await tester.pumpAndSettle();
    expect(controller.preset.id, last.id);
    // The mode, on top.
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(controller.mode, ThemeMode.dark);
  });

  testWidgets('the carousel picker: swipe, then use', (tester) async {
    var controller = _controller();
    await tester.pumpWidget(
      _app(
        controller,
        layout: FestenaoThemePickerLayout.carousel,
        locale: const Locale('fr'),
      ),
    );
    var first = controller.preset;
    await tester.tap(find.byKey(const ValueKey('festenao_theme_tile')));
    await tester.pumpAndSettle();
    expect(find.text('Thème actuel'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('festenao_theme_carousel')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('festenao_theme_use')));
    await tester.pumpAndSettle();
    expect(controller.preset.id, isNot(first.id));
    expect(find.text('Thème actuel'), findsOneWidget);
  });
  testWidgets('the theme builder of the app, in the picker too', (
    tester,
  ) async {
    var built = <String>[];
    var controller = FestenaoThemeController(
      presets: festenaoThemePresets.take(2).toList(),
      themeBuilder: (preset, brightness) {
        built.add('${preset.id}|${brightness.name}');
        return preset
            .themeData(brightness)
            .copyWith(scaffoldBackgroundColor: const Color(0xFF123456));
      },
    );
    expect(controller.theme.scaffoldBackgroundColor, const Color(0xFF123456));
    // Built once.
    expect(controller.theme, same(controller.theme));
    await tester.pumpWidget(_app(controller));
    await tester.tap(find.byKey(const ValueKey('festenao_theme_tile')));
    await tester.pumpAndSettle();
    expect(built, contains('${controller.presets[1].id}|light'));
  });

  group('the app default', () {
    var presets = festenaoThemePresets.take(4).toList();
    var appDefault = presets[2];

    test('a stored preset no longer offered falls back to it', () async {
      var controller = FestenaoThemeController(
        presets: presets,
        initial: appDefault,
        store: FestenaoThemeStore.memory('gone|dark'),
      );
      expect(controller.defaultPreset.id, appDefault.id);
      await controller.load();
      expect(controller.preset.id, appDefault.id);
      expect(controller.mode, ThemeMode.dark);
      controller.selectPreset(presets.first);
      controller.resetToDefault();
      expect(controller.preset.id, appDefault.id);
      expect(controller.mode, ThemeMode.dark);
      // Without an initial one, the first is the default.
      expect(
        FestenaoThemeController(presets: presets).defaultPreset.id,
        presets.first.id,
      );
    });

    testWidgets('the picker marks it', (tester) async {
      var controller = FestenaoThemeController(
        presets: presets,
        initial: appDefault,
      );
      await tester.pumpWidget(_app(controller));
      await tester.tap(find.byKey(const ValueKey('festenao_theme_tile')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('festenao_theme_default_${appDefault.id}')),
        findsOneWidget,
      );
      expect(find.text('Default'), findsOneWidget);
    });
  });
}
