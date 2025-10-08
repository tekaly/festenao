/// Represents an answer to a form question.
abstract class TkFormPlayerQuestionAnswer {
  /// Integer value answer (for int-type questions).
  int? get intValue;

  /// Single-choice answer id.
  String? get choiceId;

  /// Multiple-choice answer ids.
  List<String>? get choiceIds;

  /// Text value for "other" choices or text questions.
  String? get textValue;

  /// Factory to create a question answer instance.
  factory TkFormPlayerQuestionAnswer({
    int? intValue,
    String? choiceId,
    String? textValue,
    List<String>? choiceIds,
  }) => _TkFormPlayerQuestionAnswer(
    intValue: intValue,
    choiceId: choiceId,
    textValue: textValue,
    choiceIds: choiceIds,
  );
}

class _TkFormPlayerQuestionAnswer implements TkFormPlayerQuestionAnswer {
  @override
  final int? intValue;

  @override
  final String? choiceId;
  @override
  final String? textValue;
  @override
  final List<String>? choiceIds;

  /// Internal constructor for question answers.
  _TkFormPlayerQuestionAnswer({
    required this.intValue,
    required this.choiceId,
    required this.textValue,
    required this.choiceIds,
  });
}
