import 'package:festenao_base_app/form/src/screen/question_int_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('int question min and max', () {
    String? validate(String? value) =>
        formQuestionIntValidator(value, emptyAllowed: false, min: 1, max: 10);
    expect(validate('5'), isNull);
    expect(validate('1'), isNull);
    expect(validate('10'), isNull);
    expect(validate('0'), 'Minimum 1');
    expect(validate('11'), 'Maximum 10');
    expect(validate('abc'), 'Veuillez saisir un nombre');
    expect(validate(' '), 'Veuillez saisir une valeur');
    expect(formQuestionIntValidator(null, emptyAllowed: true, max: 10), isNull);
  });
}
