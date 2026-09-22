import 'package:festenao_common/data/object_editor.dart';
import 'package:flutter/material.dart';

/// Builds the widget editing one value of an object tree.
///
/// [onChanged] takes the new value; the builder calls it when the value is
/// settled — on submit or when the field loses the focus — not on every
/// keystroke, so the tree is not rebuilt while the user types.
typedef ObjectValueEditorBuilder =
    Widget Function(
      BuildContext context,
      ObjectValueTypeHandler type,
      Object? value,
      ValueChanged<Object?> onChanged,
    );

/// The widget each type is edited with, and the ones a custom type adds.
///
/// A type with no builder falls back to [objectTextValueEditorBuilder], a text
/// field parsed by the handler itself, which is all most custom types need.
///
/// ```dart
/// var editors = ObjectValueEditorRegistry(builders: {
///   'color': (context, type, value, onChanged) => MyColorPicker(...),
/// });
/// ```
class ObjectValueEditorRegistry {
  /// The builders, by [ObjectValueTypeHandler.id].
  final Map<String, ObjectValueEditorBuilder> builders;

  /// Registry adding [builders] to the built in ones.
  ObjectValueEditorRegistry({
    Map<String, ObjectValueEditorBuilder> builders = const {},
  }) : builders = {...defaultObjectValueEditorBuilders, ...builders};

  /// The builder of the type [id].
  ObjectValueEditorBuilder builder(String id) =>
      builders[id] ?? objectTextValueEditorBuilder;

  /// The widget editing [value] of type [type].
  Widget build(
    BuildContext context,
    ObjectValueTypeHandler type,
    Object? value,
    ValueChanged<Object?> onChanged,
  ) => builder(type.id)(context, type, value, onChanged);
}

/// The built in registry: a text field for anything that has a text form, a
/// switch for a boolean, a date picker for a timestamp.
final defaultObjectValueEditorRegistry = ObjectValueEditorRegistry();

/// A text field whose text is parsed by the type handler itself.
///
/// It is the fallback of every type that has no richer editor, custom ones
/// included: a blob is edited as base64, a document reference as its path, a
/// geo point as `latitude,longitude`, because that is what the handler
/// reads.
Widget objectTextValueEditorBuilder(
  BuildContext context,
  ObjectValueTypeHandler type,
  Object? value,
  ValueChanged<Object?> onChanged,
) => ObjectTextValueField(type: type, value: value, onChanged: onChanged);

/// A switch, for a boolean.
Widget objectBoolValueEditorBuilder(
  BuildContext context,
  ObjectValueTypeHandler type,
  Object? value,
  ValueChanged<Object?> onChanged,
) => Switch(value: value == true, onChanged: onChanged);

/// Nothing: a null has no value to edit, only a type to change.
Widget objectNullValueEditorBuilder(
  BuildContext context,
  ObjectValueTypeHandler type,
  Object? value,
  ValueChanged<Object?> onChanged,
) => Text('null', style: TextStyle(color: Theme.of(context).disabledColor));

/// A text field plus a calendar button opening a date and time picker.
///
/// Used by every date like type — [objectTypeDateTime] and the `timestamp` of
/// sembast, sdb and firestore — the handler converting between its own type
/// and the text the picker produces.
Widget objectDateValueEditorBuilder(
  BuildContext context,
  ObjectValueTypeHandler type,
  Object? value,
  ValueChanged<Object?> onChanged,
) => ObjectDateValueField(type: type, value: value, onChanged: onChanged);

/// The builders of the basic types plus the date like and boolean ones.
final defaultObjectValueEditorBuilders = <String, ObjectValueEditorBuilder>{
  objectTypeBool.id: objectBoolValueEditorBuilder,
  objectTypeNull.id: objectNullValueEditorBuilder,
  objectTypeDateTime.id: objectDateValueEditorBuilder,
  // The sembast, sdb and firestore timestamps, none of which this package
  // needs to know the class of: the handler does the conversion.
  'timestamp': objectDateValueEditorBuilder,
};

/// A text field editing a value through the text form of its type.
///
/// The text goes back to the tree when the field is submitted or loses the
/// focus, never on a keystroke. A text the type refuses shows the
/// [FormatException] under the field and is not applied.
class ObjectTextValueField extends StatefulWidget {
  /// The type the text is parsed by.
  final ObjectValueTypeHandler type;

  /// The value being edited.
  final Object? value;

  /// Called with the parsed value.
  final ValueChanged<Object?> onChanged;

  /// Whether the field takes several lines, for a long string.
  final bool multiline;

  /// Text field editing [value].
  const ObjectTextValueField({
    super.key,
    required this.type,
    required this.value,
    required this.onChanged,
    this.multiline = false,
  });

  @override
  State<ObjectTextValueField> createState() => _ObjectTextValueFieldState();
}

class _ObjectTextValueFieldState extends State<ObjectTextValueField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _error;

  String get _text {
    try {
      return widget.type.toText(widget.value);
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    _controller = TextEditingController(text: _text);
    _focusNode = FocusNode()..addListener(_onFocusChanged);
    super.initState();
  }

  @override
  void didUpdateWidget(ObjectTextValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Someone else changed the value (a reload, a watched record): take it,
    // unless the user is typing in this very field.
    if (!_focusNode.hasFocus && _controller.text != _text) {
      _controller.text = _text;
      _error = null;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _submit(_controller.text);
    }
  }

  void _submit(String text) {
    if (text == _text) {
      if (_error != null) {
        setState(() => _error = null);
      }
      return;
    }
    try {
      var value = widget.type.parseText(text);
      setState(() => _error = null);
      widget.onChanged(value);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focusNode,
    maxLines: widget.multiline ? null : 1,
    style: Theme.of(context).textTheme.bodyMedium,
    decoration: InputDecoration(
      isDense: true,
      errorText: _error,
      border: const OutlineInputBorder(),
      hintText: widget.type.label,
    ),
    onSubmitted: _submit,
  );
}

/// A text field plus a button opening a date and time picker.
class ObjectDateValueField extends StatelessWidget {
  /// The date like type, which converts to and from the text.
  final ObjectValueTypeHandler type;

  /// The value being edited.
  final Object? value;

  /// Called with the parsed value.
  final ValueChanged<Object?> onChanged;

  /// Date field editing [value].
  const ObjectDateValueField({
    super.key,
    required this.type,
    required this.value,
    required this.onChanged,
  });

  /// The value as a [DateTime], through the iso8601 text of its type.
  DateTime? get _dateTime {
    try {
      return DateTime.parse(type.toText(value)).toUtc();
    } catch (_) {
      return null;
    }
  }

  Future<void> _pick(BuildContext context) async {
    var current = _dateTime ?? DateTime.now().toUtc();
    var date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.utc(1970),
      lastDate: DateTime.utc(2100),
    );
    if (date == null || !context.mounted) {
      return;
    }
    var time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    var picked = DateTime.utc(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
    try {
      onChanged(type.parseText(picked.toIso8601String()));
    } catch (_) {
      // The type refused the date, nothing to apply.
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ObjectTextValueField(
          type: type,
          value: value,
          onChanged: onChanged,
        ),
      ),
      IconButton(
        icon: const Icon(Icons.event),
        tooltip: 'Pick a date',
        onPressed: () => _pick(context),
      ),
    ],
  );
}
