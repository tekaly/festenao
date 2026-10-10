import 'package:festenao_theme/src/design/festenao_palette.dart';
import 'package:festenao_theme/src/design/festenao_theme_data.dart';
import 'package:festenao_theme/src/design/festenao_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// A named festenao theme, light and dark.
///
/// Either hand made (its two palettes given) or derived from a seed colour
/// on the neutral paper ([FestenaoThemePreset.seed]).
class FestenaoThemePreset {
  /// Stable id (stored in preferences).
  final String id;

  /// Name shown in a picker.
  final String name;

  /// One line about the look.
  final String description;

  final FestenaoPalette? _light;
  final FestenaoPalette? _dark;
  final Color? _seed;
  final DynamicSchemeVariant _variant;

  /// The corner radii.
  final FestenaoRadii radii;

  /// The weight of the headings.
  final FontWeight headingWeight;

  /// Small labels in uppercase monospace.
  final bool monoLabels;

  /// A hand made theme: its palettes in light and dark (one may be missing,
  /// the other brightness is then used).
  const FestenaoThemePreset({
    required this.id,
    required this.name,
    required this.description,
    this._light,
    this._dark,
    this.radii = const FestenaoRadii(),
    this.headingWeight = FontWeight.w600,
    this.monoLabels = false,
  }) : _seed = null,
       _variant = DynamicSchemeVariant.tonalSpot;

  /// A theme derived from [seed] on the neutral paper.
  const FestenaoThemePreset.seed({
    required this.id,
    required this.name,
    required this.description,
    required Color this._seed,
    this._variant = DynamicSchemeVariant.tonalSpot,
    this.radii = const FestenaoRadii(),
    this.headingWeight = FontWeight.w600,
    this.monoLabels = false,
  }) : _light = null,
       _dark = null;

  /// Whether [brightness] is designed (not borrowed from the other one).
  bool supports(Brightness brightness) =>
      _seed != null ||
      (brightness == Brightness.light ? _light != null : _dark != null);

  /// The palette in [brightness].
  FestenaoPalette palette(Brightness brightness) {
    var seed = _seed;
    if (seed != null) {
      return FestenaoPalette.fromSeed(
        seed: seed,
        brightness: brightness,
        variant: _variant,
      );
    }
    return (brightness == Brightness.light ? _light : _dark) ??
        (_light ?? _dark)!;
  }

  /// The colour that stands for the theme in a picker.
  Color get swatch => palette(Brightness.light).accent;

  /// The Material theme in [brightness].
  ThemeData themeData(Brightness brightness) => festenaoThemeDataFromPalette(
    palette(brightness),
    radii: radii,
    headingWeight: headingWeight,
    monoLabels: monoLabels,
  );

  @override
  String toString() => 'FestenaoThemePreset($id)';
}

/// Festenao: neutral paper and ink, a blue for the action.
final festenaoThemeFestenao = FestenaoThemePreset(
  id: 'festenao',
  name: 'Festenao',
  description: 'Papier neutre, encre, un bleu pour l\'action',
  light: festenaoNeutralLight.copyWith(
    accent: const Color(0xFF3157D5),
    onAccent: const Color(0xFFFFFFFF),
    accentText: const Color(0xFF2747B8),
  ),
  dark: festenaoNeutralDark.copyWith(
    accent: const Color(0xFF8AA8FF),
    onAccent: const Color(0xFF0B1E45),
    accentText: const Color(0xFF9DB7FF),
  ),
);

/// Basalte and Plein jour: the meal ticket of the bene planner, safran on
/// basalt for the evening, high contrast for the noon sun.
const festenaoThemeBasalte = FestenaoThemePreset(
  id: 'basalte',
  name: 'Basalte · Plein jour',
  description: 'Safran sur basalte le soir, plein jour au soleil',
  light: FestenaoPalette(
    brightness: Brightness.light,
    paper: Color(0xFFEEF1F0),
    card: Color(0xFFFFFFFF),
    sunk: Color(0xFFE4E9E7),
    line: Color(0xFFD3DAD7),
    lineStrong: Color(0xFF9AA5A1),
    ink: Color(0xFF15191C),
    ink2: Color(0xFF4E585E),
    ink3: Color(0xFF7A8489),
    accent: Color(0xFFFFC233),
    onAccent: Color(0xFF2A1E00),
    accentText: Color(0xFF8A5A00),
    secondary: Color(0xFF4651D6),
    ok: Color(0xFF0E9F5C),
    warn: Color(0xFFB86E00),
    bad: Color(0xFFD93636),
    info: Color(0xFF4651D6),
    muted: Color(0xFF646E73),
    categories: [
      Color(0xFF1E9AA4),
      Color(0xFFC8418F),
      Color(0xFFA78A3E),
      Color(0xFFD9692A),
      Color(0xFF8456D6),
      Color(0xFF3D7F2F),
    ],
  ),
  dark: FestenaoPalette(
    brightness: Brightness.dark,
    paper: Color(0xFF1C2024),
    card: Color(0xFF252A2F),
    sunk: Color(0xFF2F353B),
    line: Color(0xFF3A4148),
    lineStrong: Color(0xFF59626B),
    ink: Color(0xFFEEF1F3),
    ink2: Color(0xFFA9B2BA),
    ink3: Color(0xFF78828C),
    accent: Color(0xFFFFC233),
    onAccent: Color(0xFF2A1E00),
    accentText: Color(0xFFFFD06B),
    secondary: Color(0xFF9AA4FF),
    ok: Color(0xFF4ADE9A),
    warn: Color(0xFFFFA36B),
    bad: Color(0xFFFF6B6B),
    info: Color(0xFF9AA4FF),
    muted: Color(0xFF8C969F),
    categories: [
      Color(0xFF5CC8D0),
      Color(0xFFF08BC4),
      Color(0xFFD9C38A),
      Color(0xFFFFA36B),
      Color(0xFFC49BFF),
      Color(0xFF8BD17C),
    ],
  ),
);

/// Arcade: the neo-arcade of buzzerelio, yellow and pink on near black,
/// heavy headings, monospace labels.
const festenaoThemeArcade = FestenaoThemePreset(
  id: 'arcade',
  name: 'Arcade',
  description: 'Néo-arcade : jaune et rose sur presque noir',
  headingWeight: FontWeight.w700,
  monoLabels: true,
  radii: FestenaoRadii(sheet: 24, card: 18, control: 14, pill: 10),
  light: FestenaoPalette(
    brightness: Brightness.light,
    paper: Color(0xFFF6F4EC),
    card: Color(0xFFFFFFFF),
    sunk: Color(0xFFEDEAE0),
    line: Color(0xFFE2DED2),
    lineStrong: Color(0xFFB9B4A6),
    ink: Color(0xFF111214),
    ink2: Color(0xFF55585F),
    ink3: Color(0xFF7D8088),
    accent: Color(0xFFFFC700),
    onAccent: Color(0xFF111214),
    accentText: Color(0xFF8A6A00),
    secondary: Color(0xFFE0144C),
    ok: Color(0xFF0F8F5F),
    warn: Color(0xFFB36B00),
    bad: Color(0xFFD7263D),
    info: Color(0xFF1F6FD1),
    muted: Color(0xFF6B6E76),
    categories: [
      Color(0xFFE0144C),
      Color(0xFF0F8F5F),
      Color(0xFF1F6FD1),
      Color(0xFF8B3FD9),
      Color(0xFFE06A00),
      Color(0xFF008C99),
    ],
  ),
  dark: FestenaoPalette(
    brightness: Brightness.dark,
    paper: Color(0xFF0B0D11),
    card: Color(0xFF15181E),
    sunk: Color(0xFF1F232B),
    line: Color(0xFF2B303A),
    lineStrong: Color(0xFF454B57),
    ink: Color(0xFFF2F3F5),
    ink2: Color(0xFF8B92A0),
    ink3: Color(0xFF666D7A),
    accent: Color(0xFFFFC700),
    onAccent: Color(0xFF000000),
    accentText: Color(0xFFFFC700),
    secondary: Color(0xFFFF2E63),
    ok: Color(0xFF1DB981),
    warn: Color(0xFFFFB020),
    bad: Color(0xFFFF6B6B),
    info: Color(0xFF5AB0FF),
    muted: Color(0xFF8B92A0),
    categories: [
      Color(0xFFFF2E63),
      Color(0xFF1DB981),
      Color(0xFF5AB0FF),
      Color(0xFFB07CFF),
      Color(0xFFFF8A3D),
      Color(0xFF2FD3E0),
    ],
  ),
);

/// Obsidian: the telemetry look of cronelio, developer blue on obsidian,
/// tight corners, monospace labels.
const festenaoThemeObsidian = FestenaoThemePreset(
  id: 'obsidian',
  name: 'Obsidian',
  description: 'Télémétrie : bleu développeur sur obsidienne',
  monoLabels: true,
  radii: FestenaoRadii(sheet: 16, card: 10, control: 8, pill: 6),
  light: FestenaoPalette(
    brightness: Brightness.light,
    paper: Color(0xFFF4F6FA),
    card: Color(0xFFFFFFFF),
    sunk: Color(0xFFE9EDF3),
    line: Color(0xFFDCE1E9),
    lineStrong: Color(0xFFB5BDCA),
    ink: Color(0xFF10141A),
    ink2: Color(0xFF414753),
    ink3: Color(0xFF6B7280),
    accent: Color(0xFF005CBA),
    onAccent: Color(0xFFFFFFFF),
    accentText: Color(0xFF005CBA),
    secondary: Color(0xFF27A640),
    ok: Color(0xFF1E8E3E),
    warn: Color(0xFFA86B00),
    bad: Color(0xFFBA1A1A),
    info: Color(0xFF005CBA),
    muted: Color(0xFF6B7280),
    categories: [
      Color(0xFF005CBA),
      Color(0xFF1E8E3E),
      Color(0xFFA86B00),
      Color(0xFF8E3FC4),
      Color(0xFFC2185B),
      Color(0xFF00838F),
    ],
  ),
  dark: FestenaoPalette(
    brightness: Brightness.dark,
    paper: Color(0xFF0A0E14),
    card: Color(0xFF181C22),
    sunk: Color(0xFF262A31),
    line: Color(0xFF2A2F38),
    lineStrong: Color(0xFF414753),
    ink: Color(0xFFDFE2EB),
    ink2: Color(0xFFC1C6D6),
    ink3: Color(0xFF8B919F),
    accent: Color(0xFFAAC7FF),
    onAccent: Color(0xFF002F65),
    accentText: Color(0xFFAAC7FF),
    secondary: Color(0xFF67DF70),
    ok: Color(0xFF67DF70),
    warn: Color(0xFFFABC45),
    bad: Color(0xFFFFB4AB),
    info: Color(0xFFAAC7FF),
    muted: Color(0xFF8B919F),
    categories: [
      Color(0xFFAAC7FF),
      Color(0xFF67DF70),
      Color(0xFFFABC45),
      Color(0xFFD0A8FF),
      Color(0xFFFF8FB1),
      Color(0xFF6FE3E9),
    ],
  ),
);

/// Guinguette: a summer festival, terracotta and teal on warm cream.
const festenaoThemeGuinguette = FestenaoThemePreset(
  id: 'guinguette',
  name: 'Guinguette',
  description: 'Terre cuite et sarcelle sur crème, un festival d\'été',
  radii: FestenaoRadii(sheet: 28, card: 20, control: 14, pill: 999),
  light: FestenaoPalette(
    brightness: Brightness.light,
    paper: Color(0xFFFBF6EE),
    card: Color(0xFFFFFFFF),
    sunk: Color(0xFFF3EBDF),
    line: Color(0xFFEADFCF),
    lineStrong: Color(0xFFC9B9A3),
    ink: Color(0xFF2A2118),
    ink2: Color(0xFF6A5B4C),
    ink3: Color(0xFF948473),
    accent: Color(0xFFC94F33),
    onAccent: Color(0xFFFFFFFF),
    accentText: Color(0xFFA83E25),
    secondary: Color(0xFF127C7A),
    ok: Color(0xFF2F7D3A),
    warn: Color(0xFFA9670A),
    bad: Color(0xFFB3261E),
    info: Color(0xFF127C7A),
    muted: Color(0xFF7A6D60),
    categories: [
      Color(0xFF127C7A),
      Color(0xFFC94F33),
      Color(0xFFB08A1E),
      Color(0xFF7A4FB0),
      Color(0xFF3F7F3A),
      Color(0xFFB3466E),
    ],
  ),
  dark: FestenaoPalette(
    brightness: Brightness.dark,
    paper: Color(0xFF1B1612),
    card: Color(0xFF251E18),
    sunk: Color(0xFF30271F),
    line: Color(0xFF3B3027),
    lineStrong: Color(0xFF5E4F42),
    ink: Color(0xFFF6EEE4),
    ink2: Color(0xFFC3B3A2),
    ink3: Color(0xFF8F8072),
    accent: Color(0xFFFF8A66),
    onAccent: Color(0xFF3A1206),
    accentText: Color(0xFFFF9C7D),
    secondary: Color(0xFF5CC6C2),
    ok: Color(0xFF7DD38A),
    warn: Color(0xFFF2B54A),
    bad: Color(0xFFFF7A6E),
    info: Color(0xFF5CC6C2),
    muted: Color(0xFF9C8C7D),
    categories: [
      Color(0xFF5CC6C2),
      Color(0xFFFF8A66),
      Color(0xFFE6C15A),
      Color(0xFFB99AF0),
      Color(0xFF8CCF7E),
      Color(0xFFF08DB1),
    ],
  ),
);

/// Nocturne: a night festival, magenta and violet on deep indigo.
const festenaoThemeNocturne = FestenaoThemePreset(
  id: 'nocturne',
  name: 'Nocturne',
  description: 'Magenta et violet sur indigo profond, un festival de nuit',
  headingWeight: FontWeight.w700,
  light: FestenaoPalette(
    brightness: Brightness.light,
    paper: Color(0xFFF6F4FB),
    card: Color(0xFFFFFFFF),
    sunk: Color(0xFFEDE9F6),
    line: Color(0xFFE2DCEF),
    lineStrong: Color(0xFFBDB3D6),
    ink: Color(0xFF17122B),
    ink2: Color(0xFF524A6E),
    ink3: Color(0xFF7D7598),
    accent: Color(0xFFC2185B),
    onAccent: Color(0xFFFFFFFF),
    accentText: Color(0xFFAD1457),
    secondary: Color(0xFF5B4FE9),
    ok: Color(0xFF1C7C45),
    warn: Color(0xFF9A5B00),
    bad: Color(0xFFC2302D),
    info: Color(0xFF5B4FE9),
    muted: Color(0xFF6E6788),
    categories: [
      Color(0xFF5B4FE9),
      Color(0xFFC2185B),
      Color(0xFF00897B),
      Color(0xFFB86E00),
      Color(0xFF3A64B8),
      Color(0xFF8E24AA),
    ],
  ),
  dark: FestenaoPalette(
    brightness: Brightness.dark,
    paper: Color(0xFF0E0B1A),
    card: Color(0xFF17132A),
    sunk: Color(0xFF211B3A),
    line: Color(0xFF2E2750),
    lineStrong: Color(0xFF4A4178),
    ink: Color(0xFFF1EEFF),
    ink2: Color(0xFFB3ABD6),
    ink3: Color(0xFF8079A6),
    accent: Color(0xFFFF5FA8),
    onAccent: Color(0xFF2A0016),
    accentText: Color(0xFFFF7DB8),
    secondary: Color(0xFF8F84FF),
    ok: Color(0xFF5EE6A8),
    warn: Color(0xFFFFC46B),
    bad: Color(0xFFFF6B81),
    info: Color(0xFF8F84FF),
    muted: Color(0xFF8C85B0),
    categories: [
      Color(0xFF8F84FF),
      Color(0xFFFF5FA8),
      Color(0xFF4FD8C4),
      Color(0xFFFFC46B),
      Color(0xFF6FA8FF),
      Color(0xFFD685FF),
    ],
  ),
);

/// Contraste: black on white (white on black), stronger lines and heavier
/// headings, for reading in the sun or with a low vision.
const festenaoThemeContrast = FestenaoThemePreset(
  id: 'contrast',
  name: 'Contraste',
  description: 'Noir sur blanc, contrastes renforcés (accessibilité)',
  headingWeight: FontWeight.w700,
  light: FestenaoPalette(
    brightness: Brightness.light,
    paper: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    sunk: Color(0xFFF0F0F0),
    line: Color(0xFF8A8A8A),
    lineStrong: Color(0xFF000000),
    ink: Color(0xFF000000),
    ink2: Color(0xFF1F1F1F),
    ink3: Color(0xFF4A4A4A),
    accent: Color(0xFF0037B3),
    onAccent: Color(0xFFFFFFFF),
    accentText: Color(0xFF0037B3),
    secondary: Color(0xFF6A0DAD),
    ok: Color(0xFF0B6B2E),
    warn: Color(0xFF8A4B00),
    bad: Color(0xFFB00020),
    info: Color(0xFF0037B3),
    muted: Color(0xFF4A4A4A),
    categories: [
      Color(0xFF0037B3),
      Color(0xFFB00020),
      Color(0xFF0B6B2E),
      Color(0xFF8A4B00),
      Color(0xFF6A0DAD),
      Color(0xFF00616B),
    ],
  ),
  dark: FestenaoPalette(
    brightness: Brightness.dark,
    paper: Color(0xFF000000),
    card: Color(0xFF0A0A0A),
    sunk: Color(0xFF1A1A1A),
    line: Color(0xFF8A8A8A),
    lineStrong: Color(0xFFFFFFFF),
    ink: Color(0xFFFFFFFF),
    ink2: Color(0xFFE6E6E6),
    ink3: Color(0xFFBDBDBD),
    accent: Color(0xFFFFD400),
    onAccent: Color(0xFF000000),
    accentText: Color(0xFFFFE14D),
    secondary: Color(0xFF7FDBFF),
    ok: Color(0xFF4CE38A),
    warn: Color(0xFFFFB347),
    bad: Color(0xFFFF6B6B),
    info: Color(0xFF7FDBFF),
    muted: Color(0xFFBDBDBD),
    categories: [
      Color(0xFFFFD400),
      Color(0xFF7FDBFF),
      Color(0xFF4CE38A),
      Color(0xFFFF6B6B),
      Color(0xFFD9A6FF),
      Color(0xFFFFB347),
    ],
  ),
);

/// Papier: cream paper, brown ink and a terracotta accent, warm and quiet,
/// for the apps read for a long time (lyrics, songbooks, blogs).
const festenaoThemePapier = FestenaoThemePreset(
  id: 'papier',
  name: 'Papier',
  description: 'Papier crème, encre brune, terre cuite : pour lire longtemps',
  light: FestenaoPalette(
    brightness: Brightness.light,
    paper: Color(0xFFF7F1E5),
    card: Color(0xFFFFFBF2),
    sunk: Color(0xFFEFE6D4),
    line: Color(0xFFE3D8C3),
    lineStrong: Color(0xFFC9B99B),
    ink: Color(0xFF2B2118),
    ink2: Color(0xFF5C4A38),
    ink3: Color(0xFF85715B),
    accent: Color(0xFFA4492B),
    onAccent: Color(0xFFFFFFFF),
    accentText: Color(0xFF8F3D22),
    secondary: Color(0xFF3E6B5A),
    ok: Color(0xFF2F6B3A),
    warn: Color(0xFF8A5A00),
    bad: Color(0xFFB3261E),
    info: Color(0xFF2E5E8A),
    muted: Color(0xFF7A6A58),
    categories: [
      Color(0xFFA4492B),
      Color(0xFF3E6B5A),
      Color(0xFF2E5E8A),
      Color(0xFF8A5A00),
      Color(0xFF7A4E8C),
      Color(0xFFB05C7A),
    ],
  ),
  dark: FestenaoPalette(
    brightness: Brightness.dark,
    paper: Color(0xFF1C1712),
    card: Color(0xFF241E17),
    sunk: Color(0xFF2E261D),
    line: Color(0xFF3A3026),
    lineStrong: Color(0xFF5A4B3B),
    ink: Color(0xFFF3EADB),
    ink2: Color(0xFFCDBEA6),
    ink3: Color(0xFFA08F78),
    accent: Color(0xFFE08A63),
    onAccent: Color(0xFF2A1206),
    accentText: Color(0xFFF0A07C),
    secondary: Color(0xFF8CC2AC),
    ok: Color(0xFF8FD19A),
    warn: Color(0xFFE8B65C),
    bad: Color(0xFFFF8A80),
    info: Color(0xFF8DB8E0),
    muted: Color(0xFFA39480),
    categories: [
      Color(0xFFE08A63),
      Color(0xFF8CC2AC),
      Color(0xFF8DB8E0),
      Color(0xFFE8B65C),
      Color(0xFFC6A2D6),
      Color(0xFFE59AB4),
    ],
  ),
);

/// Ardoise: cool slate surfaces and a teal accent, a calm tool (admin
/// screens, dashboards) between the neutral Festenao and the dark Obsidian.
const festenaoThemeArdoise = FestenaoThemePreset(
  id: 'ardoise',
  name: 'Ardoise',
  description: 'Ardoise froide et sarcelle : un outil calme',
  light: FestenaoPalette(
    brightness: Brightness.light,
    paper: Color(0xFFEEF1F4),
    card: Color(0xFFFFFFFF),
    sunk: Color(0xFFE4E8EC),
    line: Color(0xFFD5DBE1),
    lineStrong: Color(0xFFA9B4BF),
    ink: Color(0xFF111A22),
    ink2: Color(0xFF3D4B57),
    ink3: Color(0xFF66737F),
    accent: Color(0xFF00796B),
    onAccent: Color(0xFFFFFFFF),
    accentText: Color(0xFF00695C),
    secondary: Color(0xFF3F5BA9),
    ok: Color(0xFF1E7B45),
    warn: Color(0xFF8F5A00),
    bad: Color(0xFFC0392B),
    info: Color(0xFF2F6FB0),
    muted: Color(0xFF66737F),
    categories: [
      Color(0xFF00796B),
      Color(0xFF3F5BA9),
      Color(0xFFB0632B),
      Color(0xFF8E3B8E),
      Color(0xFF2E7D32),
      Color(0xFFAD3A54),
    ],
  ),
  dark: FestenaoPalette(
    brightness: Brightness.dark,
    paper: Color(0xFF10161B),
    card: Color(0xFF172027),
    sunk: Color(0xFF1F2A33),
    line: Color(0xFF2A3640),
    lineStrong: Color(0xFF455563),
    ink: Color(0xFFE8EEF2),
    ink2: Color(0xFFAEBBC6),
    ink3: Color(0xFF82909C),
    accent: Color(0xFF4DD0C0),
    onAccent: Color(0xFF00201C),
    accentText: Color(0xFF6FE0D2),
    secondary: Color(0xFF9DB3F0),
    ok: Color(0xFF6FD69B),
    warn: Color(0xFFF0BE63),
    bad: Color(0xFFFF8A7A),
    info: Color(0xFF8AB8F0),
    muted: Color(0xFF8C99A5),
    categories: [
      Color(0xFF4DD0C0),
      Color(0xFF9DB3F0),
      Color(0xFFF0A36B),
      Color(0xFFD08ED0),
      Color(0xFF7FD68A),
      Color(0xFFF08AA0),
    ],
  ),
);

/// Every preset, the hand made ones first, then the seed ones.
final festenaoThemePresets = <FestenaoThemePreset>[
  festenaoThemeFestenao,
  festenaoThemeBasalte,
  festenaoThemeArcade,
  festenaoThemeObsidian,
  festenaoThemeGuinguette,
  festenaoThemeNocturne,
  festenaoThemeContrast,
  festenaoThemePapier,
  festenaoThemeArdoise,
  const FestenaoThemePreset.seed(
    id: 'violet',
    name: 'Violet',
    description: 'Graine violette, la référence de firebase UI',
    seed: Color(0xFF5B4FE9),
  ),
  const FestenaoThemePreset.seed(
    id: 'teal',
    name: 'Teal',
    description: 'Graine sarcelle',
    seed: Color(0xFF00897B),
  ),
  const FestenaoThemePreset.seed(
    id: 'coral',
    name: 'Coral',
    description: 'Graine corail, variante vibrante',
    seed: Color(0xFFE5533D),
    variant: DynamicSchemeVariant.vibrant,
  ),
  const FestenaoThemePreset.seed(
    id: 'forest',
    name: 'Forest',
    description: 'Graine forêt, variante fidèle',
    seed: Color(0xFF2E7D32),
    variant: DynamicSchemeVariant.fidelity,
  ),
  const FestenaoThemePreset.seed(
    id: 'ocean',
    name: 'Ocean',
    description: 'Graine océan, variante expressive',
    seed: Color(0xFF1565C0),
    variant: DynamicSchemeVariant.expressive,
  ),
  const FestenaoThemePreset.seed(
    id: 'graphite',
    name: 'Graphite',
    description: 'Graine graphite, monochrome',
    seed: Color(0xFF607D8B),
    variant: DynamicSchemeVariant.monochrome,
  ),
  const FestenaoThemePreset.seed(
    id: 'lagon',
    name: 'Lagon',
    description: 'Le bleu lagon de playelio',
    seed: Color(0xFF009EE0),
  ),
];

/// The preset with [id], or the default one.
FestenaoThemePreset festenaoThemePresetById(String? id) =>
    festenaoThemePresets.firstWhere(
      (preset) => preset.id == id,
      orElse: () => festenaoThemeFestenao,
    );

/// The presets with [ids], in that order, the unknown ids skipped: the list
/// of themes an app offers (`festenaoThemePresetsByIds(['festenao',
/// 'obsidian', 'contrast'])`), to which it can add presets of its own.
List<FestenaoThemePreset> festenaoThemePresetsByIds(Iterable<String> ids) => [
  for (var id in ids)
    ?festenaoThemePresets.where((preset) => preset.id == id).firstOrNull,
];
