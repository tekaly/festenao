import 'package:flutter/material.dart';

import 'kiosk_app.dart';

/// A small, easy-to-miss button — meant for a corner of a kiosk-mode
/// screen — that only calls [onUnlocked] after the configured passcode is
/// entered correctly. Nothing happens if the passcode entry is
/// cancelled or wrong.
class FestenaoKioskEscapeButton extends StatelessWidget {
  /// Called once the correct passcode has been entered.
  final VoidCallback onUnlocked;

  /// Icon/child shown for the button. Defaults to a small, low-contrast
  /// lock icon so it doesn't draw attention on the kiosk screen.
  final Widget? child;

  /// Creates a [FestenaoKioskEscapeButton].
  const FestenaoKioskEscapeButton({
    super.key,
    required this.onUnlocked,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon:
          child ??
          Icon(Icons.circle, size: 12, color: Colors.white.withValues(alpha: 0.08)),
      onPressed: () async {
        var unlocked = await FestenaoKioskApp.of(context).checkPasscode(context);
        if (unlocked) {
          onUnlocked();
        }
      },
    );
  }
}
