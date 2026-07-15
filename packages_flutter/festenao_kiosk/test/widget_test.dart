import 'package:festenao_kiosk/festenao_kiosk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_app_flutter_idb/sdb.dart';

void main() {
  testWidgets('FestenaoKioskApp.of resolves the controller', (tester) async {
    late FestenaoKioskController controller;
    await tester.pumpWidget(
      FestenaoKioskApp(
        sdbFactory: sdbFactoryMemory,
        child: Builder(
          builder: (context) {
            controller = FestenaoKioskApp.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(controller, isNotNull);
    // The sdb-backed prefs open involves real async work that fake-async
    // (used by testWidgets) can't advance on its own — hop out via
    // runAsync, same as a real app would resolve it on the real event loop.
    await tester.runAsync(() => controller.ready);
    expect(controller.passcode, '0000');
  });

  testWidgets('goToSettings pushes a FestenaoKioskSettingsScreen', (
    tester,
  ) async {
    late FestenaoKioskController controller;
    await tester.pumpWidget(
      FestenaoKioskApp(
        sdbFactory: sdbFactoryMemory,
        child: MaterialApp(
          routes: festenaoKioskRoutes,
          home: Builder(
            builder: (context) {
              controller = FestenaoKioskApp.of(context);
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () => controller.goToSettings(context),
                  child: const Text('Open settings'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.runAsync(() => controller.ready);

    await tester.tap(find.text('Open settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FestenaoKioskSettingsScreen), findsOneWidget);
    expect(find.text('Kiosk settings'), findsOneWidget);
  });
}
