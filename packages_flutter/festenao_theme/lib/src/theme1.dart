import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
ThemeData poppinsThemeData1() {
  return themeData1(fontFamily: GoogleFonts.poppins().fontFamily);
}

/// Dark theme
ThemeData themeData1({TextTheme? textTheme, String? fontFamily}) {
  var themeData = ThemeData(
    fontFamily: fontFamily,
    textTheme: textTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colorBlue,
      brightness: Brightness.dark,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
  textTheme = themeData.textTheme;

  themeData = themeData.copyWith(
    snackBarTheme: SnackBarThemeData(
      actionTextColor: colorWhite,
      contentTextStyle: textTheme.bodyMedium,
      backgroundColor: colorBlue,
      //contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      elevation: 20,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: OutlineInputBorder(borderSide: BorderSide(color: colorBlue)),
    ),
    textTheme: textTheme.copyWith(
      labelSmall: const TextStyle(color: colorBlue),
    ),
    dividerTheme: const DividerThemeData(
      color: colorGrey,
      //thickness: 2,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        textStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),

        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        backgroundColor: colorBlue, // Button color
        foregroundColor: colorWhite,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: colorFestenaoBlue,
      foregroundColor: colorWhite,
    ),
  );
  return themeData;
}
