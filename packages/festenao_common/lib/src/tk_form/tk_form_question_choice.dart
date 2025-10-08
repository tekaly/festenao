/// Represents a single selectable choice for a question.
abstract class TkFormPlayerQuestionChoice {
  /// Unique choice identifier.
  String get id;

  /// Display text for the choice.
  String get text;

  /// Whether this choice allows entering a custom text value ("Other").
  bool get allowOther;

  /// Factory constructor to create a choice instance.
  factory TkFormPlayerQuestionChoice({
    required String id,
    required String text,
    bool? allowOther,
    bool? multi,
  }) {
    return _TkFormPlayerQuestionChoice(
      id: id,
      text: text,
      allowOther: allowOther ?? false,
    );
  }
}

class _TkFormPlayerQuestionChoice extends TkFormPlayerQuestionChoiceBase {
  /// Internal constructor used by the factory.
  _TkFormPlayerQuestionChoice({
    required super.id,
    required super.text,
    required super.allowOther,
  });
}

/// Base implementation for a question choice.
abstract class TkFormPlayerQuestionChoiceBase
    implements TkFormPlayerQuestionChoice {
  @override
  final String id;
  @override
  final String text;

  @override
  final bool allowOther;

  /// Creates a new choice base with the given fields.
  TkFormPlayerQuestionChoiceBase({
    required this.id,
    required this.text,
    required this.allowOther,
  });
}

/// Debug extension for [TkFormPlayerQuestionChoice].
extension TkFormPlayerQuestionChoiceExt on TkFormPlayerQuestionChoice {
  /// Returns a debug string for the choice.
  String toDebugString() {
    return 'QuestionChoice(id: $id, name: $text)';
  }
}
