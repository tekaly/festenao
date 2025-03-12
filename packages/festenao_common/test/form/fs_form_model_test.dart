// ignore_for_file: inference_failure_on_collection_literal

import 'package:cv/cv.dart';
import 'package:dev_test/dev_test.dart';
import 'package:festenao_common/form/src/fs_form_model.dart';

Model _fill<T extends CvModel>() =>
    (cvNewModel<T>()..fillModel(cvFillOptions1)).toMap();
Future<void> main() async {
  initFsFormBuilders();
  group('form', () {
    test('fill', () {
      expect(_fill<FsFormQuestion>(), isNotEmpty);
      expect(_fill<CvFormProposedAnswer>(), {
        'answerEmptyAllowed': false,
        'answerType': 'text_2',
        'answerChoices': [
          {'id': 'text_3', 'text': 'text_4'},
        ],
        'answerIntMin': 5,
        'answerIntMax': 6,
        'answerIntPresets': [7],
      });
      expect(_fill<FsForm>(), {
        'title': 'text_1',
        'questions': [
          {'id': 'text_2', 'subFormId': 'text_3'},
        ],
      });
      expect(_fill<CvFormQuestionResponse>(), {
        'id': 'text_1',
        'answerType': 'text_2',
        'int': 3,
        'text': 'text_4',
        'choiceId': 'text_5',
        'choiceIds': ['text_6'],
        'subForm': [
          {
            'id': 'text_7',
            'answerType': 'text_8',
            'int': 9,
            'text': 'text_10',
            'choiceId': 'text_11',
            'choiceIds': ['text_12'],
            'subForm': [{}],
          },
        ],
      });
      expect(_fill<FsFormQuestion>(), {
        'name': 'text_1',
        'slug': 'text_2',
        'text': 'text_3',
        'hint': 'text_4',
        'proposedAnswer': {
          'answerEmptyAllowed': false,
          'answerType': 'text_6',
          'answerChoices': [
            {'id': 'text_7', 'text': 'text_8'},
          ],
          'answerIntMin': 9,
          'answerIntMax': 10,
          'answerIntPresets': [11],
        },
        'proposedAnswerId': 'text_12',
      });
      expect(cvNewModel<FsFormFull>().fields.map((e) => e.key), [
        'title',
        'questions',
        'formQuestions',
        'formSubForms',
        'formProposedAnswers',
      ]);
    });
  });
}
