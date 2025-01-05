import 'package:flutter/material.dart';

/// Convenient linear wait
class LinearWait extends StatelessWidget {
  final ValueNotifier<bool>? showNotifier;
  final bool? show;

  LinearWait({super.key, this.showNotifier, this.show}) {
    if (showNotifier != null) {
      assert(show == null, 'Cannot have both showNotifier and show set');
    }
  }
  @override
  Widget build(BuildContext context) {
    if (showNotifier == null) {
      return (show ?? true) ? const LinearProgressIndicator() : Container();
    } else {
      return ValueListenableBuilder<bool>(
          valueListenable: showNotifier!,
          builder: (context, saving, _) {
            return LinearWait(
              show: saving,
            );
          });
    }
  }
}
