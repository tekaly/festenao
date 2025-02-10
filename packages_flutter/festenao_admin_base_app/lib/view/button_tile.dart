import 'package:flutter/material.dart';

class ButtonTile extends StatelessWidget {
  final Widget child;

  const ButtonTile({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: child,
      ),
    );
  }
}
