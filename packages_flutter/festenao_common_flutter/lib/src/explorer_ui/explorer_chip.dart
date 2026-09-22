import 'package:festenao_common/data/object_editor.dart';
import 'package:festenao_theme/theme.dart';
import 'package:flutter/material.dart';

/// The size the small labels of the explorer ui are drawn at.
///
/// The text themes leave the size of `labelSmall` to the widget, so the
/// badges, section headers and status bars name it once here.
const explorerChipFontSize = 11.0;

/// How loud a chip is.
enum ExplorerChipTone {
  /// The quiet one: a type badge, a count, a size.
  neutral,

  /// Something worth noticing: a live connection, unsaved edits.
  accent,

  /// Something that went wrong, or is refused.
  danger,
}

/// A small badge: a type beside a field, a count beside a store, the state of
/// a screen in its app bar.
///
/// It is the one chip every explorer uses, so a badge reads the same wherever
/// it is. Its colours come from the theme — a container and its `on` colour —
/// so it follows whatever theme the app is in, light, dark or poppins, without
/// a colour of its own.
class ExplorerChip extends StatelessWidget {
  /// What it says, kept short.
  final String label;

  /// An icon before the label.
  final IconData? icon;

  /// How loud it is.
  final ExplorerChipTone tone;

  /// True for the monospace font, which lines up hex and sizes.
  final bool monospace;

  /// What a long press or a tap says.
  final String? tooltip;

  /// Chip saying [label].
  const ExplorerChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = ExplorerChipTone.neutral,
    this.monospace = false,
    this.tooltip,
  });

  /// The background and foreground [tone] asks the theme for.
  static (Color, Color) toneColors(ColorScheme colors, ExplorerChipTone tone) =>
      switch (tone) {
        ExplorerChipTone.neutral => (
          colors.surfaceContainerHighest,
          colors.onSurfaceVariant,
        ),
        ExplorerChipTone.accent => (
          colors.primaryContainer,
          colors.onPrimaryContainer,
        ),
        ExplorerChipTone.danger => (
          colors.errorContainer,
          colors.onErrorContainer,
        ),
      };

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var (background, foreground) = toneColors(theme.colorScheme, tone);
    var chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
              color: foreground,
              // A theme leaves the size of its small labels to whatever
              // draws them, and a badge wants to stay a badge.
              fontSize: explorerChipFontSize,
              fontFamily: monospace ? festenaoMonospaceFontFamily : null,
              fontFeatures: const [FontFeature.tabularFigures()],
              height: 1.2,
            ),
          ),
        ],
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

/// The type badge of a value: `str`, `int`, `ts`, `byte`, `map`…
///
/// It is what tells a timestamp from the string that looks like one, at a
/// glance, without opening anything.
class ExplorerTypeChip extends StatelessWidget {
  /// The type it names.
  final ObjectValueTypeHandler type;

  /// Badge of [type].
  const ExplorerTypeChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) => ExplorerChip(
    label: type.shortLabel,
    tooltip: type.label,
    monospace: true,
    tone: type.isCustom ? ExplorerChipTone.accent : ExplorerChipTone.neutral,
  );
}
