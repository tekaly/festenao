import 'package:festenao_kiosk/festenao_kiosk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_app_flutter_idb/sdb.dart';
import 'package:tekartik_prefs_sdb/prefs.dart';

FestenaoKioskController _newController() => FestenaoKioskController(
  prefsFactory: getPrefsFactorySdb(sdbFactoryMemory),
  prefsName: 'festenao_kiosk_test_${DateTime.now().microsecondsSinceEpoch}',
);

void main() {
  test('passcode defaults to the sanitized default passcode', () async {
    var controller = _newController();
    await controller.ready;
    expect(controller.passcodeOrNull, isNull);
    expect(controller.passcode, '0000');
  });

  test('setPasscode persists and sanitizes on read', () async {
    var controller = _newController();
    await controller.ready;

    await controller.setPasscode('12ab34');
    expect(controller.passcodeOrNull, '12ab34');
    expect(controller.passcode, '1234');
  });

  test('a custom default passcode is sanitized too', () async {
    var controller = FestenaoKioskController(
      prefsFactory: getPrefsFactorySdb(sdbFactoryMemory),
      prefsName:
          'festenao_kiosk_test_default_${DateTime.now().microsecondsSinceEpoch}',
      defaultPasscode: '99',
    );
    await controller.ready;
    expect(controller.passcode, '9900');
  });
}
