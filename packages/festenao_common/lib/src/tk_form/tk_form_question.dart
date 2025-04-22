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

  /// Optional title
  String? get title;

  /// Question options
  TkFormPlayerQuestionOptions get options;

  /// Constructor
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

/// Question with options
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

  /// Constructor
  TkFormPlayerQuestionBase({
    required this.id,
    this.title,
    required this.text,
    required this.options,
    this.hint,
  });
}

/// Multi or single choice
abstract class TkFormPlayerQuestionChoiceOptions
    implements TkFormPlayerQuestionOptions {
  /// Choice allow other
  bool get choiceAllowOther;

  /// For choice and multi choice
  List<TkFormPlayerQuestionChoice>? get choices;

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

/// Question options choice
class _TkFormPlayerQuestionChoiceOptions extends TkFormPlayerQuestionOptionsBase
    implements TkFormPlayerQuestionChoiceOptions {
  final bool multi;
  _TkFormPlayerQuestionChoiceOptions({
    this.choices,
    super.emptyAllowed,
    this.multi = false,
    super.tags,
  });

  /// Is type choice multi
  @override
  bool get isTypeChoiceMulti => multi;

  /// Is type choice
  @override
  bool get isTypeChoice => !multi;
  @override
  final List<TkFormPlayerQuestionChoice>? choices;

  /// Any choice that support other...TO test
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

/// Create class implementing TkFormPlayerQuestionInformationOptions
class _TkFormPlayerQuestionInformationOptions
    extends TkFormPlayerQuestionOptionsBase
    implements TkFormPlayerQuestionInformationOptions {
  @override
  bool get isInformation => true;
  _TkFormPlayerQuestionInformationOptions() : super(emptyAllowed: true);
}

/// Information
abstract class TkFormPlayerQuestionInformationOptions
    extends TkFormPlayerQuestionOptions {
  /// Create factory using TkFormPlayerQuestionInformationOptions
  factory TkFormPlayerQuestionInformationOptions() {
    return _TkFormPlayerQuestionInformationOptions();
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

  /// Information only, no answer
  bool get isInformation;

  List<String>? get tags;
}

/// Question options base
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
