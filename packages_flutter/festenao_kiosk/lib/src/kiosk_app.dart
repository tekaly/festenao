import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_idb/sdb.dart';
import 'package:tekartik_prefs_sdb/prefs.dart';

import 'kiosk_controller.dart';

/// Wraps your app to provide kiosk settings (persisted via
/// `tekartik_prefs`, sdb-backed) and a passcode-protected escape hatch to
/// every descendant, without imposing a router or state-management
/// framework.
///
/// ```dart
/// void main() {
///   runApp(
///     FestenaoKioskApp(
///       child: MaterialApp.router(routerConfig: myRouter),
///     ),
///   );
/// }
/// ```
///
/// Access it anywhere below with `FestenaoKioskApp.of(context)`.
class FestenaoKioskApp extends StatefulWidget {
  /// The rest of your app (a `MaterialApp`, `MaterialApp.router`, ...).
  final Widget child;

  /// Sdb factory backing the prefs storage. Defaults to the platform sdb
  /// factory (sqflite on mobile/desktop, IndexedDB on web) — pass one
  /// explicitly (e.g. an in-memory factory) for tests.
  final SdbFactory? sdbFactory;

  /// Name of the prefs database. Defaults to `festenao_kiosk`.
  final String prefsName;

  /// Fallback passcode used until one is configured. Defaults to `0000`.
  final String defaultPasscode;

  /// Length of the numeric passcode. Defaults to `4`.
  final int passcodeLength;

  /// Creates a [FestenaoKioskApp].
  const FestenaoKioskApp({
    super.key,
    required this.child,
    this.sdbFactory,
    this.prefsName = 'festenao_kiosk',
    this.defaultPasscode = '0000',
    this.passcodeLength = 4,
  });

  /// Returns the [FestenaoKioskController] for the closest
  /// [FestenaoKioskApp] ancestor.
  static FestenaoKioskController of(BuildContext context) {
    var scope = context
        .dependOnInheritedWidgetOfExactType<FestenaoKioskScope>();
    assert(
      scope != null,
      'No FestenaoKioskApp found in context. '
      'Wrap your app with FestenaoKioskApp.',
    );
    return scope!.controller;
  }

  @override
  State<FestenaoKioskApp> createState() => _FestenaoKioskAppState();
}

class _FestenaoKioskAppState extends State<FestenaoKioskApp> {
  late final _controller = FestenaoKioskController(
    prefsFactory: getPrefsFactorySdb(
      widget.sdbFactory ?? getSdbFactory(packageName: 'festenao_kiosk'),
    ),
    prefsName: widget.prefsName,
    defaultPasscode: widget.defaultPasscode,
    passcodeLength: widget.passcodeLength,
  );

  @override
  Widget build(BuildContext context) {
    return FestenaoKioskScope(controller: _controller, child: widget.child);
  }
}

/// Raw [InheritedWidget] exposing a [FestenaoKioskController] to
/// descendants. Prefer `FestenaoKioskApp.of(context)` over using this
/// directly.
class FestenaoKioskScope extends InheritedWidget {
  /// The controller made available to descendants.
  final FestenaoKioskController controller;

  /// Creates a [FestenaoKioskScope].
  const FestenaoKioskScope({
    super.key,
    required this.controller,
    required super.child,
  });

  @override
  bool updateShouldNotify(FestenaoKioskScope oldWidget) =>
      controller != oldWidget.controller;
}
