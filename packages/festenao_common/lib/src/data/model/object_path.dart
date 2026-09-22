import 'package:collection/collection.dart';

/// Where a value sits in an object tree: a list of parts, a [String] for a map
/// field, an [int] for a list item.
///
/// `ObjectPath.root.field('a').field('b').item(0)` is displayed `a.b[0]`, and
/// its [parts] are what `yaml_edit` and the other path based apis take.
class ObjectPath {
  /// The parts, from the root: a [String] map key or an [int] list index.
  final List<Object> parts;

  /// Path made of [parts].
  ObjectPath(Iterable<Object> parts) : parts = List.unmodifiable(parts);

  /// The path of the root value itself, no part.
  static final root = ObjectPath(const []);

  /// True for the path of the root value.
  bool get isRoot => parts.isEmpty;

  /// The path of the container this value sits in, null for the root.
  ObjectPath? get parent =>
      isRoot ? null : ObjectPath(parts.take(parts.length - 1));

  /// The last part, the key or index in the parent container, null for the
  /// root.
  Object? get last => parts.lastOrNull;

  /// The number of parts, 0 for the root.
  int get depth => parts.length;

  /// This path with [part] appended.
  ObjectPath child(Object part) => ObjectPath([...parts, part]);

  /// This path with the map field [key] appended.
  ObjectPath field(String key) => child(key);

  /// This path with the list item [index] appended.
  ObjectPath item(int index) => child(index);

  /// Whether [other] is this path or one of its descendants.
  bool contains(ObjectPath other) {
    if (other.parts.length < parts.length) {
      return false;
    }
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] != other.parts[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is ObjectPath &&
      const ListEquality<Object>().equals(parts, other.parts);

  @override
  int get hashCode => const ListEquality<Object>().hash(parts);

  @override
  String toString() {
    var sb = StringBuffer();
    for (var part in parts) {
      if (part is int) {
        sb.write('[$part]');
      } else {
        if (sb.isNotEmpty) {
          sb.write('.');
        }
        sb.write(part);
      }
    }
    return sb.isEmpty ? '/' : sb.toString();
  }
}
