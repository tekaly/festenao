import 'package:festenao_theme/fonts/jetbrains_mono/jetbrains_mono_font.dart';
import 'package:festenao_theme/fonts/poppins/poppins_font.dart';
import 'package:festenao_theme/src/design/festenao_palette.dart';
import 'package:festenao_theme/src/design/festenao_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The Material theme of a [FestenaoPalette]: paper and ink surfaces, the
/// accent for the action and the selection, the tokens as an extension.
///
/// Every component is themed from the palette (app bars on the paper, cards
/// on the card colour with a line, filled buttons on the accent, labels of
/// small text from the text theme), so that screens written with the plain
/// Material widgets already look right.
ThemeData festenaoThemeDataFromPalette(
  FestenaoPalette palette, {
  FestenaoRadii radii = const FestenaoRadii(),
  String fontFamily = poppinsFontFamily,
  String monoFamily = jetBrainsMonoFontFamily,
  FontWeight headingWeight = FontWeight.w600,
  bool monoLabels = false,
}) {
  var p = palette;
  var isDark = p.isDark;
  var scheme = ColorScheme(
    brightness: p.brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    primaryContainer: Color.alphaBlend(p.accentSoft, p.card),
    onPrimaryContainer: p.accentText,
    secondary: p.effectiveSecondary,
    onSecondary: _onColor(p.effectiveSecondary),
    secondaryContainer: Color.alphaBlend(p.soft(p.effectiveSecondary), p.card),
    onSecondaryContainer: p.ink,
    tertiary: p.ok,
    onTertiary: _onColor(p.ok),
    tertiaryContainer: Color.alphaBlend(p.soft(p.ok), p.card),
    onTertiaryContainer: p.ink,
    error: p.bad,
    onError: _onColor(p.bad),
    errorContainer: Color.alphaBlend(p.soft(p.bad), p.card),
    onErrorContainer: p.bad,
    surface: p.card,
    onSurface: p.ink,
    surfaceDim: p.paper,
    surfaceBright: p.card,
    surfaceContainerLowest: isDark ? p.paper : p.card,
    surfaceContainerLow: isDark ? p.card : p.paper,
    surfaceContainer: isDark ? p.card : p.paper,
    surfaceContainerHigh: p.sunk,
    surfaceContainerHighest: Color.lerp(p.sunk, p.line, 0.5)!,
    onSurfaceVariant: p.ink2,
    outline: p.lineStrong,
    outlineVariant: p.line,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: p.ink,
    onInverseSurface: p.paper,
    inversePrimary: p.accentText,
    surfaceTint: Colors.transparent,
  );

  var typography = Typography.material2021(
    platform: TargetPlatform.android,
    colorScheme: scheme,
  );
  var base = (isDark ? typography.white : typography.black).apply(
    fontFamily: fontFamily,
    bodyColor: p.ink,
    displayColor: p.ink,
  );
  var textTheme = base.copyWith(
    displaySmall: base.displaySmall?.copyWith(
      fontSize: 36,
      fontWeight: headingWeight,
      letterSpacing: -0.5,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontWeight: headingWeight,
      letterSpacing: -0.3,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontSize: 24,
      fontWeight: headingWeight,
      letterSpacing: -0.3,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 18,
      fontWeight: headingWeight,
      letterSpacing: -0.1,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, letterSpacing: 0),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, letterSpacing: 0),
    bodySmall: base.bodySmall?.copyWith(fontSize: 12.5, color: p.ink2),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    labelMedium: base.labelMedium?.copyWith(color: p.ink2),
    labelSmall: base.labelSmall?.copyWith(color: p.ink2),
  );

  var controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radii.control),
  );
  var cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radii.card),
    side: BorderSide(color: p.line),
  );
  var sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radii.sheet),
  );
  var buttonText = textTheme.labelLarge!.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radii.control),
        borderSide: BorderSide(color: color, width: width),
      );
  var filledStyle = FilledButton.styleFrom(
    backgroundColor: p.accent,
    foregroundColor: p.onAccent,
    disabledBackgroundColor: p.sunk,
    disabledForegroundColor: p.ink3,
    minimumSize: const Size(64, 48),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    shape: controlShape,
    textStyle: buttonText,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    colorScheme: scheme,
    textTheme: textTheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: p.paper,
    canvasColor: p.paper,
    dividerColor: p.line,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    splashFactory: InkSparkle.splashFactory,
    iconTheme: IconThemeData(color: p.ink2, size: 22),
    appBarTheme: AppBarTheme(
      backgroundColor: p.paper,
      foregroundColor: p.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: IconThemeData(color: p.ink),
      actionsIconTheme: IconThemeData(color: p.ink2),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape,
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.ink2,
      textColor: p.ink,
      titleTextStyle: textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: textTheme.bodySmall,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 10,
      selectedColor: p.accentText,
      selectedTileColor: p.accentSoft,
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? p.sunk : p.card,
      hoverColor: p.accentSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: inputBorder(p.lineStrong),
      enabledBorder: inputBorder(isDark ? p.line : p.lineStrong),
      focusedBorder: inputBorder(p.accent, 2),
      errorBorder: inputBorder(p.bad),
      focusedErrorBorder: inputBorder(p.bad, 2),
      labelStyle: textTheme.bodyMedium?.copyWith(color: p.ink2),
      floatingLabelStyle: textTheme.bodyMedium?.copyWith(
        color: p.accentText,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(color: p.ink3),
      helperStyle: textTheme.bodySmall,
      prefixIconColor: p.ink2,
      suffixIconColor: p.ink2,
    ),
    filledButtonTheme: FilledButtonThemeData(style: filledStyle),
    // An elevated button looks like a filled one: one primary look.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        elevation: 0,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        side: BorderSide(color: p.lineStrong),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accentText,
        minimumSize: const Size(48, 44),
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.ink2),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: p.onAccent,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 4,
      highlightElevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radii.card),
      ),
      extendedTextStyle: buttonText,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.card,
      selectedColor: p.accentSoft,
      disabledColor: p.sunk,
      side: BorderSide(color: p.line),
      checkmarkColor: p.accentText,
      labelStyle: textTheme.labelLarge?.copyWith(color: p.ink),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: p.accentText),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radii.pill),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accentSoft
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.accentText : p.ink,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: p.lineStrong)),
        textStyle: WidgetStatePropertyAll(buttonText.copyWith(fontSize: 14)),
        minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
        shape: WidgetStatePropertyAll(controlShape),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? p.onAccent : p.lineStrong,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? p.accent : p.sunk,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : p.lineStrong,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? p.accent
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(p.onAccent),
      side: BorderSide(color: p.lineStrong, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? p.accent : p.lineStrong,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.sunk,
      circularTrackColor: p.sunk,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      inactiveTrackColor: p.sunk,
      thumbColor: p.accent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.accentSoft,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected) ? p.accentText : p.ink2,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? p.accentText : p.ink2,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: p.card,
      indicatorColor: p.accentSoft,
      selectedIconTheme: IconThemeData(color: p.accentText),
      unselectedIconTheme: IconThemeData(color: p.ink2),
      selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: p.accentText,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: textTheme.labelMedium,
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.accentSoft,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.accentText,
      unselectedLabelColor: p.ink2,
      indicatorColor: p.accent,
      dividerColor: p.line,
      labelStyle: buttonText.copyWith(fontSize: 14),
      unselectedLabelStyle: buttonText.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.paper),
      actionTextColor: isDark ? p.accentText : p.accent,
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      shape: controlShape,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: sheetShape,
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.ink2),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.lineStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radii.sheet)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.card,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radii.control),
        side: BorderSide(color: p.line),
      ),
      textStyle: textTheme.bodyMedium,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(p.card),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radii.control),
            side: BorderSide(color: p.line),
          ),
        ),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.ink,
        borderRadius: BorderRadius.circular(radii.pill),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: p.paper),
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: p.bad,
      textColor: _onColor(p.bad),
    ),
    extensions: [
      FestenaoTokens(
        palette: palette,
        radii: radii,
        monoFamily: monoFamily,
        monoLabels: monoLabels,
      ),
    ],
  );
}

/// Black or white, whichever reads on [color].
Color _onColor(Color color) =>
    color.computeLuminance() > 0.45 ? const Color(0xFF111111) : Colors.white;
