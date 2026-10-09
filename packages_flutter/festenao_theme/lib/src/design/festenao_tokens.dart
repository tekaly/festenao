import 'package:festenao_theme/src/design/festenao_palette.dart';
import 'package:material_ui/material_ui.dart';

/// The corner radii of a theme.
@immutable
class FestenaoRadii {
  /// Sheets and dialogs.
  final double sheet;

  /// Cards.
  final double card;

  /// Fields and buttons.
  final double control;

  /// Pills, badges, chips.
  final double pill;

  /// The corner radii of a theme.
  const FestenaoRadii({
    this.sheet = 24,
    this.card = 16,
    this.control = 12,
    this.pill = 8,
  });
}

/// The spacing and widths shared by the festenao screens.
abstract final class FestenaoSpace {
  /// Page padding on a phone.
  static const double pagePhone = 16;

  /// Page padding on a desk.
  static const double pageDesk = 32;

  /// Gaps.
  static const double xs = 4;

  /// Gaps.
  static const double s = 8;

  /// Gaps.
  static const double m = 12;

  /// Gaps.
  static const double l = 16;

  /// Gaps.
  static const double xl = 24;

  /// A form column.
  static const double formWidth = 640;

  /// A reading column.
  static const double readingWidth = 720;

  /// Width from which the screens use a rail and two panes.
  static const double medium = 600;

  /// Width from which the screens use a side navigation.
  static const double expanded = 1000;
}

/// The design tokens of a festenao theme, read with [FestenaoTokens.of].
///
/// Built by the theme builder from a [FestenaoPalette], never set by hand: a
/// screen picks `tokens.ok`, `tokens.card` or `tokens.radii.card` and stays
/// right in every theme and brightness.
@immutable
class FestenaoTokens extends ThemeExtension<FestenaoTokens> {
  /// The colours.
  final FestenaoPalette palette;

  /// The corner radii.
  final FestenaoRadii radii;

  /// The monospace family (codes, times in some themes, raw data).
  final String monoFamily;

  /// Small labels (section titles, badges) in uppercase monospace.
  final bool monoLabels;

  /// The design tokens of a theme.
  const FestenaoTokens({
    required this.palette,
    this.radii = const FestenaoRadii(),
    required this.monoFamily,
    this.monoLabels = false,
  });

  /// The tokens of the current theme, derived from its colour scheme when
  /// the theme was not built by festenao.
  static FestenaoTokens of(BuildContext context) {
    var theme = Theme.of(context);
    return theme.extension<FestenaoTokens>() ?? FestenaoTokens.fallback(theme);
  }

  /// Tokens derived from any [theme].
  factory FestenaoTokens.fallback(ThemeData theme) {
    var scheme = theme.colorScheme;
    var neutral = theme.brightness == Brightness.dark
        ? festenaoNeutralDark
        : festenaoNeutralLight;
    return FestenaoTokens(
      palette: neutral.copyWith(
        paper: theme.scaffoldBackgroundColor,
        card: scheme.surface,
        sunk: scheme.surfaceContainerHighest,
        line: scheme.outlineVariant,
        lineStrong: scheme.outline,
        ink: scheme.onSurface,
        ink2: scheme.onSurfaceVariant,
        accent: scheme.primary,
        onAccent: scheme.onPrimary,
        accentText: scheme.primary,
        bad: scheme.error,
      ),
      monoFamily: 'monospace',
    );
  }

  /// Shortcuts to the palette.
  bool get isDark => palette.isDark;

  /// The page.
  Color get paper => palette.paper;

  /// Cards.
  Color get card => palette.card;

  /// Sunk surfaces.
  Color get sunk => palette.sunk;

  /// Lines.
  Color get line => palette.line;

  /// Strong lines.
  Color get lineStrong => palette.lineStrong;

  /// Text.
  Color get ink => palette.ink;

  /// Secondary text.
  Color get ink2 => palette.ink2;

  /// Faint text.
  Color get ink3 => palette.ink3;

  /// The accent.
  Color get accent => palette.accent;

  /// On the accent.
  Color get onAccent => palette.onAccent;

  /// The accent as text.
  Color get accentText => palette.accentText;

  /// The accent tint.
  Color get accentSoft => palette.accentSoft;

  /// The second accent.
  Color get secondary => palette.effectiveSecondary;

  /// Done.
  Color get ok => palette.ok;

  /// Pending.
  Color get warn => palette.warn;

  /// Error.
  Color get bad => palette.bad;

  /// Information.
  Color get info => palette.info;

  /// Neutral.
  Color get muted => palette.muted;

  /// A soft tint of [color].
  Color soft(Color color) => palette.soft(color);

  /// Category [index].
  Color category(int index) => palette.category(index);

  /// The shadow of a card: a faint accent tinted one in light, none in dark
  /// (the surfaces carry the depth there).
  List<BoxShadow> get cardShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ];

  /// A hero gradient (an app icon, an avatar, a big screen).
  Gradient get heroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, Color.lerp(accent, secondary, 0.6)!],
  );

  /// The style of a small label (section titles, badges), in [color].
  TextStyle labelStyle(BuildContext context, {Color? color}) {
    var base = Theme.of(context).textTheme.labelMedium ?? const TextStyle();
    if (monoLabels) {
      return base.copyWith(
        fontFamily: monoFamily,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: color ?? ink2,
      );
    }
    return base.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: color ?? ink2,
    );
  }

  /// Whether small labels are drawn in uppercase.
  bool get upperLabels => monoLabels;

  @override
  FestenaoTokens copyWith({
    FestenaoPalette? palette,
    FestenaoRadii? radii,
    String? monoFamily,
    bool? monoLabels,
  }) => FestenaoTokens(
    palette: palette ?? this.palette,
    radii: radii ?? this.radii,
    monoFamily: monoFamily ?? this.monoFamily,
    monoLabels: monoLabels ?? this.monoLabels,
  );

  @override
  FestenaoTokens lerp(covariant FestenaoTokens? other, double t) {
    if (other == null) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}

/// Access to the tokens from a context.
extension FestenaoTokensContextExt on BuildContext {
  /// The festenao tokens of the current theme.
  FestenaoTokens get festenao => FestenaoTokens.of(this);
}
