import 'package:festenao_admin_base_app/auth/auth.dart';
import 'package:festenao_admin_base_app/firebase/firebase_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  testWidgets('local firebase sets the auth ui service', (tester) async {
    globalAuthFlutterUiServiceOrNull = null;
    await tester.runAsync(() async {
      await initFestenaoFirebaseServicesLocal(
        sembastDatabaseFactory: newDatabaseFactoryMemory(),
      );
    });
    expect(globalAuthFlutterUiServiceOrNull, isNotNull);

    // The account icon of the admin screens.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => goToAuthScreen(context),
            child: const Text('account'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('account'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
