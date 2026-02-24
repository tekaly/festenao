import 'package:festenao_icon/src/icon_set.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('icon_set', () {
    test('FestenaoIconAndColor', () {
      var iconAndColor = FestenaoIconAndColor(Icons.add, Colors.red);
      expect(iconAndColor.icon, Icons.add);
      expect(iconAndColor.color, Colors.red);
    });

    test('FestenaoIconAndColorListExt', () {
      var list = [
        FestenaoIconAndColor(Icons.add, Colors.red),
        FestenaoIconAndColor(Icons.remove, Colors.green),
      ];

      var colorReversed = list.colorReversed;
      expect(colorReversed[0].icon, Icons.add);
      expect(colorReversed[0].color, Colors.green);
      expect(colorReversed[1].icon, Icons.remove);
      expect(colorReversed[1].color, Colors.red);

      var iconReversed = list.iconReversed;
      expect(iconReversed[0].icon, Icons.remove);
      expect(iconReversed[0].color, Colors.red);
      expect(iconReversed[1].icon, Icons.add);
      expect(iconReversed[1].color, Colors.green);
    });

    test('FestenaoIconSet', () {
      var list = [
        FestenaoIconAndColor(Icons.add, Colors.red),
        FestenaoIconAndColor(Icons.remove, Colors.green),
      ];
      var iconSet = FestenaoIconSet(iconSet: list);
      expect(iconSet.iconSet, list);
      expect(iconSet.size, 24.0);

      // Test modulo indexing
      var widget = iconSet.icon(2) as Icon;
      expect(widget.icon, Icons.add);
      expect(widget.color, Colors.red);

      var all = iconSet.allIcons();
      expect(all.length, 2);
    });

    test('FestenaoIconDataListExt', () {
      var icons = [Icons.add, Icons.remove];
      var colors = [Colors.red, Colors.green];
      var list = icons.toFestenaoIconAndColor(colors);

      expect(list.length, 2);
      expect(list[0].icon, Icons.add);
      expect(list[0].color, Colors.red);
      expect(list[1].icon, Icons.remove);
      expect(list[1].color, Colors.green);
    });
  });
}
