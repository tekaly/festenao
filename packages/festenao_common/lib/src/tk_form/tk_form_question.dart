import 'package:tekartik_common_utils/iterable_utils.dart';

import 'tk_form_question_choice.dart';

/// Simple question
abstract class TkFormPlayerQuestion {
  /// Question id (unique in a form)
  String get id;

  /// Question text
  String get text;

  /// Question hint
  String? get hint;

  /// Question options
  TkFormPlayerQuestionOptions get options;

  /// Constructor
  factory TkFormPlayerQuestion({
    required String id,
    required String text,
    required TkFormPlayerQuestionOptions options,
    String? hint,
  }) {
    return _TkFormPlayerQuestion(
      id: id,
      text: text,
      options: options,
      hint: hint,
    );
  }
}

class _TkFormPlayerQuestion extends TkFormPlayerQuestionBase {
  _TkFormPlayerQuestion({
    required super.id,
    required super.text,
    required super.options,
    required super.hint,
  });
}

/// Question with options
abstract class TkFormPlayerQuestionBase implements TkFormPlayerQuestion {
  @override
  final String id;
  @override
  final String text;
  @override
  final String? hint;

  /// Question options
  @override
  final TkFormPlayerQuestionOptions options;

  /// Constructor
  TkFormPlayerQuestionBase({
    required this.id,
    required this.text,
    required this.options,
    this.hint,
  });
}

/// Multi or single choice
abstract class TkFormPlayerQuestionChoiceOptions
    extends TkFormPlayerQuestionOptions {
  /// Choice allow other
  bool get choiceAllowOther;

  /// For choice and multi choice
  List<TkFormPlayerQuestionChoice>? get choices;
}

/// Helper extension
extension TkFormPlayerQuestionChoiceIterableExt
    on Iterable<TkFormPlayerQuestionChoice> {
  /// Get ids
  Iterable<String> get ids => map((e) => e.id);

  /// Get choice by id
  TkFormPlayerQuestionChoice? getChoiceById(String id) {
    return firstWhereOrNull((element) => element.id == id);
  }
}

/// Int
abstract class TkFormPlayerQuestionIntOptions
    extends TkFormPlayerQuestionOptions {
  /// If non null, it must be non empty
  List<int>? get presets;

  /// Min value
  int? get min;

  /// Max value
  int? get max;

  /// Create factory using _TkFormPlayerQuestionIntOptions
  factory TkFormPlayerQuestionIntOptions({
    List<int>? presets,
    int? min,
    int? max,
    bool? emptyAllowed,
  }) {
    return _TkFormPlayerQuestionIntOptions(
      presets: presets,
      min: min,
      max: max,
      emptyAllowed: emptyAllowed,
    );
  }
}

/// Create class implementing TkFormPlayerQuestionIntOptions
class _TkFormPlayerQuestionIntOptions extends TkFormPlayerQuestionOptionsBase
    implements TkFormPlayerQuestionIntOptions {
  @override
  final List<int>? presets;

  @override
  final int? min;

  @override
  final int? max;
  @override
  bool get isTypeInt => true;
  _TkFormPlayerQuestionIntOptions({
    required this.presets,
    required this.min,
    required this.max,
    required super.emptyAllowed,
  });
}

/// Create class implementing TkFormPlayerQuestionIntOptions
class _TkFormPlayerQuestionTextOptions extends TkFormPlayerQuestionOptionsBase
    implements TkFormPlayerQuestionTextOptions {
  @override
  bool get isTypeText => true;
  _TkFormPlayerQuestionTextOptions({required super.emptyAllowed});
}

/// Text
abstract class TkFormPlayerQuestionTextOptions
    extends TkFormPlayerQuestionOptions {
  /// Create factory using _TkFormPlayerQuestionIntOptions
  factory TkFormPlayerQuestionTextOptions({bool? emptyAllowed}) {
    return _TkFormPlayerQuestionTextOptions(emptyAllowed: emptyAllowed);
  }
}

/// Question options
abstract class TkFormPlayerQuestionOptions {
  /// Is type int
  bool get isTypeInt;

  /// Is type text (default)
  bool get isTypeText;

  /// Is type choice
  bool get isTypeChoice;

  /// Multi choice type
  bool get isTypeChoiceMulti;

  /// True if empty answer is allowed
  bool get emptyAllowed;
}

/// Question options base
class TkFormPlayerQuestionOptionsBase
    with TkFormPlayerQuestionOptionsMixin
    implements TkFormPlayerQuestionOptions {
  /// empty Allowed
  @override
  final bool emptyAllowed;

  /// Constructor
  TkFormPlayerQuestionOptionsBase({bool? emptyAllowed})
    : emptyAllowed = emptyAllowed ?? false;
}

/// Default options
mixin TkFormPlayerQuestionOptionsMixin implements TkFormPlayerQuestionOptions {
  @override
  bool get isTypeInt => false;

  @override
  bool get isTypeText => false;

  @override
  bool get isTypeChoice => false;

  @override
  bool get isTypeChoiceMulti => false;

  @override
  bool get emptyAllowed => false;

  @override
  String toString() {
    var sb = StringBuffer();
    void add(String name, bool value) {
      if (value) {
        if (sb.isNotEmpty) {
          sb.write(', ');
        }
        sb.write('$name: true');
      }
    }

    add('isTypeInt', isTypeInt);
    add('isTypeText', isTypeText);
    add('isTypeChoice', isTypeChoice);
    add('emptyAllowed', emptyAllowed);
    return 'QuestionOptions($sb)';
  }
}

/// Default options
class TkFormPlayerQuestionOptionsDefault
    with TkFormPlayerQuestionOptionsMixin
    implements TkFormPlayerQuestionTextOptions {
  @override
  bool get isTypeText => true;
}

/// Form player question extension
extension TkFormPlayerQuestionExtension on TkFormPlayerQuestion {
  /// Debug string
  String toDebugString() {
    return 'PlayerQuestion(id: $id, text: $text, $options)';
  }
}

/// Form player question extension
extension TkFormPlayerQuestionListExtension on Iterable<TkFormPlayerQuestion> {
  /// List of ids
  Iterable<String> get ids => map((e) => e.id).toList();
}

/// Invalid question
class TkFormPlayerQuestionInvalid extends TkFormPlayerQuestionBase {
  /// Constructor
  TkFormPlayerQuestionInvalid({required super.id})
    : super(text: 'invalid', options: TkFormPlayerQuestionOptionsDefault());
}
