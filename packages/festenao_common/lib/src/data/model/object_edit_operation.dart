import 'object_path.dart';

/// One edit applied to an object tree, recorded by an `ObjectEditor`.
///
/// The point of recording them is saving: a format that can be updated in
/// place — yaml, whose comments and layout a full re-encode would drop —
/// replays the operations on the original text instead of re-encoding the
/// whole document, see `ObjectTextFormat.encodeFrom`.
sealed class ObjectEditOperation {
  /// The value the operation acts on.
  final ObjectPath path;

  /// Operation at [path].
  const ObjectEditOperation(this.path);
}

/// [path] takes [value], whether it existed or not.
///
/// A new map field, a changed value and a changed type are all a set.
class ObjectSetOperation extends ObjectEditOperation {
  /// The new value, in its runtime form (a custom value is still a custom
  /// value, encoding it is the writer's business).
  final Object? value;

  /// Sets [path] to [value].
  const ObjectSetOperation(super.path, this.value);

  @override
  String toString() => 'set $path';
}

/// [path] is removed from the map or list holding it.
class ObjectRemoveOperation extends ObjectEditOperation {
  /// Removes [path].
  const ObjectRemoveOperation(super.path);

  @override
  String toString() => 'remove $path';
}

/// [value] is inserted in a list at [path], the items after it shifting by one.
///
/// [path] is the path of the new item, so `ObjectPath.last` is the index it
/// takes and `ObjectPath.parent` is the list.
class ObjectInsertOperation extends ObjectEditOperation {
  /// The inserted value, in its runtime form.
  final Object? value;

  /// Inserts [value] at [path].
  const ObjectInsertOperation(super.path, this.value);

  /// The index the new item takes in its list.
  int get index => path.last as int;

  @override
  String toString() => 'insert $path';
}
