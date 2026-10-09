import 'package:material_ui/material_ui.dart';

/// The colours of one festenao theme in one brightness.
///
/// A neutral paper and ink with one accent: the accent marks the main
/// action, the selection and what is live, never a whole surface. Status and
/// category colours carry a fixed meaning in every app.
@immutable
class FestenaoPalette {
  /// Light or dark.
  final Brightness brightness;

  /// The page.
  final Color paper;

  /// Cards, sheets, lists.
  final Color card;

  /// Tracks, segmented backgrounds, the inside of a card.
  final Color sunk;

  /// Dividers and quiet outlines.
  final Color line;

  /// Field outlines and ghost buttons.
  final Color lineStrong;

  /// Text.
  final Color ink;

  /// Secondary text, icons.
  final Color ink2;

  /// Hints, faint text.
  final Color ink3;

  /// The accent: main action, selection, live.
  final Color accent;

  /// Text and icons on [accent].
  final Color onAccent;

  /// The accent as a text colour, readable on [paper] and [card].
  final Color accentText;

  /// A second accent (a buzzer, the night), defaults to [accent].
  final Color? secondary;

  /// Done, arrived, healthy.
  final Color ok;

  /// To check, pending.
  final Color warn;

  /// Error, allergy, removal.
  final Color bad;

  /// Information.
  final Color info;

  /// Neutral status.
  final Color muted;

  /// Six category colours given in sort order (stages, kinds of person,
  /// chart series), so that a category keeps its colour everywhere.
  final List<Color> categories;

  /// The colours of a theme in one brightness.
  const FestenaoPalette({
    required this.brightness,
    required this.paper,
    required this.card,
    required this.sunk,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    this.secondary,
    required this.ok,
    required this.warn,
    required this.bad,
    required this.info,
    required this.muted,
    required this.categories,
  });

  /// The neutral paper and ink of the festenao themes, with the accent of
  /// [seed] derived by Material ([variant]).
  factory FestenaoPalette.fromSeed({
    required Color seed,
    required Brightness brightness,
    DynamicSchemeVariant variant = DynamicSchemeVariant.tonalSpot,
  }) {
    var scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: variant,
    );
    var neutral = brightness == Brightness.light
        ? festenaoNeutralLight
        : festenaoNeutralDark;
    return neutral.copyWith(
      accent: scheme.primary,
      onAccent: scheme.onPrimary,
      accentText: scheme.primary,
    );
  }

  /// Whether dark.
  bool get isDark => brightness == Brightness.dark;

  /// The opacity of a soft tint.
  double get softAlpha => isDark ? 0.22 : 0.12;

  /// A soft tint of [color] (badges, selection, icon boxes).
  Color soft(Color color) => color.withValues(alpha: softAlpha);

  /// A soft tint of [accent].
  Color get accentSoft => soft(accent);

  /// The second accent, or the accent.
  Color get effectiveSecondary => secondary ?? accent;

  /// Category [index], cycling.
  Color category(int index) => categories[index % categories.length];

  /// Copy with some colours replaced.
  FestenaoPalette copyWith({
    Color? paper,
    Color? card,
    Color? sunk,
    Color? line,
    Color? lineStrong,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? accent,
    Color? onAccent,
    Color? accentText,
    Color? secondary,
    Color? ok,
    Color? warn,
    Color? bad,
    Color? info,
    Color? muted,
    List<Color>? categories,
  }) => FestenaoPalette(
    brightness: brightness,
    paper: paper ?? this.paper,
    card: card ?? this.card,
    sunk: sunk ?? this.sunk,
    line: line ?? this.line,
    lineStrong: lineStrong ?? this.lineStrong,
    ink: ink ?? this.ink,
    ink2: ink2 ?? this.ink2,
    ink3: ink3 ?? this.ink3,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    accentText: accentText ?? this.accentText,
    secondary: secondary ?? this.secondary,
    ok: ok ?? this.ok,
    warn: warn ?? this.warn,
    bad: bad ?? this.bad,
    info: info ?? this.info,
    muted: muted ?? this.muted,
    categories: categories ?? this.categories,
  );
}

/// The neutral light palette (paper, ink, status, categories), accent blue.
const festenaoNeutralLight = FestenaoPalette(
  brightness: Brightness.light,
  paper: Color(0xFFF3F4F6),
  card: Color(0xFFFFFFFF),
  sunk: Color(0xFFECEEF1),
  line: Color(0xFFE1E3E8),
  lineStrong: Color(0xFFC9CDD4),
  ink: Color(0xFF16181D),
  ink2: Color(0xFF4E535E),
  ink3: Color(0xFF737885),
  accent: Color(0xFF2459C2),
  onAccent: Color(0xFFFFFFFF),
  accentText: Color(0xFF2459C2),
  ok: Color(0xFF1C7C45),
  warn: Color(0xFF9A5B00),
  bad: Color(0xFFC2302D),
  info: Color(0xFF2459C2),
  muted: Color(0xFF646A76),
  categories: [
    Color(0xFF0F7F86),
    Color(0xFFB86E00),
    Color(0xFF7048C2),
    Color(0xFFC13F72),
    Color(0xFF3D7F2F),
    Color(0xFF3A64B8),
  ],
);

/// The neutral dark palette, accent blue.
const festenaoNeutralDark = FestenaoPalette(
  brightness: Brightness.dark,
  paper: Color(0xFF111318),
  card: Color(0xFF1A1D23),
  sunk: Color(0xFF23272E),
  line: Color(0xFF2C3038),
  lineStrong: Color(0xFF4A505B),
  ink: Color(0xFFEEF0F3),
  ink2: Color(0xFFA9AFBA),
  ink3: Color(0xFF7A808C),
  accent: Color(0xFF8AB0FF),
  onAccent: Color(0xFF0B1E45),
  accentText: Color(0xFF8AB0FF),
  ok: Color(0xFF4ADE80),
  warn: Color(0xFFFBBF24),
  bad: Color(0xFFFF6B6B),
  info: Color(0xFF60A5FA),
  muted: Color(0xFF8B92A0),
  categories: [
    Color(0xFF5CC8D0),
    Color(0xFFFFB547),
    Color(0xFFB79CFF),
    Color(0xFFF08BC4),
    Color(0xFF8BD17C),
    Color(0xFF8FB2FF),
  ],
);
