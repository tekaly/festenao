/// Abstract class for form player question answer.
abstract class TkFormPlayerQuestionAnswer {
  /// Int value
  int? get intValue;

  /// Choice id for single choice, could include textValue also
  String? get choiceId;

  /// Choice ids for multi choice, could include other
  List<String>? get choiceIds;

  /// For choie meaning other we might have a text value
  String? get textValue;

  /// Factory
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

  _TkFormPlayerQuestionAnswer({
    required this.intValue,
    required this.choiceId,
    required this.textValue,
    required this.choiceIds,
  });
}
