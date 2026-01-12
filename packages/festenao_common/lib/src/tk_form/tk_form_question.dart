import 'package:tekartik_common_utils/iterable_utils.dart';

import 'tk_form_question_choice.dart';

/// Simple question
abstract class TkFormPlayerQuestion {
  /// Question id (unique in a form)
  String get id;

  /// Question text
  String get text;

  /// Optional hint for the question
  String? get hint;

  /// Optional title for the question
  String? get title;

  /// Options describing the question type and constraints
  TkFormPlayerQuestionOptions get options;

  /// Factory constructor to create a simple question instance.
  factory TkFormPlayerQuestion({
    String? title,
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
      title: title,
    );
  }
}

class _TkFormPlayerQuestion extends TkFormPlayerQuestionBase {
  _TkFormPlayerQuestion({
    required super.id,
    required super.text,
    required super.options,
    required super.hint,
    required super.title,
  });
}

/// Base implementation of a question with common fields.
abstract class TkFormPlayerQuestionBase implements TkFormPlayerQuestion {
  /// Optional title
  @override
  final String? title;
  @override
  final String id;
  @override
  final String text;
  @override
  final String? hint;

  /// Question options
  @override
  final TkFormPlayerQuestionOptions options;

  /// Creates a new base question.
  TkFormPlayerQuestionBase({
    required this.id,
    this.title,
    required this.text,
    required this.options,
    this.hint,
  });
}

/// Multi or single choice options interface.
abstract class TkFormPlayerQuestionChoiceOptions
    implements TkFormPlayerQuestionOptions {
  /// Whether choices allow an "other" value.
  bool get choiceAllowOther;

  /// Available choices for this question (null if not applicable).
  List<TkFormPlayerQuestionChoice>? get choices;

  /// Factory to create choice options.
  factory TkFormPlayerQuestionChoiceOptions({
    List<TkFormPlayerQuestionChoice>? choices,
    bool? emptyAllowed,
    bool? multi,
    List<String>? tags,
  }) {
    return _TkFormPlayerQuestionChoiceOptions(
      choices: choices,
      emptyAllowed: emptyAllowed,
      multi: multi ?? false,
      tags: tags,
    );
  }
}

/// Question options choice implementation.
class _TkFormPlayerQuestionChoiceOptions extends TkFormPlayerQuestionOptionsBase
    implements TkFormPlayerQuestionChoiceOptions {
  final bool multi;
  _TkFormPlayerQuestionChoiceOptions({
    this.choices,
    super.emptyAllowed,
    this.multi = false,
    super.tags,
  });

  /// Is this a multi-choice question
  @override
  bool get isTypeChoiceMulti => multi;

  /// Is this a choice question (single-select)
  @override
  bool get isTypeChoice => !multi;
  @override
  final List<TkFormPlayerQuestionChoice>? choices;

  /// Whether any of the choices supports an "other" value.
  @override
  bool get choiceAllowOther {
    if (isTypeChoice) {
      if (choices?.firstWhereOrNull((choice) => choice.allowOther) != null) {
        return true;
      }
    }
    return false;
  }
}

/// Helper extension to access choice iterable conveniences.
extension TkFormPlayerQuestionChoiceIterableExt
    on Iterable<TkFormPlayerQuestionChoice> {
  /// Get ids
  Iterable<String> get ids => map((e) => e.id);

  /// Get choice by id
  TkFormPlayerQuestionChoice? getChoiceById(String id) {
    return firstWhereOrNull((element) => element.id == id);
  }
}

/// Integer options for a question.
abstract class TkFormPlayerQuestionIntOptions
    extends TkFormPlayerQuestionOptions {
  /// Preset values (if non-null, values must be one of these)
  List<int>? get presets;

  /// Minimum allowed value
  int? get min;

  /// Maximum allowed value
  int? get max;

  /// Factory to create integer options.
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

/// Integer options implementation.
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

/// Text options implementation.
class _TkFormPlayerQuestionTextOptions extends TkFormPlayerQuestionOptionsBase
    implements TkFormPlayerQuestionTextOptions {
  @override
  bool get isTypeText => true;
  _TkFormPlayerQuestionTextOptions({required super.emptyAllowed});
}

/// Text options interface.
abstract class TkFormPlayerQuestionTextOptions
    extends TkFormPlayerQuestionOptions {
  /// Factory to create text options.
  factory TkFormPlayerQuestionTextOptions({bool? emptyAllowed}) {
    return _TkFormPlayerQuestionTextOptions(emptyAllowed: emptyAllowed);
  }
}

/// Information-only question options implementation.
class _TkFormPlayerQuestionInformationOptions
    extends TkFormPlayerQuestionOptionsBase
    implements TkFormPlayerQuestionInformationOptions {
  @override
  bool get isInformation => true;
  _TkFormPlayerQuestionInformationOptions() : super(emptyAllowed: true);
}

/// Information-only options interface.
abstract class TkFormPlayerQuestionInformationOptions
    extends TkFormPlayerQuestionOptions {
  /// Factory to create information options.
  factory TkFormPlayerQuestionInformationOptions() {
    return _TkFormPlayerQuestionInformationOptions();
  }
}

/// Question options common interface.
/// Question options common interface.
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

  /// Information only, no answer
  bool get isInformation;

  /// Optional tags.
  List<String>? get tags;
}

/// Base implementation for question options with defaults.
class TkFormPlayerQuestionOptionsBase
    with TkFormPlayerQuestionOptionsMixin
    implements TkFormPlayerQuestionOptions {
  @override
  final List<String>? tags;

  /// empty Allowed
  @override
  final bool emptyAllowed;

  /// Constructor
  TkFormPlayerQuestionOptionsBase({bool? emptyAllowed, this.tags})
    : emptyAllowed = emptyAllowed ?? false;
}

/// Default behaviors for question options.
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
  bool get isInformation => false;
  @override
  List<String>? get tags => null;
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

/// Default options instance for text questions.
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

/// Extension to list of questions to get ids.
extension TkFormPlayerQuestionListExtension on Iterable<TkFormPlayerQuestion> {
  /// List of ids
  Iterable<String> get ids => map((e) => e.id).toList();
}

/// Invalid question implementation.
class TkFormPlayerQuestionInvalid extends TkFormPlayerQuestionBase {
  /// Creates an invalid question with the given [id].
  TkFormPlayerQuestionInvalid({required super.id})
    : super(text: 'invalid', options: TkFormPlayerQuestionOptionsDefault());
}
