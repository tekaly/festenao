import 'package:festenao_common/form/tk_form.dart';
import 'package:festenao_common/form/tk_form_test.dart';
import 'package:test/test.dart';

Future<void> main() async {
  group('tk_form_player', () {
    test('toDebugString()', () {
      var q = TkFormPlayerQuestion(
        id: 'q1',
        text: 'My name is?',
        options: TkFormPlayerQuestionTextOptions(emptyAllowed: true),
      );
      expect(
        q.toDebugString(),
        'PlayerQuestion(id: q1, text: My name is?, QuestionOptions(isTypeText: true, emptyAllowed: true))',
      );
      var c = TkFormPlayerQuestionChoice(
        id: '1',
        text: 'some text',
        allowOther: true,
      );
      expect(c.toDebugString(), 'QuestionChoice(id: 1, name: some text)');
    });
    test('duplicated question id', () {
      expect(
        () => TestFormPlayer(
          id: 'test',
          questions: [
            TkFormPlayerQuestion(
              id: 'q1',
              text: 'My name is?',
              options: TkFormPlayerQuestionTextOptions(emptyAllowed: true),
            ),
            TkFormPlayerQuestion(
              id: 'q1',
              text: 'My name is?',
              options: TkFormPlayerQuestionTextOptions(emptyAllowed: true),
            ),
          ],
          form: TkFormPlayerFormBase(id: 'f1', name: 'Form1'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
