import 'package:festenao_admin_base_app/theme/color.dart';
import 'package:flutter/material.dart';

double get editLabelSmallFontSize => 13;
double get labelSmallFontSize => editLabelSmallFontSize;
TextStyle get infoValueTextStyle =>
    const TextStyle(color: colorAdminLightBlue, fontSize: 16);

TextStyle get errorTextStyle => TextStyle(
      color: Colors.red[400],
      fontSize: 13,
    );
TextStyle get infoLabelTextStyle => TextStyle(
    color: colorAdminLightBlue,
    fontSize: labelSmallFontSize,
    fontWeight: FontWeight.normal);
