import 'package:flutter/material.dart';

var leadingIconSize = 38.0;

var editIconSize = 25.0;

class CenteredLeading extends StatelessWidget {
  final Widget child;

  const CenteredLeading({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [child]);
  }
}

class IconLeading extends StatelessWidget {
  final IconData iconData;
  final Color? color;
  final double? size;

  const IconLeading({super.key, required this.iconData, this.color, this.size});

  @override
  Widget build(BuildContext context) {
    return CenteredLeading(
        child: SizedBox(
            width: size ?? leadingIconSize,
            height: size ?? leadingIconSize,
            child: Center(
              child: Icon(
                iconData,
                color: color,
              ),
            )));
  }
}
