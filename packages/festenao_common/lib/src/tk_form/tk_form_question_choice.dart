/// Abstract class for form player question answer.
abstract class TkFormPlayerQuestionChoice {
  /// Choice id
  String get id;

  /// Choice text
  String get text;

  /// Allow entering text
  bool get allowOther;

  /// Constructor
  factory TkFormPlayerQuestionChoice({
    required String id,
    required String text,
    bool? allowOther,
  }) {
    return _TkFormPlayerQuestionChoice(
      id: id,
      text: text,
      allowOther: allowOther ?? false,
    );
  }
}

class _TkFormPlayerQuestionChoice extends TkFormPlayerQuestionChoiceBase {
  /// Constructor
  _TkFormPlayerQuestionChoice({
    required super.id,
    required super.text,
    required super.allowOther,
  });
}

/// Form player question base
abstract class TkFormPlayerQuestionChoiceBase
    implements TkFormPlayerQuestionChoice {
  @override
  final String id;
  @override
  final String text;

  @override
  final bool allowOther;

  /// Constructor
  TkFormPlayerQuestionChoiceBase({
    required this.id,
    required this.text,
    required this.allowOther,
  });
}

/// Debug helper
extension TkFormPlayerQuestionChoiceExt on TkFormPlayerQuestionChoice {
  /// Debug string
  String toDebugString() {
    return 'QuestionChoice(id: $id, name: $text)';
  }
}
