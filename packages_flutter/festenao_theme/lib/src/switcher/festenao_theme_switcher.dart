import 'package:festenao_theme/src/design/festenao_theme_presets.dart';
import 'package:festenao_theme/src/switcher/festenao_theme_controller.dart';
import 'package:material_ui/material_ui.dart';

/// The words of the switcher widgets, English or French.
class FestenaoThemeSwitcherTexts {
  /// "Theme".
  final String theme;

  /// "Appearance".
  final String appearance;

  /// "System".
  final String system;

  /// "Light".
  final String light;

  /// "Dark".
  final String dark;

  /// The words.
  const FestenaoThemeSwitcherTexts({
    required this.theme,
    required this.appearance,
    required this.system,
    required this.light,
    required this.dark,
  });

  /// English.
  static const en = FestenaoThemeSwitcherTexts(
    theme: 'Theme',
    appearance: 'Appearance',
    system: 'System',
    light: 'Light',
    dark: 'Dark',
  );

  /// French.
  static const fr = FestenaoThemeSwitcherTexts(
    theme: 'Thème',
    appearance: 'Apparence',
    system: 'Système',
    light: 'Clair',
    dark: 'Sombre',
  );

  /// French for a French locale, English otherwise.
  static FestenaoThemeSwitcherTexts of(BuildContext context) =>
      Localizations.maybeLocaleOf(context)?.languageCode == 'fr' ? fr : en;

  /// The name of [mode].
  String modeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => system,
    ThemeMode.light => light,
    ThemeMode.dark => dark,
  };
}

/// The icon of [mode].
IconData festenaoThemeModeIcon(ThemeMode mode) => switch (mode) {
  ThemeMode.system => Icons.brightness_auto_outlined,
  ThemeMode.light => Icons.light_mode_outlined,
  ThemeMode.dark => Icons.dark_mode_outlined,
};

/// The accent of [preset] on its paper, in [brightness] (the one of the
/// current theme by default).
class FestenaoPresetSwatch extends StatelessWidget {
  /// The preset.
  final FestenaoThemePreset preset;

  /// The brightness shown, the current one when null.
  final Brightness? brightness;

  /// Diameter.
  final double size;

  /// A swatch.
  const FestenaoPresetSwatch({
    super.key,
    required this.preset,
    this.brightness,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    var palette = preset.palette(brightness ?? Theme.of(context).brightness);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size / 5.5),
      decoration: BoxDecoration(
        color: palette.paper,
        shape: BoxShape.circle,
        border: Border.all(color: palette.lineStrong),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.accent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// An app bar button: the offered presets and the light, dark or system
/// mode in one menu. With a single preset, only the modes.
///
/// [controller] defaults to the one of the [FestenaoThemeScope] above.
class FestenaoThemeButton extends StatelessWidget {
  /// The controller, the scope's one when null.
  final FestenaoThemeController? controller;

  /// The words, from the locale when null.
  final FestenaoThemeSwitcherTexts? texts;

  /// The button.
  const FestenaoThemeButton({super.key, this.controller, this.texts});

  @override
  Widget build(BuildContext context) {
    var controller = this.controller ?? FestenaoThemeController.of(context);
    var texts = this.texts ?? FestenaoThemeSwitcherTexts.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        var current = controller.preset;
        var mode = controller.mode;
        return PopupMenuButton<Object>(
          tooltip: controller.presets.length > 1
              ? '${texts.theme}: ${current.name}'
              : texts.appearance,
          icon: const Icon(Icons.palette_outlined),
          onSelected: (value) {
            if (value is FestenaoThemePreset) {
              controller.selectPreset(value);
            } else if (value is ThemeMode) {
              controller.selectMode(value);
            }
          },
          itemBuilder: (context) => [
            if (controller.presets.length > 1) ...[
              for (var preset in controller.presets)
                CheckedPopupMenuItem<Object>(
                  value: preset,
                  checked: preset.id == current.id,
                  child: Row(
                    children: [
                      FestenaoPresetSwatch(preset: preset),
                      const SizedBox(width: 12),
                      Flexible(child: Text(preset.name)),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
            ],
            for (var value in ThemeMode.values)
              CheckedPopupMenuItem<Object>(
                value: value,
                checked: value == mode,
                child: Row(
                  children: [
                    Icon(festenaoThemeModeIcon(value)),
                    const SizedBox(width: 12),
                    Text(texts.modeLabel(value)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// An app bar button cycling system, light and dark, its icon showing the
/// current mode.
class FestenaoThemeModeButton extends StatelessWidget {
  /// The controller, the scope's one when null.
  final FestenaoThemeController? controller;

  /// The words, from the locale when null.
  final FestenaoThemeSwitcherTexts? texts;

  /// The button.
  const FestenaoThemeModeButton({super.key, this.controller, this.texts});

  @override
  Widget build(BuildContext context) {
    var controller = this.controller ?? FestenaoThemeController.of(context);
    var texts = this.texts ?? FestenaoThemeSwitcherTexts.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => IconButton(
        tooltip: '${texts.appearance}: ${texts.modeLabel(controller.mode)}',
        icon: Icon(festenaoThemeModeIcon(controller.mode)),
        onPressed: controller.nextMode,
      ),
    );
  }
}

/// A settings section: the offered presets as chips (the chosen one with
/// its description) and the mode as a segmented button.
class FestenaoThemeSettings extends StatelessWidget {
  /// The controller, the scope's one when null.
  final FestenaoThemeController? controller;

  /// The words, from the locale when null.
  final FestenaoThemeSwitcherTexts? texts;

  /// The section.
  const FestenaoThemeSettings({super.key, this.controller, this.texts});

  @override
  Widget build(BuildContext context) {
    var controller = this.controller ?? FestenaoThemeController.of(context);
    var texts = this.texts ?? FestenaoThemeSwitcherTexts.of(context);
    var textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        var current = controller.preset;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.presets.length > 1) ...[
              Text(texts.theme, style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var preset in controller.presets)
                    ChoiceChip(
                      avatar: FestenaoPresetSwatch(preset: preset, size: 18),
                      label: Text(preset.name),
                      selected: preset.id == current.id,
                      showCheckmark: false,
                      onSelected: (_) => controller.selectPreset(preset),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(current.description, style: textTheme.bodySmall),
              const SizedBox(height: 16),
            ],
            Text(texts.appearance, style: textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                for (var mode in ThemeMode.values)
                  ButtonSegment(
                    value: mode,
                    icon: Icon(festenaoThemeModeIcon(mode)),
                    label: Text(texts.modeLabel(mode)),
                  ),
              ],
              selected: {controller.mode},
              onSelectionChanged: (selection) =>
                  controller.selectMode(selection.single),
            ),
          ],
        );
      },
    );
  }
}
