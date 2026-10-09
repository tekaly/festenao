import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/kit.dart';
import 'package:festenao_theme_example/src/gallery_app.dart';
import 'package:festenao_theme_example/src/page_access.dart';
import 'package:festenao_theme_example/src/page_kit.dart';
import 'package:festenao_theme_example/src/page_overview.dart';
import 'package:material_ui/material_ui.dart';

/// The frame: a bottom bar on a phone, a rail on a tablet, a side panel
/// with the app identity on a desk; the theme picker in the app bar.
class GalleryShell extends StatelessWidget {
  /// The frame.
  const GalleryShell({super.key});

  @override
  Widget build(BuildContext context) {
    var controller = GalleryScope.of(context);
    var state = controller.value;
    var body = switch (state.page) {
      GalleryPage.overview => const OverviewPage(),
      GalleryPage.access => const AccessPage(),
      GalleryPage.kit => const FkPageView(),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = FkWidth.of(constraints.maxWidth);
        var appBar = AppBar(
          titleSpacing: width == FkWidth.compact ? 16 : 24,
          title: width == FkWidth.expanded
              ? Text(state.page.label)
              : const _AppTitle(),
          actions: [
            ThemeActions(compact: width == FkWidth.compact),
            const SizedBox(width: 8),
          ],
        );
        switch (width) {
          case FkWidth.compact:
            return Scaffold(
              appBar: appBar,
              body: body,
              bottomNavigationBar: NavigationBar(
                selectedIndex: state.page.index,
                onDestinationSelected: (index) =>
                    controller.selectPage(GalleryPage.values[index]),
                destinations: [
                  for (var page in GalleryPage.values)
                    NavigationDestination(
                      icon: Icon(page.icon),
                      label: page.label,
                    ),
                ],
              ),
            );
          case FkWidth.medium:
            return Scaffold(
              appBar: appBar,
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: state.page.index,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (index) =>
                        controller.selectPage(GalleryPage.values[index]),
                    destinations: [
                      for (var page in GalleryPage.values)
                        NavigationRailDestination(
                          icon: Icon(page.icon),
                          label: Text(page.label),
                        ),
                    ],
                  ),
                  VerticalDivider(width: 1, color: context.festenao.line),
                  Expanded(child: body),
                ],
              ),
            );
          case FkWidth.expanded:
            return Scaffold(
              body: Row(
                children: [
                  const _SidePanel(),
                  VerticalDivider(width: 1, color: context.festenao.line),
                  Expanded(
                    child: Column(
                      children: [
                        appBar,
                        Expanded(child: body),
                      ],
                    ),
                  ),
                ],
              ),
            );
        }
      },
    );
  }
}

class _AppTitle extends StatelessWidget {
  const _AppTitle();

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Logo(size: 30, radius: t.radii.control * 0.8),
        const SizedBox(width: 10),
        const Flexible(
          child: Text('Tilleuls 2026', overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  final double size;
  final double radius;

  const _Logo({required this.size, required this.radius});

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: t.heroGradient,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(Icons.festival_rounded, color: t.onAccent, size: size * 0.6),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel();

  @override
  Widget build(BuildContext context) {
    var controller = GalleryScope.of(context);
    var state = controller.value;
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    return Container(
      width: 264,
      color: t.card,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Logo(size: 40, radius: t.radii.control),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Festen Orga', style: text.titleMedium),
                    Text(
                      'Festival des Tilleuls 2026',
                      style: text.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          for (var page in GalleryPage.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _SideItem(
                page: page,
                selected: page == state.page,
                onTap: () => controller.selectPage(page),
              ),
            ),
          const Spacer(),
          FkCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.cloud_done_rounded, color: t.ok, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Synchronisé', style: text.labelLarge),
                      Text('il y a 2 min', style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  final GalleryPage page;
  final bool selected;
  final VoidCallback onTap;

  const _SideItem({
    required this.page,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    var color = selected ? t.accentText : t.ink2;
    return Material(
      color: selected ? t.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(t.radii.control),
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radii.control),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(page.icon, color: color, size: 22),
              const SizedBox(width: 12),
              Text(
                page.label,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: selected ? t.accentText : t.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The theme picker: the presets in a menu, the next one in one tap, light
/// or dark.
class ThemeActions extends StatelessWidget {
  /// Only the swatch, no name (a phone).
  final bool compact;

  /// The theme picker.
  const ThemeActions({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    var controller = GalleryScope.of(context);
    var state = controller.value;
    var isDark = state.brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<FestenaoThemePreset>(
          tooltip: 'Thème : ${state.preset.name}',
          initialValue: state.preset,
          onSelected: controller.selectPreset,
          itemBuilder: (context) => [
            for (var preset in festenaoThemePresets)
              PopupMenuItem(
                value: preset,
                child: Row(
                  children: [
                    PresetSwatch(preset: preset, brightness: state.brightness),
                    const SizedBox(width: 12),
                    Text(preset.name),
                  ],
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PresetSwatch(
                  preset: state.preset,
                  brightness: state.brightness,
                ),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  Text(
                    state.preset.name,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Thème suivant',
          icon: const Icon(Icons.palette_outlined),
          onPressed: controller.nextPreset,
        ),
        IconButton(
          tooltip: isDark ? 'Clair' : 'Sombre',
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
          onPressed: controller.toggleBrightness,
        ),
      ],
    );
  }
}

/// The accent of [preset] on its paper.
class PresetSwatch extends StatelessWidget {
  /// The preset.
  final FestenaoThemePreset preset;

  /// The brightness shown.
  final Brightness brightness;

  /// Diameter.
  final double size;

  /// A swatch.
  const PresetSwatch({
    super.key,
    required this.preset,
    required this.brightness,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    var palette = preset.palette(brightness);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
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
