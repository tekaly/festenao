// 0, 1, 2
import 'package:flutter/material.dart';

const _kDefaultSize = 24.0;

/// Festenao icon set with color
class FestenaoIconAndColor {
  /// Icon data
  final IconData icon;

  /// Color
  final Color color;

  /// Constructor
  FestenaoIconAndColor(this.icon, this.color);

  /// Widget
  Icon iconWidget({double? size}) {
    size ??= _kDefaultSize;
    return Icon(
      fill: 1,
      icon, // Or Icons.sentiment_very_satisfied
      color: color, // Apply your desired color here
      size: size, // Adjust size as needed
    );
  }
}

/// Festenao icon set with color helpers
extension FestenaoIconAndColorListExt on List<FestenaoIconAndColor> {
  /// Reverse the color
  List<FestenaoIconAndColor> get colorReversed {
    return indexed.map((e) {
      var index = e.$1;
      var element = e.$2;
      var other = this[length - index - 1];
      return FestenaoIconAndColor(element.icon, other.color);
    }).toList();
  }

  /// Reverse the icon
  List<FestenaoIconAndColor> get iconReversed {
    return indexed.map((e) {
      var index = e.$1;
      var element = e.$2;
      var other = this[length - index - 1];

      return FestenaoIconAndColor(other.icon, element.color);
    }).toList();
  }
}

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

/// Color sets
var colorsRedToGreenSet5 = [
  Colors.red,
  Colors.orange,
  Colors.yellow,
  Colors.lightGreen,
  Colors.green,
];

/// Color sets
var colorsRedToGreenSet3 = [Colors.red, Colors.yellow, Colors.green];

/// Build helpers
extension FestenaoIconDataListExt on List<IconData> {
  /// Returns a list of FestenaoIconAndColor
  List<FestenaoIconAndColor> toFestenaoIconAndColor(List<Color> colors) {
    return indexed.map((e) {
      var index = e.$1;
      var icon = e.$2;
      var color = colors[index];
      return FestenaoIconAndColor(icon, color);
    }).toList();
  }
}
