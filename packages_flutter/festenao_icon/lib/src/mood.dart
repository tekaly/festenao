// 0, 1, 2
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

const _kDefaultSize = 24.0;

/// Festenao icon set with color
class FestenaoIconAndColor {
  /// Icon data
  final IconData icon;

  /// Color
  final Color color;

  /// Constructor
  FestenaoIconAndColor(this.icon, this.color);
}

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
  FestenaoIconAndColor(Symbols.sentiment_very_satisfied, Colors.green),
  FestenaoIconAndColor(Symbols.sentiment_satisfied, Colors.lightGreen),
  FestenaoIconAndColor(Symbols.sentiment_neutral, Colors.yellow),
  FestenaoIconAndColor(Symbols.sentiment_dissatisfied_rounded, Colors.orange),
  FestenaoIconAndColor(Symbols.sentiment_extremely_dissatisfied, Colors.red),
];

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
];

/// Festenao icon set with color
class FestenaoIconSet {
  ///  Set
  final List<FestenaoIconAndColor> iconSet;

  /// Default size
  final double size;

  /// Constructor
  FestenaoIconSet({double? size, required this.iconSet})
    : size = size ?? _kDefaultSize;

  /// Returns an icon from the set
  Widget icon(int index, {double? size}) {
    size ??= this.size;
    var ic = iconSet[index % iconSet.length];
    return Icon(
      fill: 1,
      ic.icon, // Or Icons.sentiment_very_satisfied
      color: ic.color, // Apply your desired color here
      size: size, // Adjust size as needed
    );
  }

  /// Returns a list of all icons in the set
  List<Widget> allIcons({double? size}) {
    return List.generate(iconSet.length, (index) {
      return icon(index, size: size);
    });
  }
}
