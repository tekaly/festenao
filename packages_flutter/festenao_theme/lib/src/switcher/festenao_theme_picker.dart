import 'package:material_ui/material_ui.dart';

import '../design/festenao_theme_presets.dart';
import '../design/festenao_tokens.dart';
import 'festenao_theme_controller.dart';
import 'festenao_theme_switcher.dart';

/// What an app adds to the previews of its themes (its blocks, its pegs):
/// drawn under the preview's theme, [width] wide.
typedef FestenaoThemePreviewBuilder = Widget Function(
  BuildContext context,
  double width,
);

/// How the full screen picker shows the themes.
enum FestenaoThemePickerLayout {
  /// Every theme at once, a grid of previews.
  grid,

  /// One theme at a time, big, swiped through.
  carousel,
}

/// A miniature screen in [preset] and [brightness]: its paper, a bar, a
/// card with lines of ink, an accent button, the status colors; [content]
/// (the app's own) inside the card when given. [width] wide, a phone's
/// portrait proportions ([heightOf]).
class FestenaoThemePreview extends StatelessWidget {
  /// The preset shown.
  final FestenaoThemePreset preset;

  /// Light or dark.
  final Brightness brightness;

  /// The width.
  final double width;

  /// The app's own content, in the card.
  final FestenaoThemePreviewBuilder? content;

  /// The controller whose themes are cached, the scope's one when null
  /// (none: built on the fly).
  final FestenaoThemeController? controller;

  /// A preview.
  const FestenaoThemePreview({
    super.key,
    required this.preset,
    required this.brightness,
    this.width = 120,
    this.content,
    this.controller,
  });

  /// The height of a preview [width] wide.
  static double heightOf(double width) => width / 0.62;

  @override
  Widget build(BuildContext context) {
    var controller =
        this.controller ?? FestenaoThemeController.maybeOf(context);
    var theme =
        controller?.themeOf(preset, brightness) ?? preset.themeData(brightness);
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          var t = context.festenao;
          var w = width;
          var h = heightOf(w);
          var unit = w / 24;
          Widget bar(double widthFactor, Color color, {double height = 1}) =>
              Container(
                width: (w - 6 * unit) * widthFactor,
                height: unit * height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(unit),
                ),
              );
          return Semantics(
            label: preset.name,
            child: Container(
              width: w,
              height: h,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: t.paper,
                borderRadius: BorderRadius.circular(unit * 2.2),
                border: Border.all(color: t.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The bar: a title and an action.
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      unit * 2,
                      unit * 2,
                      unit * 2,
                      unit * 1.5,
                    ),
                    child: Row(
                      children: [
                        bar(0.4, t.ink, height: 1.4),
                        const Spacer(),
                        Container(
                          width: unit * 2,
                          height: unit * 2,
                          decoration: BoxDecoration(
                            color: t.ink3,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // The card.
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: unit * 1.5),
                    padding: EdgeInsets.all(unit * 1.5),
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: BorderRadius.circular(unit * 1.6),
                      border: Border.all(color: t.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(0.55, t.ink, height: 1.2),
                        SizedBox(height: unit * 0.9),
                        bar(0.8, t.ink3, height: 0.8),
                        SizedBox(height: unit * 0.6),
                        bar(0.65, t.ink3, height: 0.8),
                        if (content != null) ...[
                          SizedBox(height: unit * 1.2),
                          // Inside the borders of the screen and the card.
                          content!(context, w - 6 * unit - 4),
                        ],
                        SizedBox(height: unit * 1.4),
                        Container(
                          height: unit * 2.6,
                          decoration: BoxDecoration(
                            color: t.accent,
                            borderRadius: BorderRadius.circular(unit * 1.3),
                          ),
                          alignment: Alignment.center,
                          child: bar(0.3, t.onAccent, height: 0.8),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // The status colors and the categories.
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      unit * 2,
                      0,
                      unit * 2,
                      unit * 2,
                    ),
                    child: Row(
                      children: [
                        for (var color in [
                          t.ok,
                          t.warn,
                          t.bad,
                          t.category(0),
                          t.category(1),
                        ])
                          Container(
                            margin: EdgeInsets.only(right: unit * 0.8),
                            width: unit * 2,
                            height: unit * 2,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The brightness [mode] shows in [context] (the platform's for the
/// system mode).
Brightness festenaoBrightnessOf(BuildContext context, ThemeMode mode) =>
    switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };

/// The theme in a settings page, one widget: a preview of the current
/// theme, its name and mode, a button to the next theme (cycling in
/// place), one to the next mode (system, light, dark); a tap opens the full
/// screen picker ([FestenaoThemePickerScreen], in [layout]).
class FestenaoThemeTile extends StatelessWidget {
  /// The controller, the scope's one when null.
  final FestenaoThemeController? controller;

  /// The words, from the locale when null.
  final FestenaoThemeSwitcherTexts? texts;

  /// The app's own content in the previews.
  final FestenaoThemePreviewBuilder? previewContent;

  /// The layout of the picker opened.
  final FestenaoThemePickerLayout layout;

  /// The tile.
  const FestenaoThemeTile({
    super.key,
    this.controller,
    this.texts,
    this.previewContent,
    this.layout = FestenaoThemePickerLayout.grid,
  });

  @override
  Widget build(BuildContext context) {
    var controller = this.controller ?? FestenaoThemeController.of(context);
    var texts = this.texts ?? FestenaoThemeSwitcherTexts.of(context);
    var textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        var t = context.festenao;
        var preset = controller.preset;
        var mode = controller.mode;
        return InkWell(
          key: const ValueKey('festenao_theme_tile'),
          borderRadius: BorderRadius.circular(t.radii.card),
          onTap: () => festenaoShowThemePicker(
            context,
            controller: controller,
            texts: texts,
            previewContent: previewContent,
            layout: layout,
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                FestenaoThemePreview(
                  preset: preset,
                  brightness: festenaoBrightnessOf(context, mode),
                  width: 64,
                  content: previewContent,
                  controller: controller,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(texts.theme, style: textTheme.bodySmall),
                      Text(
                        preset.name,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        preset.descriptionFor(
                          Localizations.maybeLocaleOf(context)?.languageCode,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(color: t.ink2),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        texts.chooseTheme,
                        style: textTheme.labelMedium?.copyWith(
                          color: t.accentText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    if (controller.presets.length > 1)
                      IconButton(
                        key: const ValueKey('festenao_theme_next'),
                        tooltip: texts.nextTheme,
                        icon: const Icon(Icons.autorenew_rounded),
                        onPressed: controller.nextPreset,
                      ),
                    IconButton(
                      key: const ValueKey('festenao_theme_mode'),
                      tooltip: texts.modeLabel(mode),
                      icon: Icon(festenaoThemeModeIcon(mode)),
                      onPressed: controller.nextMode,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Opens the full screen theme picker of [controller] (the scope's one
/// when null).
Future<void> festenaoShowThemePicker(
  BuildContext context, {
  FestenaoThemeController? controller,
  FestenaoThemeSwitcherTexts? texts,
  FestenaoThemePreviewBuilder? previewContent,
  FestenaoThemePickerLayout layout = FestenaoThemePickerLayout.grid,
}) {
  controller ??= FestenaoThemeController.of(context);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => FestenaoThemePickerScreen(
        controller: controller,
        texts: texts,
        previewContent: previewContent,
        layout: layout,
      ),
    ),
  );
}

/// Every theme of [controller], full screen, with a preview; the mode on
/// top. A choice applies at once (the whole app changes behind).
class FestenaoThemePickerScreen extends StatefulWidget {
  /// The controller, the scope's one when null.
  final FestenaoThemeController? controller;

  /// The words, from the locale when null.
  final FestenaoThemeSwitcherTexts? texts;

  /// The app's own content in the previews.
  final FestenaoThemePreviewBuilder? previewContent;

  /// A grid of every theme, or a carousel.
  final FestenaoThemePickerLayout layout;

  /// The picker.
  const FestenaoThemePickerScreen({
    super.key,
    this.controller,
    this.texts,
    this.previewContent,
    this.layout = FestenaoThemePickerLayout.grid,
  });

  @override
  State<FestenaoThemePickerScreen> createState() =>
      _FestenaoThemePickerScreenState();
}

class _FestenaoThemePickerScreenState extends State<FestenaoThemePickerScreen> {
  late final FestenaoThemeController _controller =
      widget.controller ?? FestenaoThemeController.of(context);
  late final PageController _pages = PageController(
    viewportFraction: 0.72,
    initialPage: _controller.presets.indexWhere(
      (preset) => preset.id == _controller.preset.id,
    ),
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var texts = widget.texts ?? FestenaoThemeSwitcherTexts.of(context);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        var mode = _controller.mode;
        var brightness = festenaoBrightnessOf(context, mode);
        return Scaffold(
          appBar: AppBar(title: Text(texts.theme)),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SegmentedButton<ThemeMode>(
                  key: const ValueKey('festenao_theme_modes'),
                  showSelectedIcon: false,
                  segments: [
                    for (var mode in ThemeMode.values)
                      ButtonSegment(
                        value: mode,
                        icon: Icon(festenaoThemeModeIcon(mode)),
                        label: Text(texts.modeLabel(mode)),
                      ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (selection) =>
                      _controller.selectMode(selection.single),
                ),
              ),
              Expanded(
                child: switch (widget.layout) {
                  FestenaoThemePickerLayout.grid => _grid(brightness),
                  FestenaoThemePickerLayout.carousel => _carousel(
                    brightness,
                    texts,
                  ),
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _name(FestenaoThemePreset preset, bool selected) {
    var t = context.festenao;
    var texts = widget.texts ?? FestenaoThemeSwitcherTexts.of(context);
    var name = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected) ...[
          Icon(Icons.check_circle_rounded, size: 18, color: t.accentText),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            preset.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? t.accentText : t.ink,
            ),
          ),
        ),
      ],
    );
    if (!_controller.isDefault(preset)) {
      return name;
    }
    // The app's own default.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        name,
        Text(
          texts.defaultTheme,
          key: ValueKey('festenao_theme_default_${preset.id}'),
          style: TextStyle(fontSize: 11, color: t.ink3),
        ),
      ],
    );
  }

  Widget _grid(Brightness brightness) {
    var presets = _controller.presets;
    return LayoutBuilder(
      builder: (context, constraints) {
        var columns = (constraints.maxWidth / 170).floor().clamp(2, 6);
        var t = context.festenao;
        return GridView.builder(
          key: const ValueKey('festenao_theme_grid'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.5,
          ),
          itemCount: presets.length,
          itemBuilder: (context, index) {
            var preset = presets[index];
            var selected = preset.id == _controller.preset.id;
            return LayoutBuilder(
              builder: (context, cell) {
                var width = cell.maxWidth - 8;
                return InkWell(
                  key: ValueKey('festenao_theme_${preset.id}'),
                  borderRadius: BorderRadius.circular(t.radii.card),
                  onTap: () => _controller.selectPreset(preset),
                  child: Column(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            width / 24 * 2.2 + 4,
                          ),
                          border: Border.all(
                            color: selected ? t.accent : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(1),
                          child: FestenaoThemePreview(
                            preset: preset,
                            brightness: brightness,
                            width: width,
                            content: widget.previewContent,
                            controller: _controller,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _name(preset, selected),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _carousel(Brightness brightness, FestenaoThemeSwitcherTexts texts) {
    var presets = _controller.presets;
    var t = context.festenao;
    var textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = (constraints.maxWidth * 0.72 - 24).clamp(120.0, 320.0);
        var height = FestenaoThemePreview.heightOf(width);
        if (height > constraints.maxHeight - 150) {
          height = constraints.maxHeight - 150;
          width = height * 0.62;
        }
        return Column(
          children: [
            SizedBox(
              height: height + 8,
              child: PageView.builder(
                key: const ValueKey('festenao_theme_carousel'),
                controller: _pages,
                itemCount: presets.length,
                onPageChanged: (_) => setState(() {}),
                itemBuilder: (context, index) => Center(
                  child: GestureDetector(
                    onTap: () => _controller.selectPreset(presets[index]),
                    child: FestenaoThemePreview(
                      preset: presets[index],
                      brightness: brightness,
                      width: width,
                      content: widget.previewContent,
                      controller: _controller,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                var index = _pages.hasClients
                    ? (_pages.page ?? _pages.initialPage.toDouble()).round()
                    : _pages.initialPage;
                var preset = presets[index.clamp(0, presets.length - 1)];
                var selected = preset.id == _controller.preset.id;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _name(preset, selected),
                      const SizedBox(height: 4),
                      Text(
                        preset.descriptionFor(
                          Localizations.maybeLocaleOf(context)?.languageCode,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: textTheme.bodySmall?.copyWith(color: t.ink2),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        key: const ValueKey('festenao_theme_use'),
                        onPressed: selected
                            ? null
                            : () => _controller.selectPreset(preset),
                        child: Text(selected ? texts.current : texts.useTheme),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
