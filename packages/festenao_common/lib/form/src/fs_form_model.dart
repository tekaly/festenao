import 'package:festenao_common/festenao_firestore.dart';

/// Init form builders
void initFsFormBuilders() {
  cvAddConstructors([
    CvFormQuestionChoice.new,
    CvFormProposedAnswer.new,
    CvFormQuestion.new,
    FsForm.new,
    CvQuestionRef.new,
    CvFormQuestionResponse.new,
    CvFormQuestion.new,
    CvForm.new,
    FsFormFull.new
  ]);
}

/// Answer possible choice
class CvFormQuestionChoice extends CvModelBase {
  /// Choice ID
  final id = CvField<String>('id');

  /// Choice text
  final text = CvField<String>('text');

  @override
  List<CvField> get fields => [id, text];
}

/// Form question mixin
mixin CvFormQuestionMixin on CvModel {
  /// Question text
  final text = CvField<String>('text');

  /// Question hint
  final hint = CvField<String>('hint');

  /// Proposed answer
  final proposedAnswer = CvModelField<CvFormProposedAnswer>('proposedAnswer');

  /// Proposed answer ID
  final proposedAnswerId = CvField<String>('proposedAnswerId');

  /// Question mixin fields
  List<CvField> get questionMixinFields => [
        text,
        hint,
        proposedAnswer,

        /// Aternative to choice id
        proposedAnswerId,
      ];
}

/// Survey question
class CvFormQuestion extends CvModelBase with CvFormQuestionMixin {
  /// Question ID
  final id = CvField<String>('id');

  @override
  List<CvField> get fields => [id, ...questionMixinFields];
}

/// Survey answer mixin
mixin CvFormQuestionResponseMixin on CvModel {
  /// Type of answer
  final answerType = CvField<String>('answerType');

  /// Answer int
  final answerInt = CvField<int>('int');

  /// Answer date 2025-02-25
  final answerDate = CvField<String>('date');

  /// Answer text
  final answerText = CvField<String>('text');

  /// Choice ID
  final choiceId = CvField<String>('choiceId');

  /// Choice IDs
  final choiceIds = CvListField<String>('choiceIds');

  /// Sub form response
  final subFormResponses = CvModelListField<CvFormQuestionResponse>(
    'subForm',
  );

  /// Answer mixin fields
  List<CvField> get responseMixinFields => [
        answerType,
        answerInt,
        answerText,
        choiceId,
        choiceIds,
        subFormResponses
      ];
}

/// Survey answer
class CvFormQuestionResponse extends CvModelBase
    with CvFormQuestionResponseMixin {
  /// Question ID
  final id = CvField<String>('id');

  @override
  List<CvField> get fields => [id, ...responseMixinFields];
}

// study
/// Type text
const formAnswerTypeText = 'text';

/// Type int
const formAnswerTypeInt = 'int';

/// Type choice id
const formAnswerTypeChoice = 'choice';

/// Type choice multi
const formAnswerTypeChoiceMulti = 'choice_multi';

/// Type timestamp
const formAnswerTypeTimestamp = 'timestamp';

/// Type data
const formAnswerTypeDate = 'date'; // 2021-06-26

// /template/survey/question/<questionId>
//     title: <string>
//     text: <string>
//     answerEmptyAllowed: <bool>
//     answerType: <free_text,int,choice> // choice_multi,date,time,timestamp,bool>
//     answerChoices: (for 'choice|choice_multi' anserType) [
//         0:
//             id: (string)Fs
//             text: (string)
//         1:
//             id: (string)
//             text: (string)
//             ...
//     ]
/// FS Form question
class FsFormQuestion extends CvFirestoreDocumentBase with CvFormQuestionMixin {
  /// Question title (hidden)
  final title = CvField<String>('title');

  @override
  List<CvField> get fields => [title, ...questionMixinFields];
}

/// Proposed answer mixin
mixin CvFormProposedAnswerMixin implements CvModel {
  /// Proposed answer mixin fields
  List<CvField> get proposedAnswerMixinFields => [
        answerEmptyAllowed,
        answerType,
        answerChoices,
        answerIntMin,
        answerIntMax,
        answerIntPresets,
      ];

  /// Empty answer allowed
  final answerEmptyAllowed = CvField<bool>('answerEmptyAllowed');

  /// Answer type
  final answerType = CvField<String>('answerType');

  /// Answer choices
  final answerChoices = CvModelListField<CvFormQuestionChoice>(
    'answerChoices',
  );

  /// For answerType == int
  final answerIntMin = CvField<int>('answerIntMin');

  /// For answerType == int
  final answerIntMax = CvField<int>('answerIntMax');

  /// For answerType == int
  final answerIntPresets = CvListField<int>('answerIntPresets');
}

/// Proposed answer
class CvFormProposedAnswer extends CvModelBase with CvFormProposedAnswerMixin {
  @override
  List<CvField> get fields => [...proposedAnswerMixinFields];
}

/// Id is the proposeAnswerId
class FsFormProposedAnswer extends CvFirestoreDocumentBase
    with CvFormProposedAnswerMixin {
  @override
  List<CvField> get fields => [...proposedAnswerMixinFields];
}

// All should match
// /template/survey/question/<questionId>/selection/<selectionId>
//     title: <string>
//     answerIds: (for 'selection' answerType) [ <answerId1>, <answerId2> ]
//     answerIntMin: <int?> (for 'int' answerType)
//     answerIntMax: <int?> (for 'int' answerType)
//     answerIsTrue: <bool?>
//     answerIsFalse: <bool?> (for 'bool' answerType)
//     ...
// ]
/// Question selection if needed
class FsFormQuestionSelection extends CvFirestoreDocumentBase
    with CvFormQuestionSelectionMixin {
  @override
  List<CvField> get fields => [...selectionMixinFields];
}

/// Question selection if needed
mixin CvFormQuestionSelectionMixin {
  /// Selection title
  final title = CvField<String>('title');

  /// Answer choice IDs
  final answerChoiceIds = CvListField<String>('answerChoiceIds');

  /// Answer int min
  final answerIntMin = CvListField<int>('answerIntMin');

  /// Answer int max
  final answerIntMax = CvListField<int>('answerIntMax');

  /// mixin
  List<CvField> get selectionMixinFields => [
        title,
        answerChoiceIds,
        answerIntMax,
        answerIntMin,
      ];
}

/// Question selection if needed
class CvFormQuestionSelection extends CvModelBase
    with CvFormQuestionSelectionMixin {
  /// Qustion ID
  final id = CvField<String>('id');
  @override
  List<CvField> get fields => [id, ...selectionMixinFields];
}

/// Quesiton ref
class CvQuestionRef extends CvModelBase {
  /// Question id
  final id = CvField<String>('id');

  /// For optional subform
  final subFormId = CvField<String>('subFormId');

  @override
  CvFields get fields => [id, subFormId];
}

/// Response
class CvQuestionResponse extends CvModelBase {
  /// Question ID
  final questionId = CvField<String>('questionId');

  /// Answer
  final answer = CvModelField<CvFormQuestionResponse>('answer');

  @override
  CvFields get fields => [questionId, answer];
}

///  `/study/<studyId>/info/survey`
class FsForm extends CvFirestoreDocumentBase with CvFormMixin {
  @override
  List<CvField> get fields => [...formMixinFields];
}

/// Form with questions ref
class CvForm extends CvFirestoreDocumentBase with CvFormMixin {
  @override
  List<CvField> get fields => [...formMixinFields];
}

/// Form mixin with reference to questions
mixin CvFormMixin implements CvModel {
  /// Title
  final title = CvField<String>('title');

  /// Questions reference list
  final questions = CvModelListField<CvQuestionRef>('questions');

  /// form mixin fields
  List<CvField> get formMixinFields => [title, questions];
}

/// Full form
class FsFormFull extends CvFirestoreDocumentBase with CvFormMixin {
  /// Questions
  final formQuestions = CvModelListField<CvFormQuestion>('formQuestions');

  /// Sub forms
  final formSubForms = CvModelListField<CvForm>('formSubForms');

  /// Proposed answers
  final formProposedAnswers =
      CvModelListField<CvFormProposedAnswer>('formProposedAnswers');

  @override
  List<CvField> get fields =>
      [...formMixinFields, formQuestions, formSubForms, formProposedAnswers];
}

/// Form response
class CvFormResponse extends CvModelBase {
  /// Response list
  final list = CvModelListField<CvFormQuestionResponse>('list');

  @override
  CvFields get fields => [list];
}

/// Extension
extension CvFormResponseExt on CvFormResponse {
  /// Add a response
  void addResponse(CvFormQuestionResponse response) {
    assert(response.id.v != null, 'response.id is null');
    var list = this.list.v ??= [];
    list.removeWhere((item) => item.id.v == response.id.v);
    list.add(response);
  }
}
