import 'package:festenao_kiosk/festenao_kiosk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_app_flutter_idb/sdb.dart';

class _AppUnderTest extends StatelessWidget {
  final ValueChanged<FestenaoKioskController> onController;

  const _AppUnderTest({required this.onController});

  @override
  Widget build(BuildContext context) {
    return FestenaoKioskApp(
      sdbFactory: sdbFactoryMemory,
      child: MaterialApp(
        routes: festenaoKioskRoutes,
        home: Builder(
          builder: (context) {
            onController(FestenaoKioskApp.of(context));
            return Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    FestenaoKioskApp.of(context).goToSettings(context),
                child: const Text('Open settings'),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Pumps [_AppUnderTest] and resolves the controller's `ready` future via
/// [WidgetTester.runAsync] (the sdb-backed prefs open involves real async
/// work that fake-async, used by `testWidgets`, can't advance on its own).
/// Once resolved here, further internal `await controller.ready` calls
/// (e.g. inside the settings screen) complete instantly, since it's a
/// memoized `late final` future.
Future<FestenaoKioskController> _pumpReadyApp(WidgetTester tester) async {
  late FestenaoKioskController controller;
  await tester.pumpWidget(
    _AppUnderTest(onController: (c) => controller = c),
  );
  await tester.runAsync(() => controller.ready);
  return controller;
}

void main() {
  testWidgets('FestenaoKioskApp.of resolves the controller', (tester) async {
    var controller = await _pumpReadyApp(tester);
    expect(controller.passcode, '0000');
  });

  testWidgets('goToSettings pushes the settings screen', (tester) async {
    await _pumpReadyApp(tester);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(find.byType(FestenaoKioskSettingsScreen), findsOneWidget);
    expect(find.text('Kiosk settings'), findsOneWidget);
  });

  testWidgets('saving a passcode on the settings screen persists it', (
    tester,
  ) async {
    await _pumpReadyApp(tester);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '4321');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    // Back on the start screen; re-open settings to confirm persistence.
    expect(find.byType(FestenaoKioskSettingsScreen), findsNothing);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    var field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, '4321');
  });
}
