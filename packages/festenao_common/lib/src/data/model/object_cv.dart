import 'dart:typed_data';

import 'package:cv/cv.dart';

import 'object_edit_operation.dart';
import 'object_editor.dart';
import 'object_source.dart';
import 'object_type.dart';
import 'object_type_registry.dart';

/// One known field of a cv model: its name and the editor type it takes.
class CvObjectField {
  /// The field name, the map key it is read and written under.
  final String name;

  /// The dart type the cv field declares.
  final Type type;

  /// The id of the editor type [type] maps to, null when none does — an
  /// enum, a model list, anything the editor shows as a map or a list.
  final String? typeId;

  /// Field [name] of dart type [type], edited as [typeId].
  CvObjectField({required this.name, required this.type, this.typeId});

  @override
  String toString() => '$name: ${typeId ?? type}';
}

/// The known fields of a [CvModel], what the editor offers to add to a map it
/// knows the shape of.
///
/// The editor stays generic: a model is edited as the map it serializes to, so
/// a field the schema does not know is still editable, and a document that is
/// not a model at all is edited just the same.
class CvObjectSchema {
  /// The fields, in the order the model declares them.
  final List<CvObjectField> fields;

  /// Schema holding [fields].
  CvObjectSchema(Iterable<CvObjectField> fields)
    : fields = List.unmodifiable(fields);

  /// The field named [name], null when the model has no such field.
  CvObjectField? field(String name) {
    for (var field in fields) {
      if (field.name == name) {
        return field;
      }
    }
    return null;
  }

  /// The names of the fields [value], a map being edited, does not hold yet.
  List<String> missingFieldNames(Object? value) {
    if (value is! Map) {
      return fields.map((field) => field.name).toList();
    }
    return fields
        .map((field) => field.name)
        .where((name) => !value.containsKey(name))
        .toList();
  }

  @override
  String toString() => 'CvObjectSchema(${fields.join(', ')})';
}

/// The id of the editor type a cv field of dart type [type] takes, null when
/// no basic type matches — a nested model, an enum, a typed list: the editor
/// falls back to what the value itself looks like.
String? cvObjectTypeIdOf(Type type) {
  if (type == String) {
    return objectTypeString.id;
  }
  if (type == int) {
    return objectTypeInt.id;
  }
  if (type == double || type == num) {
    return objectTypeDouble.id;
  }
  if (type == bool) {
    return objectTypeBool.id;
  }
  if (type == DateTime) {
    return objectTypeDateTime.id;
  }
  if (type == Uint8List) {
    return objectTypeBytes.id;
  }
  return null;
}

/// The schema of [model], the fields it declares.
CvObjectSchema cvObjectSchema(CvModel model) => CvObjectSchema(
  model.fields.map(
    (field) => CvObjectField(
      name: field.key,
      type: field.type,
      typeId: cvObjectTypeIdOf(field.type),
    ),
  ),
);

/// A [CvModel] edited as the map it serializes to.
///
/// [read] answers `model.toMap()` and [write] feeds the edited map back through
/// `model.fromMap()`, so the model itself holds the result — what a dev screen
/// editing a settings or a config model wants.
///
/// The values the model holds keep their runtime type, so a `Timestamp` field
/// is edited as a timestamp: pass the [typeRegistry] of the backend the model
/// is stored in (`sembastObjectTypeRegistry`, `firestoreObjectTypeRegistry`).
class CvObjectSource extends ObjectSource {
  /// The model, read and written in place.
  final CvModel model;

  @override
  final String title;

  @override
  final ObjectTypeRegistry typeRegistry;

  @override
  final bool isReadOnly;

  /// The fields the model declares, what an editor offers to add.
  late final CvObjectSchema schema = cvObjectSchema(model);

  /// Source of [model].
  CvObjectSource(
    this.model, {
    String? title,
    ObjectTypeRegistry? typeRegistry,
    this.isReadOnly = false,
  }) : title = title ?? '${model.runtimeType}',
       typeRegistry = typeRegistry ?? defaultObjectTypeRegistry;

  @override
  Future<Object?> read() async => model.toMap();

  @override
  Future<void> write(
    Object? value, {
    List<ObjectEditOperation>? operations,
  }) async {
    checkWritable();
    if (value is! Map) {
      throw ArgumentError.value(value, 'value', 'A cv model is a map');
    }
    model.clear();
    model.fromMap(value);
  }
}

/// cv helpers on an editor.
extension ObjectEditorCvExt on ObjectEditor {
  /// The tree read as a [T], the editor holding the map it serializes to.
  ///
  /// Throws a [StateError] when the tree is not a map.
  T toCvModel<T extends CvModel>(T model) {
    var value = this.value;
    if (value is! Map) {
      throw StateError('Not a map, a ${value.runtimeType}');
    }
    model.fromMap(value);
    return model;
  }

  /// Replaces the tree with the map [model] serializes to.
  void setCvModel(CvModel model) => setRootValue(model.toMap());
}
