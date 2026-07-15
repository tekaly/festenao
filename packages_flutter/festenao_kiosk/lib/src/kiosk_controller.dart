import 'package:flutter/material.dart';
import 'package:flutter_screen_lock/flutter_screen_lock.dart';
import 'package:tekartik_prefs_sdb/prefs.dart';

import 'kiosk_settings_screen.dart';

const _passcodeKey = 'passcode';

/// Sanitizes a raw passcode into a fixed-length digit string, matching
/// what [flutter_screen_lock]'s default numeric keypad expects. Non-digit
/// characters are dropped; missing digits are padded with the tail of
/// `'0000000000'`.
String kioskSanitizePasscode(String raw, {int length = 4}) {
  var digits = raw
      .split('')
      .where((c) => RegExp(r'^[0-9]$').hasMatch(c))
      .join();
  if (digits.length >= length) {
    return digits.substring(0, length);
  }
  return (digits + '0' * length).substring(0, length);
}

/// Settings and navigation helpers for a [FestenaoKioskApp]. Obtain one
/// via `FestenaoKioskApp.of(context)`.
class FestenaoKioskController {
  /// Prefs storage (sdb-backed, see `tekartik_prefs_sdb`).
  final PrefsFactory prefsFactory;

  /// Name of the prefs database.
  final String prefsName;

  /// Fallback passcode used until one is configured (and to backfill
  /// missing digits — see [kioskSanitizePasscode]).
  final String defaultPasscode;

  /// Length of the numeric passcode.
  final int passcodeLength;

  Prefs? _prefsOrNull;

  /// Creates a controller. Normally you don't build this directly — use
  /// [FestenaoKioskApp] instead.
  FestenaoKioskController({
    required this.prefsFactory,
    this.prefsName = 'festenao_kiosk',
    this.defaultPasscode = '0000',
    this.passcodeLength = 4,
  });

  /// Completes once prefs are loaded. All getters are safe to call before
  /// this completes (they simply return defaults), but setters that need
  /// to persist should be awaited after this future.
  late final ready = () async {
    _prefsOrNull = await prefsFactory.openPreferences(prefsName);
  }();

  /// Raw stored passcode, if one has ever been saved.
  String? get passcodeOrNull => _prefsOrNull?.getString(_passcodeKey);

  /// The passcode currently in effect (sanitized, always [passcodeLength]
  /// digits long).
  String get passcode => kioskSanitizePasscode(
    passcodeOrNull ?? defaultPasscode,
    length: passcodeLength,
  );

  /// Updates and persists the passcode.
  Future<void> setPasscode(String value) async {
    await ready;
    _prefsOrNull!.setString(_passcodeKey, value);
    await _prefsOrNull!.save();
  }

  /// Pushes the kiosk settings screen.
  Future<void> goToSettings(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const FestenaoKioskSettingsScreen(),
      ),
    );
  }

  /// Shows the passcode entry screen and returns whether it was unlocked
  /// (i.e. the correct passcode was entered). Use this to guard a
  /// "private escape" action (e.g. a hidden corner button that exits
  /// kiosk mode) — see `FestenaoKioskEscapeButton`.
  Future<bool> checkPasscode(BuildContext context) async {
    await ready;
    if (!context.mounted) {
      return false;
    }
    var unlocked = false;
    await screenLock(
      context: context,
      title: const Text('Enter code'),
      cancelButton: const Text('Cancel'),
      correctString: passcode,
      onUnlocked: () {
        unlocked = true;
        Navigator.of(context).pop();
      },
    );
    return unlocked;
  }
}
