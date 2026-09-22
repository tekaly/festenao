import 'dart:async';

import 'object_edit_operation.dart';
import 'object_node.dart';
import 'object_path.dart';
import 'object_type.dart';
import 'object_type_registry.dart';

/// A deep copy of [value], maps and lists rebuilt, leaves shared.
///
/// A custom value (a timestamp, a blob) is shared, not copied: the editor
/// replaces such a value rather than mutating it. [typeRegistry] is what says
/// a value is custom, and passing it matters for the custom types that are a
/// [Map] or a [List] as well — a [Uint8List] is a list of ints, and cloning it
/// as one would turn a blob into three numbers.
Object? objectDeepClone(Object? value, {ObjectTypeRegistry? typeRegistry}) {
  if (typeRegistry != null && typeRegistry.typeOf(value).isCustom) {
    return value;
  }
  if (value is Map) {
    var map = <String, Object?>{};
    value.forEach((key, value) {
      map['$key'] = objectDeepClone(value, typeRegistry: typeRegistry);
    });
    return map;
  }
  if (value is List) {
    return value
        .map((value) => objectDeepClone(value, typeRegistry: typeRegistry))
        .toList();
  }
  return value;
}

/// An object tree being edited: the value, the operations applied to it, and
/// the notifications a UI rebuilds on.
///
/// It is the model both the console editor and the flutter editor drive, and
/// it knows nothing of where the object came from — that is an `ObjectSource`.
///
/// ```dart
/// var editor = ObjectEditor({'name': 'test', 'count': 1});
/// editor.setValueAt(ObjectPath.root.field('count'), 2);
/// editor.addField(ObjectPath.root, 'createdAt', typeId: 'dateTime');
/// print(editor.value);
/// ```
class ObjectEditor {
  /// The types the tree is read and edited with.
  final ObjectTypeRegistry typeRegistry;

  Object? _value;
  var _operations = <ObjectEditOperation>[];
  final _changeController = StreamController<ObjectEditor>.broadcast();

  /// Editor of [value], a deep copy of it unless [clone] is false: the tree
  /// the caller passed is left alone until the edits are written back.
  ObjectEditor(
    Object? value, {
    ObjectTypeRegistry? typeRegistry,
    bool clone = true,
  }) : typeRegistry = typeRegistry ?? defaultObjectTypeRegistry,
       _value = clone
           ? objectDeepClone(
               value,
               typeRegistry: typeRegistry ?? defaultObjectTypeRegistry,
             )
           : value;

  /// Editor of a new empty map.
  ObjectEditor.newMap({ObjectTypeRegistry? typeRegistry})
    : this(<String, Object?>{}, typeRegistry: typeRegistry, clone: false);

  /// Editor of a json encodable tree, custom values decoded through
  /// [typeRegistry].
  factory ObjectEditor.fromJsonEncodable(
    Object? jsonValue, {
    ObjectTypeRegistry? typeRegistry,
  }) {
    var registry = typeRegistry ?? defaultObjectTypeRegistry;
    return ObjectEditor(
      registry.fromJsonEncodable(jsonValue),
      typeRegistry: registry,
      clone: false,
    );
  }

  /// The tree, edited in place.
  Object? get value => _value;

  /// The edits applied since the last [markClean], in order.
  List<ObjectEditOperation> get operations => List.unmodifiable(_operations);

  /// True when something was edited since the last [markClean].
  bool get isDirty => _operations.isNotEmpty;

  /// Fires after each edit, what a UI rebuilds on.
  Stream<ObjectEditor> get onChanged => _changeController.stream;

  /// The root node, the whole document.
  ObjectNode get rootNode => ObjectNode(
    typeRegistry: typeRegistry,
    path: ObjectPath.root,
    value: _value,
  );

  /// The node at [path], null when nothing sits there.
  ObjectNode? nodeAt(ObjectPath path) {
    if (path.isRoot) {
      return rootNode;
    }
    var parent = _containerAt(path.parent!);
    var key = path.last;
    Object? value;
    if (parent is Map) {
      if (!parent.containsKey(key)) {
        return null;
      }
      value = parent[key];
    } else if (parent is List) {
      if (key is! int || key < 0 || key >= parent.length) {
        return null;
      }
      value = parent[key];
    } else {
      return null;
    }
    return ObjectNode(typeRegistry: typeRegistry, path: path, value: value);
  }

  /// The value at [path], null when nothing sits there (as for a null value).
  Object? valueAt(ObjectPath path) => nodeAt(path)?.value;

  /// Whether something sits at [path], a null value included.
  bool exists(ObjectPath path) => nodeAt(path) != null;

  /// Sets the value at [path], whether something sat there or not.
  ///
  /// The root takes [value] as a whole, see [setRootValue].
  void setValueAt(ObjectPath path, Object? value) {
    if (path.isRoot) {
      setRootValue(value);
      return;
    }
    var parent = _containerOrThrow(path.parent!);
    var key = path.last;
    if (parent is Map) {
      parent['$key'] = value;
    } else if (parent is List) {
      var index = _listIndexOrThrow(parent, key);
      parent[index] = value;
    }
    _record(ObjectSetOperation(path, value));
  }

  /// Switches the value at [path] to the type of id [typeId], giving it the
  /// default value of that type.
  ///
  /// A container keeps what it holds when it is already of that type, so
  /// switching a map to a map is a no-op rather than a wipe.
  void setTypeAt(ObjectPath path, String typeId) {
    var handler = typeRegistry.handlerOrThrow(typeId);
    var current = valueAt(path);
    if (handler.matches(current)) {
      return;
    }
    setValueAt(path, handler.newValue);
  }

  /// Adds the field [key] to the map at [mapPath].
  ///
  /// The value is [value] when given, the default value of the type of id
  /// [typeId] otherwise (a null value by default). Throws a [StateError] when
  /// the map already has that field.
  void addField(
    ObjectPath mapPath,
    String key, {
    String? typeId,
    Object? value,
  }) {
    var map = _containerOrThrow(mapPath);
    if (map is! Map) {
      throw StateError('$mapPath is not a map');
    }
    if (map.containsKey(key)) {
      throw StateError('Field $key already exists in $mapPath');
    }
    setValueAt(mapPath.field(key), value ?? _newValueOf(typeId));
  }

  /// Renames the map field at [fieldPath] to [newKey], keeping its value.
  ///
  /// The field moves to the end of the map: a rename is a remove plus an add,
  /// there is no renaming a key in place.
  void renameField(ObjectPath fieldPath, String newKey) {
    var mapPath = fieldPath.parent;
    if (mapPath == null) {
      throw StateError('The root has no name');
    }
    var map = _containerOrThrow(mapPath);
    if (map is! Map) {
      throw StateError('$mapPath is not a map');
    }
    var key = '${fieldPath.last}';
    if (key == newKey) {
      return;
    }
    if (!map.containsKey(key)) {
      throw StateError('No field $key in $mapPath');
    }
    if (map.containsKey(newKey)) {
      throw StateError('Field $newKey already exists in $mapPath');
    }
    var value = map[key] as Object?;
    removeAt(fieldPath);
    setValueAt(mapPath.field(newKey), value);
  }

  /// Adds an item to the list at [listPath], at [index] or at the end.
  ///
  /// The value is [value] when given, the default value of the type of id
  /// [typeId] otherwise (a null value by default).
  void addItem(
    ObjectPath listPath, {
    int? index,
    String? typeId,
    Object? value,
  }) {
    var list = _containerOrThrow(listPath);
    if (list is! List) {
      throw StateError('$listPath is not a list');
    }
    var at = index ?? list.length;
    if (at < 0 || at > list.length) {
      throw RangeError.range(at, 0, list.length, 'index');
    }
    var itemValue = value ?? _newValueOf(typeId);
    list.insert(at, itemValue);
    _record(ObjectInsertOperation(listPath.item(at), itemValue));
  }

  /// Moves the item at [from] to [to] in the list at [listPath].
  void moveItem(ObjectPath listPath, int from, int to) {
    var list = _containerOrThrow(listPath);
    if (list is! List) {
      throw StateError('$listPath is not a list');
    }
    if (from == to) {
      return;
    }
    var value = list[from] as Object?;
    list.removeAt(from);
    _record(ObjectRemoveOperation(listPath.item(from)));
    var at = to.clamp(0, list.length);
    list.insert(at, value);
    _record(ObjectInsertOperation(listPath.item(at), value));
  }

  /// Removes the value at [path] from the map or list holding it.
  void removeAt(ObjectPath path) {
    var parentPath = path.parent;
    if (parentPath == null) {
      throw StateError('The root cannot be removed, set it instead');
    }
    var parent = _containerOrThrow(parentPath);
    var key = path.last;
    if (parent is Map) {
      if (!parent.containsKey(key)) {
        throw StateError('No field $key in $parentPath');
      }
      parent.remove(key);
    } else if (parent is List) {
      parent.removeAt(_listIndexOrThrow(parent, key));
    }
    _record(ObjectRemoveOperation(path));
  }

  /// Replaces the whole document with [value].
  ///
  /// The recorded operations are dropped for a single set of the root: nothing
  /// of what came before survives it.
  void setRootValue(Object? value) {
    _value = value;
    _operations = [ObjectSetOperation(ObjectPath.root, value)];
    _changeController.add(this);
  }

  /// Forgets the recorded operations: the tree becomes the saved one.
  ///
  /// Called after a successful write, so [isDirty] goes back to false.
  void markClean() {
    if (_operations.isEmpty) {
      return;
    }
    _operations = [];
    _changeController.add(this);
  }

  /// The tree as a json encodable one, custom values encoded through
  /// [typeRegistry].
  Object? toJsonEncodable() => typeRegistry.toJsonEncodable(_value);

  /// Releases [onChanged].
  Future<void> close() => _changeController.close();

  Object? _newValueOf(String? typeId) =>
      typeId == null ? null : typeRegistry.handlerOrThrow(typeId).newValue;

  /// The container at [path], null when [path] holds something else or
  /// nothing.
  Object? _containerAt(ObjectPath path) {
    var current = _value;
    for (var part in path.parts) {
      if (typeRegistry.typeOf(current).isCustom) {
        return null;
      }
      if (current is Map) {
        current = current['$part'];
      } else if (current is List) {
        if (part is! int || part < 0 || part >= current.length) {
          return null;
        }
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  Object? _containerOrThrow(ObjectPath path) {
    var container = _containerAt(path);
    if (!typeRegistry.typeOf(container).isCustom &&
        (container is Map || container is List)) {
      return container;
    }
    throw StateError('$path is not a map nor a list');
  }

  int _listIndexOrThrow(List list, Object? key) {
    if (key is! int || key < 0 || key >= list.length) {
      throw RangeError.value(key is int ? key : -1, 'index');
    }
    return key;
  }

  void _record(ObjectEditOperation operation) {
    _operations.add(operation);
    _changeController.add(this);
  }

  @override
  String toString() =>
      'ObjectEditor(${typeRegistry.typeOf(_value).format(_value)}'
      '${isDirty ? ', ${_operations.length} edits' : ''})';
}

/// Type helpers on an editor.
extension ObjectEditorTypeExt on ObjectEditor {
  /// The type of the value at [path], [objectTypeUnknown] when nothing sits
  /// there.
  ObjectValueTypeHandler typeAt(ObjectPath path) =>
      nodeAt(path)?.type ?? objectTypeUnknown;

  /// Sets the value at [path] from the text [text], parsed by the type it
  /// currently has.
  ///
  /// Throws a [FormatException] when the text is not a valid value of that
  /// type.
  void setTextAt(ObjectPath path, String text) =>
      setValueAt(path, typeAt(path).parseText(text));
}
