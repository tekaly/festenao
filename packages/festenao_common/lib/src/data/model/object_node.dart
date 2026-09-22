import 'object_path.dart';
import 'object_type.dart';
import 'object_type_registry.dart';

/// One value of an object tree, with where it sits ([path]), what it is
/// ([type]) and, for a container, what it holds ([children]).
///
/// A node is a read only view built on demand by `ObjectEditor.nodeAt`: it
/// holds no state of its own and goes stale as soon as the tree is edited.
class ObjectNode {
  /// The registry the tree is read with.
  final ObjectTypeRegistry typeRegistry;

  /// Where this value sits in the tree.
  final ObjectPath path;

  /// The value itself.
  final Object? value;

  /// Node of [value] at [path].
  ObjectNode({
    required this.typeRegistry,
    required this.path,
    required this.value,
  });

  /// The type of [value].
  ObjectValueTypeHandler get type => typeRegistry.typeOf(value);

  /// The map key or list index this value sits under, null for the root.
  Object? get key => path.last;

  /// What a row displays on the left: the key, the index in brackets, or the
  /// name of the whole document for the root.
  String get name {
    var key = this.key;
    if (key == null) {
      return '/';
    }
    return key is int ? '[$key]' : '$key';
  }

  /// True for a map or a list, the two types with [children].
  bool get isContainer => type.isContainer;

  /// The fields of a map or the items of a list, empty for anything else.
  ///
  /// Map fields come in insertion order, the order they were read or written
  /// in, not sorted: that is the order a json or yaml document has.
  ///
  /// A custom value has none, whatever it is made of: a blob is a [Uint8List],
  /// hence a [List], but it is one value rather than a list of bytes.
  List<ObjectNode> get children {
    if (!isContainer) {
      return const [];
    }
    var value = this.value;
    if (value is Map) {
      return value.entries
          .map(
            (entry) => ObjectNode(
              typeRegistry: typeRegistry,
              path: path.field('${entry.key}'),
              value: entry.value,
            ),
          )
          .toList();
    }
    if (value is List) {
      return List.generate(
        value.length,
        (index) => ObjectNode(
          typeRegistry: typeRegistry,
          path: path.item(index),
          value: value[index],
        ),
      );
    }
    return const [];
  }

  /// What a row displays on the right: the value formatted by its type.
  String get display => type.format(value);

  @override
  String toString() => '$path: $display (${type.id})';
}
