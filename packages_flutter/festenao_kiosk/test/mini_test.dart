import 'package:festenao_kiosk/festenao_kiosk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_app_flutter_idb/sdb.dart';

void main() {
  testWidgets('debug settings nav', (tester) async {
    late FestenaoKioskController controller;
    await tester.pumpWidget(
      FestenaoKioskApp(
        sdbFactory: sdbFactoryMemory,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              controller = FestenaoKioskApp.of(context);
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
      ),
    );
    await tester.runAsync(() => controller.ready);
    // print('ready resolved: ${controller.passcodeOrNull}');

    await tester.tap(find.text('Open settings'));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      // print('pump $i: loading=${find.byType(CircularProgressIndicator).evaluate().isNotEmpty} settings=${find.byType(FestenaoKioskSettingsScreen).evaluate().isNotEmpty} textfields=${find.byType(TextField).evaluate().length}');
    }
  });
}
