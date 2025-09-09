import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tekartik_app_flutter_common_utils/color.dart';

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

/// Dart theme
ThemeData poppinsThemeData1({Color? seedColor}) {
  return themeData1(
    fontFamily: GoogleFonts.poppins().fontFamily,
    seedColor: seedColor,
  );
}

/// Dark theme
ThemeData themeData1({
  TextTheme? textTheme,
  String? fontFamily,
  Color? seedColor,
}) {
  seedColor ??= colorFestenaoBlue;
  var isSeedColorDark = seedColor.isDark;
  var seedTextColor = isSeedColorDark ? Colors.white : Colors.black;
  var themeData = ThemeData(
    fontFamily: fontFamily,
    textTheme: textTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
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
    textTheme: textTheme.copyWith(labelSmall: TextStyle(color: seedColor)),
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
