import 'dart:async';

import 'package:festenao_kiosk/festenao_kiosk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_prefs_sdb/prefs.dart';

/// Memory prefs whose open waits for [gate].
class _GatedPrefsFactory implements PrefsFactory {
  final gate = Completer<void>();
  final _delegate = newPrefsFactoryMemory();

  /// Stores a passcode before the gated open.
  Future<void> storePasscode(String name, String passcode) async {
    var prefs = await _delegate.openPreferences(name);
    prefs.setString('passcode', passcode);
    await prefs.save();
  }

  @override
  bool get hasStorage => false;

  @override
  Future<void> deletePreferences(String name) =>
      _delegate.deletePreferences(name);

  @override
  Future<Prefs> openPreferences(
    String name, {
    int? version,
    PrefsOnVersionChangedFunction? onVersionChanged,
  }) async {
    await gate.future;
    return _delegate.openPreferences(
      name,
      version: version,
      onVersionChanged: onVersionChanged,
    );
  }
}

Widget _app(FestenaoKioskController controller) => FestenaoKioskScope(
  controller: controller,
  child: MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => controller.goToSettings(context),
          child: const Text('Open settings'),
        ),
      ),
    ),
  ),
);

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.text('Open settings'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('saving the untouched settings keeps the default passcode', (
    tester,
  ) async {
    var controller = FestenaoKioskController(
      prefsFactory: newPrefsFactoryMemory(),
      defaultPasscode: '2468',
    );
    await controller.ready;
    await tester.pumpWidget(_app(controller));
    await _openSettings(tester);
    expect(find.byType(FestenaoKioskSettingsScreen), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Was '0000': the empty field was saved.
    expect(controller.passcode, '2468');
  });

  testWidgets('a passcode of the wrong length is not saved', (tester) async {
    var controller = FestenaoKioskController(
      prefsFactory: newPrefsFactoryMemory(),
    );
    await controller.ready;
    await tester.pumpWidget(_app(controller));
    await _openSettings(tester);

    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Was saved as '12', the code to enter became '1200'.
    expect(controller.passcodeOrNull, isNull);
    expect(controller.passcode, '0000');
    expect(find.byType(FestenaoKioskSettingsScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1357');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.passcode, '1357');
    expect(find.byType(FestenaoKioskSettingsScreen), findsNothing);
  });

  testWidgets('closing the settings before the prefs are ready', (
    tester,
  ) async {
    var factory = _GatedPrefsFactory();
    var controller = FestenaoKioskController(prefsFactory: factory);
    await factory.storePasscode(controller.prefsName, '1234');
    await tester.pumpWidget(_app(controller));
    await _openSettings(tester);
    expect(find.byType(FestenaoKioskSettingsScreen), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FestenaoKioskSettingsScreen), findsNothing);

    // Used to set the text of the disposed TextEditingController.
    factory.gate.complete();
    await controller.ready;
    await tester.pump();
  });
}
