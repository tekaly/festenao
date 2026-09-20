---
name: festenao-icon-sets
description: >-
  Use when a Festenao Flutter app shows a rated / graded icon (mood smileys,
  signal strength, red-to-green scales) and needs a colored icon picked by
  index: FestenaoIconSet (icon(index), allIcons()), FestenaoIconAndColor
  (iconWidget), FestenaoIconAndColorListExt (colorReversed, iconReversed), the
  ready made sets festenaoIconMoodSet3, festenaoIconMoodSet5,
  festenaoIconMoodSet3Filled, festenaoIconMoodSet5Filled,
  festenaoIconFrequencySet5, and the FestenaoAllIcons gallery widget from
  package:festenao_icon/icon.dart.
---

# Icon sets (festenao_icon)

`festenao_icon` is a tiny Flutter helper around `material_symbols_icons`: it
pairs an `IconData` with a `Color` and groups those pairs into ordered sets, so
a rating (0..n) maps to a colored icon without any conditional code in the UI.

## Guidelines

* Dependency (not on pub.dev, git only):

  ```yaml
  dependencies:
    festenao_icon:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_icon
  ```

* Single import: `package:festenao_icon/icon.dart`. Never import
  `package:festenao_icon/src/...` (the `test/` files do, the package's own
  code may; app code must not).
* `FestenaoIconAndColor(icon, color)` is the pair: positional args, fields
  `icon` and `color`, and `iconWidget({double? size})` returning a filled
  `Icon` (default size 24). A set is just a `List<FestenaoIconAndColor>`.
* `FestenaoIconSet({double? size, required List<FestenaoIconAndColor> iconSet})`
  is the renderer:
  * `icon(int index, {double? size})` returns the widget for that entry, with
    **modulo indexing** (`index % iconSet.length`), so an out of range rating
    wraps instead of throwing — clamp yourself if that is wrong for your data.
  * `allIcons({double? size})` returns `List<Widget>`, one per entry, ready to
    drop into a `Row`/`Wrap`.
  * `size` defaults to 24.0 and is overridable per call.
* Ready made sets exported by the library, all ordered worst → best:
  * `festenaoIconMoodSet3` / `festenaoIconMoodSet5`: material `Icons.sentiment_*`
    smileys, red → green (3 or 5 steps).
  * `festenaoIconMoodSet3Filled` / `festenaoIconMoodSet5Filled`: the same scale
    with `material_symbols_icons` `Symbols.sentiment_*` glyphs.
  * `festenaoIconFrequencySet5`: `Symbols.do_not_disturb` then
    `signal_cellular_*`, for a never → always frequency scale.
* Reverse a scale with the list extension `FestenaoIconAndColorListExt`:
  `colorReversed` keeps the icons and mirrors the colors (green → red),
  `iconReversed` keeps the colors and mirrors the icons. Both return a new
  list; they do not mutate.
* `FestenaoAllIcons({double? size})` is a gallery `StatelessWidget` showing
  every built-in set in `Wrap` rows; use it in a debug/preview screen only (it
  is unbounded in height, put it inside a `ListView` or a `Column` in a
  scrollable, as `example/lib/main.dart` does).
* Not part of the public API even though `lib/src/icon_set.dart` defines them:
  `colorsRedToGreenSet3`, `colorsRedToGreenSet5`, the
  `FestenaoIconDataListExt.toFestenaoIconAndColor(colors)` builder and
  `festenaoIconMoodSetFilled`. To build a custom set from `package:festenao_icon/icon.dart`,
  construct the `FestenaoIconAndColor` entries yourself.
* The icons rendered by `FestenaoIconSet` / `FestenaoIconAndColor.iconWidget`
  are built with `fill: 1`; that only has an effect on variable fonts such as
  `Symbols.*` — plain `Icons.*` entries are unaffected.
* Tests: this is pure widget code, testable with `flutter_test` alone. The set
  math (`colorReversed`, `iconReversed`, modulo indexing) is checked in
  `test/icon_set_test.dart` with plain `test()` — no `WidgetTester` needed,
  `icon(i)` can be cast to `Icon` and its `icon`/`color` asserted.

## Examples

### A rating row driven by a value

```dart
import 'package:festenao_icon/icon.dart';
import 'package:flutter/material.dart';

/// Shows the 5 mood icons, highlighting the selected one.
class MoodPicker extends StatelessWidget {
  /// Current value, 0..4.
  final int value;

  /// Called with the new value.
  final ValueChanged<int> onChanged;

  /// Constructor.
  const MoodPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    var set = FestenaoIconSet(size: 32, iconSet: festenaoIconMoodSet5Filled);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var (index, _) in festenaoIconMoodSet5Filled.indexed)
          IconButton(
            onPressed: () => onChanged(index),
            icon: Opacity(
              opacity: index == value ? 1 : 0.4,
              child: set.icon(index),
            ),
          ),
      ],
    );
  }
}
```

### One icon for a score, with a safe index

```dart
import 'package:festenao_icon/icon.dart';
import 'package:flutter/material.dart';

/// Frequency icon for [count] occurrences (never, rare, ... , always).
///
/// [FestenaoIconSet.icon] wraps out of range indexes, so clamp first.
Widget frequencyIcon(int count, {double? size}) {
  var set = FestenaoIconSet(iconSet: festenaoIconFrequencySet5);
  var index = count.clamp(0, festenaoIconFrequencySet5.length - 1);
  return set.icon(index, size: size);
}
```

### A custom set, and the reversed scale

```dart
import 'package:festenao_icon/icon.dart';
import 'package:flutter/material.dart';

/// A 3 step battery scale, plus the same icons with mirrored colors.
class BatteryScale extends StatelessWidget {
  /// Constructor.
  const BatteryScale({super.key});

  @override
  Widget build(BuildContext context) {
    var scale = <FestenaoIconAndColor>[
      FestenaoIconAndColor(Icons.battery_1_bar, Colors.red),
      FestenaoIconAndColor(Icons.battery_4_bar, Colors.orange),
      FestenaoIconAndColor(Icons.battery_full, Colors.green),
    ];
    return Column(
      children: [
        Wrap(children: FestenaoIconSet(iconSet: scale).allIcons(size: 32)),
        // Same glyphs, colors mirrored (green, orange, red).
        Wrap(
          children: FestenaoIconSet(
            iconSet: scale.colorReversed,
          ).allIcons(size: 32),
        ),
        // A single pair can also build its own widget.
        scale.last.iconWidget(size: 48),
      ],
    );
  }
}
```

### Debug gallery of every built-in set

```dart
import 'package:festenao_icon/icon.dart';
import 'package:flutter/material.dart';

/// Debug screen listing all the festenao icon sets.
class IconGalleryScreen extends StatelessWidget {
  /// Constructor.
  const IconGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Festenao icons')),
    body: ListView(
      children: const [
        FestenaoAllIcons(size: 32),
        FestenaoAllIcons(size: 64),
      ],
    ),
  );
}
```
