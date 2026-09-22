import 'package:cv/cv.dart';
import 'package:festenao_common/data/object_editor.dart';
import 'package:flutter/material.dart';

import 'object_clipboard_flutter.dart';
import 'object_editor_screen.dart';
import 'object_value_editor.dart';

/// An object held in memory while it is edited, kept apart from the one the
/// caller passed until it is saved.
class _EditedObjectSource extends ObjectSource {
  @override
  final String title;

  @override
  final ObjectTypeRegistry typeRegistry;

  @override
  final bool isReadOnly;

  /// What the editor last saved, the value it started on until then.
  Object? value;

  /// True once the editor saved, which is what tells an edit from a cancel.
  var isSaved = false;

  _EditedObjectSource({
    required this.value,
    required this.title,
    required this.typeRegistry,
    required this.isReadOnly,
  });

  @override
  Future<Object?> read() async => value;

  @override
  Future<void> write(
    Object? value, {
    List<ObjectEditOperation>? operations,
  }) async {
    checkWritable();
    this.value = value;
    isSaved = true;
  }
}

/// Edits [value] in memory and answers what it became, or null when the editor
/// was left without saving.
///
/// Nothing is written anywhere: the object goes in, the edited one comes back,
/// which is what a form editing a json field of its own wants.
///
/// ```dart
/// var edited = await editObject(context, {'name': 'test', 'count': 1});
/// if (edited != null) {
///   setState(() => _config = edited);
/// }
/// ```
///
/// [typeRegistry] says what the values may be, the default one (the json
/// types plus `dateTime` and `blob`) unless the object comes from a backend
/// with types of its own. [schema] offers the fields a `cv` model declares,
/// see [editCvModel] for editing one whole.
Future<Object?> editObject(
  BuildContext context,
  Object? value, {
  String title = 'Object',
  ObjectTypeRegistry? typeRegistry,
  CvObjectSchema? schema,
  ObjectValueEditorRegistry? valueEditors,
  FlutterObjectClipboard? clipboard,
  bool isReadOnly = false,
}) async {
  var source = _EditedObjectSource(
    value: value,
    title: title,
    typeRegistry: typeRegistry ?? defaultObjectTypeRegistry,
    isReadOnly: isReadOnly,
  );
  await goToObjectEditorScreen(
    context,
    source: source,
    schema: schema,
    valueEditors: valueEditors,
    clipboard: clipboard,
    title: title,
  );
  return source.isSaved ? source.value : null;
}

/// Edits the map [model] serializes to and feeds it back, answering true when
/// the editor saved.
///
/// The fields the model declares are offered when adding one, and the model
/// itself holds the result.
///
/// ```dart
/// if (await editCvModel(context, settings)) {
///   await saveSettings(settings);
/// }
/// ```
Future<bool> editCvModel(
  BuildContext context,
  CvModel model, {
  String? title,
  ObjectTypeRegistry? typeRegistry,
  ObjectValueEditorRegistry? valueEditors,
  FlutterObjectClipboard? clipboard,
  bool isReadOnly = false,
}) async {
  var edited = await editObject(
    context,
    model.toMap(),
    title: title ?? '${model.runtimeType}',
    typeRegistry: typeRegistry,
    schema: cvObjectSchema(model),
    valueEditors: valueEditors,
    clipboard: clipboard,
    isReadOnly: isReadOnly,
  );
  if (edited is! Map) {
    return false;
  }
  model.clear();
  model.fromMap(edited);
  return true;
}
