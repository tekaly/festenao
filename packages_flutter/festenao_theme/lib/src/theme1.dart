import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_common_utils/color.dart';

import '../fonts/jetbrains_mono/jetbrains_mono_font.dart';
import '../fonts/poppins/poppins_font.dart';

/// Festenao theme
const colorBlue = Colors.blue;

/// Festenao blue
const colorFestenaoBlue = Colors.blue;

/// Festenao theme
const colorBlueSelected = Color(0xff1b2177);

/// Form color blue selected response
final colorFestenaoFormBlueSelected = Colors.blue[300];

/// Festenao theme
const colorWhite = Colors.white;

/// Festenao theme
const colorError = Colors.red;

/// Festenao theme
const colorGrey = Colors.grey;

/// The Poppins font family: the font of the poppins themes, for an app
/// building its own theme with it.
///
/// Bundled as a plain Flutter font (see the package's `pubspec.yaml`) rather
/// than fetched by google_fonts at runtime, so it renders the same offline,
/// in tests, and on a device with no network.
const festenaoPoppinsFontFamily = poppinsFontFamily;

/// The monospace font family the explorers draw hex dumps and raw text
/// with: JetBrains Mono, bundled the same way as [festenaoPoppinsFontFamily].
const festenaoMonospaceFontFamily = jetBrainsMonoFontFamily;

/// Dark theme with the Poppins font.
ThemeData poppinsThemeData1({Color? seedColor}) {
  return themeData1(
    fontFamily: festenaoPoppinsFontFamily,
    seedColor: seedColor,
  );
}

/// Light theme with the Poppins font.
ThemeData poppinsThemeDataLight1({Color? seedColor}) {
  return themeDataLight1(
    fontFamily: festenaoPoppinsFontFamily,
    seedColor: seedColor,
  );
}

/// Light theme: the rules of [themeData1] in light brightness.
ThemeData themeDataLight1({
  TextTheme? textTheme,
  String? fontFamily,
  Color? seedColor,
}) {
  return themeData1(
    textTheme: textTheme,
    fontFamily: fontFamily,
    brightness: Brightness.light,
    seedColor: seedColor,
  );
}

/// Dark theme (light with [brightness]): a color scheme seeded with
/// [seedColor] (the festenao blue by default), floating snack bars on the
/// seed color, outlined inputs, seed colored buttons.
ThemeData themeData1({
  TextTheme? textTheme,
  String? fontFamily,
  Brightness? brightness,
  Color? seedColor,
}) {
  brightness ??= Brightness.dark;
  seedColor ??= colorFestenaoBlue;
  var isSeedColorDark = seedColor.isDark;
  var seedTextColor = isSeedColorDark ? Colors.white : Colors.black;
  var themeData = ThemeData(
    fontFamily: fontFamily,
    textTheme: textTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
  textTheme = themeData.textTheme;

  themeData = themeData.copyWith(
    snackBarTheme: SnackBarThemeData(
      actionTextColor: seedTextColor,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: seedTextColor),
      backgroundColor: seedColor,
      behavior: SnackBarBehavior.floating,
      elevation: 20,
    ),
    inputDecorationTheme: InputDecorationTheme(
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: OutlineInputBorder(borderSide: BorderSide(color: seedColor)),
    ),
    // Only the colour of labelSmall changes: replacing the style outright
    // would drop its font family, and the small labels — badges, section
    // headers — would then be drawn in the platform font rather than in the
    // one the theme was built with.
    textTheme: textTheme.copyWith(
      labelSmall: (textTheme.labelSmall ?? const TextStyle()).copyWith(
        color: seedColor,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: colorGrey,
      //thickness: 2,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        textStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),

        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        backgroundColor: seedColor, // Button color
        foregroundColor: seedTextColor,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: seedColor,
      foregroundColor: seedTextColor,
    ),
  );
  return themeData;
}
