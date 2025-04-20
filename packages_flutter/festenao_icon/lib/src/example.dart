import 'package:festenao_icon/icon.dart';
import 'package:festenao_icon/src/mood.dart';
import 'package:flutter/material.dart';

/// All icons from the Festenao icon set
class FestenaoAllIcons extends StatelessWidget {
  /// Default size
  final double? size;

  /// Constructor
  const FestenaoAllIcons({super.key, this.size});

  @override
  Widget build(BuildContext context) {
    var iconsSets = [
      festenaoIconMoodSet5,
      festenaoIconMoodSet3,
      festenaoIconMoodSet5Filled,
      festenaoIconMoodSet3Filled,
      festenaoIconMoodSetFilled,
      festenaoIconFrequencySet5,
    ];
    return Column(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (var iconSet in iconsSets)
              Wrap(
                children:
                    FestenaoIconSet(size: size, iconSet: iconSet).allIcons(),
              ),
          ],
        ),
      ],
    );
  }
}
