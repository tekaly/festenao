import 'package:festenao_kiosk/festenao_kiosk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps exactly length digits, dropping non-digits', () {
    expect(kioskSanitizePasscode('12ab34'), '1234');
    expect(kioskSanitizePasscode('1-2-3-4'), '1234');
  });

  test('pads short input with trailing zeros', () {
    expect(kioskSanitizePasscode('7'), '7000');
    expect(kioskSanitizePasscode(''), '0000');
  });

  test('truncates long input to the requested length', () {
    expect(kioskSanitizePasscode('123456'), '1234');
  });

  test('supports a custom length', () {
    expect(kioskSanitizePasscode('12', length: 6), '120000');
    expect(kioskSanitizePasscode('1234567', length: 6), '123456');
  });
}
