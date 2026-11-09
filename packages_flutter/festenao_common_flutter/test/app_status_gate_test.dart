import 'dart:async';

import 'package:festenao_common_flutter/app_status_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late StreamController<FestenaoAppStatus> controller;

  Widget app({bool canBypass = false, Locale locale = const Locale('en')}) =>
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => FestenaoAppStatusGate(
          status: controller.stream,
          canBypass: canBypass,
          child: child!,
        ),
        home: const Scaffold(body: Text('the app')),
      );

  // Created in the test body: its events then go through the fake async
  // zone of the test (one pump delivers them).
  void newController() {
    controller = StreamController<FestenaoAppStatus>();
    addTearDown(controller.close);
  }

  testWidgets('normal, read only, maintenance', (tester) async {
    newController();
    await tester.pumpWidget(app());
    // Below, two pumps per change: the status event may land after the build
    // of the first frame, the second one shows it.
    // Normal until a status comes.
    expect(find.text('the app'), findsOneWidget);

    controller.add(
      const FestenaoAppStatus(mode: FestenaoAppStatusMode.readOnly),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('the app'), findsOneWidget);
    expect(find.byType(FestenaoAppStatusBanner), findsOneWidget);

    controller.add(
      const FestenaoAppStatus(
        mode: FestenaoAppStatusMode.maintenance,
        message: 'Back at 6 pm',
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('the app'), findsNothing);
    expect(find.text('Under maintenance'), findsOneWidget);
    expect(find.text('Back at 6 pm'), findsOneWidget);

    controller.add(FestenaoAppStatus.normal);
    await tester.pump();
    await tester.pump();
    expect(find.text('the app'), findsOneWidget);
    expect(find.byType(FestenaoAppStatusBanner), findsNothing);
  });

  testWidgets('maintenance in French, bypassed by an admin', (tester) async {
    newController();
    await tester.pumpWidget(app(canBypass: true, locale: const Locale('fr')));
    controller.add(
      const FestenaoAppStatus(
        mode: FestenaoAppStatusMode.maintenance,
        messages: {'fr': 'Retour à 18 h', 'en': 'Back at 6 pm'},
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Maintenance en cours'), findsOneWidget);
    expect(find.text('Retour à 18 h'), findsOneWidget);

    await tester.tap(find.text('Continuer (administrateur)'));
    await tester.pump();
    await tester.pump();
    expect(find.text('the app'), findsOneWidget);
    // Still reminded.
    expect(find.byType(FestenaoAppStatusBanner), findsOneWidget);
  });
}
