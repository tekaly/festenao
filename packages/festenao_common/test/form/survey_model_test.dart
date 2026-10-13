import 'package:festenao_common/form/tk_form_db.dart';
import 'package:test/test.dart';

void main() {
  test('survey answer date', () {
    var answer = CvSurveyAnswer()
      ..id.v = 'q1'
      ..answerDate.v = '2025-02-25';
    expect(answer.toMap(), {'id': 'q1', 'date': '2025-02-25'});
  });
}
