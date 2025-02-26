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
          {'id': 'text_3', 'text': 'text_4'}
        ],
        'answerIntMin': 5,
        'answerIntMax': 6,
        'answerIntPresets': [7]
      });
      expect(_fill<FsForm>(), {
        'title': 'text_1',
        'questions': [
          {'id': 'text_2', 'subFormId': 'text_3'}
        ]
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
            'subForm': [{}]
          }
        ]
      });
      expect(_fill<FsFormFull>(), {
        'title': 'text_1',
        'questions': [
          {'id': 'text_2', 'subFormId': 'text_3'}
        ],
        'formQuestions': [
          {
            'id': 'text_4',
            'text': 'text_5',
            'hint': 'text_6',
            'proposedAnswer': {
              'answerEmptyAllowed': false,
              'answerType': 'text_8',
              'answerChoices': [
                {'id': 'text_9', 'text': 'text_10'}
              ],
              'answerIntMin': 11,
              'answerIntMax': 12,
              'answerIntPresets': [13]
            },
            'proposedAnswerId': 'text_14'
          }
        ],
        'formSubForms': [
          {
            'title': 'text_15',
            'questions': [
              {'id': 'text_16', 'subFormId': 'text_17'}
            ]
          }
        ],
        'formProposedAnswers': [
          {
            'answerEmptyAllowed': true,
            'answerType': 'text_19',
            'answerChoices': [
              {'id': 'text_20', 'text': 'text_21'}
            ],
            'answerIntMin': 22,
            'answerIntMax': 23,
            'answerIntPresets': [24]
          }
        ]
      });
    });
  });
}
