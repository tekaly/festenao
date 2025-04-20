// 0, 1, 2
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'icon_set.dart';

/// Festenao icon set with color
final festenaoIconMoodSet3 = [
  FestenaoIconAndColor(Icons.sentiment_satisfied, Colors.green),
  FestenaoIconAndColor(Icons.sentiment_neutral, Colors.yellow),
  FestenaoIconAndColor(Icons.sentiment_dissatisfied, Colors.red),
];

/// Festenao icon set with color
final festenaoIconMoodSet5 = [
  FestenaoIconAndColor(Icons.sentiment_very_satisfied, Colors.green),
  FestenaoIconAndColor(Icons.sentiment_satisfied, Colors.lightGreen),
  FestenaoIconAndColor(Icons.sentiment_neutral, Colors.yellow),
  FestenaoIconAndColor(Icons.sentiment_dissatisfied, Colors.orange),
  FestenaoIconAndColor(Icons.sentiment_very_dissatisfied, Colors.red),
];

/// Festenao icon set with color
final festenaoIconMoodSet5Filled = [
  Symbols.sentiment_extremely_dissatisfied,
  Symbols.sentiment_dissatisfied,
  Symbols.sentiment_neutral,
  Symbols.sentiment_very_satisfied,
  Symbols.sentiment_satisfied,
].toFestenaoIconAndColor(colorsRedToGreenSet5);

/// Festenao icon set with color
final festenaoIconMoodSet3Filled = [
  FestenaoIconAndColor(Symbols.sentiment_satisfied, Colors.green),

  FestenaoIconAndColor(Symbols.sentiment_neutral, Colors.yellow),

  FestenaoIconAndColor(Symbols.sentiment_dissatisfied, Colors.red),
];

/// Festenao icon set with color
final festenaoIconMoodSetFilled = [
  FestenaoIconAndColor(Symbols.sentiment_very_satisfied, Colors.green),
  FestenaoIconAndColor(Symbols.sentiment_very_satisfied_rounded, Colors.green),
  FestenaoIconAndColor(Symbols.sentiment_very_satisfied_sharp, Colors.green),
  FestenaoIconAndColor(Symbols.sentiment_satisfied, Colors.lightGreen),
  FestenaoIconAndColor(Symbols.sentiment_satisfied_rounded, Colors.lightGreen),
  FestenaoIconAndColor(Symbols.sentiment_satisfied_sharp, Colors.lightGreen),
  FestenaoIconAndColor(Symbols.sentiment_neutral, Colors.yellow),
  FestenaoIconAndColor(Symbols.sentiment_neutral_rounded, Colors.yellow),
  FestenaoIconAndColor(Symbols.sentiment_neutral_sharp, Colors.yellow),
  FestenaoIconAndColor(Symbols.sentiment_dissatisfied, Colors.orange),
  FestenaoIconAndColor(Symbols.sentiment_dissatisfied_rounded, Colors.orange),
  FestenaoIconAndColor(Symbols.sentiment_dissatisfied_sharp, Colors.orange),
  FestenaoIconAndColor(Symbols.sentiment_extremely_dissatisfied, Colors.red),
  FestenaoIconAndColor(
    Symbols.sentiment_extremely_dissatisfied_rounded,
    Colors.red,
  ),
  FestenaoIconAndColor(
    Symbols.sentiment_extremely_dissatisfied_sharp,
    Colors.red,
  ),
  FestenaoIconAndColor(Symbols.sentiment_calm, Colors.red),
  FestenaoIconAndColor(Symbols.sentiment_content, Colors.red),
  FestenaoIconAndColor(Symbols.sentiment_excited, Colors.red),
  FestenaoIconAndColor(Symbols.sentiment_frustrated, Colors.red),
  FestenaoIconAndColor(Symbols.sentiment_sad, Colors.red),
  FestenaoIconAndColor(Symbols.sentiment_stressed, Colors.red),
  FestenaoIconAndColor(Symbols.sentiment_worried, Colors.red),
];
