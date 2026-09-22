import 'dart:async';
import 'dart:convert';

import 'object_editor.dart';
import 'object_path.dart';
import 'object_source.dart';
import 'object_type_registry.dart';

/// What was copied: a value, plus where it came from.
///
/// The value is held in its **json encodable** form, the one
/// [ObjectTypeRegistry.toJsonEncodable] produces, so it crosses backends: a
/// timestamp copied from a sembast record pastes into a firestore document as
/// a firestore timestamp, and into a json file as `{"$timestamp": ...}`.
class ObjectClipboardData {
  /// The copied value, json encodable.
  final Object? jsonValue;

  /// Where it was copied from, what a paste menu displays (`config.json`,
  /// `config/main`, `items[2]`).
  final String label;

  /// When it was copied.
  final DateTime copiedAt;

  /// Data holding [jsonValue], copied from [label].
  ObjectClipboardData({
    required this.jsonValue,
    required this.label,
    DateTime? copiedAt,
  }) : copiedAt = copiedAt ?? DateTime.now();

  /// The value read with [typeRegistry], ready to be pasted in a tree that
  /// registry reads.
  Object? value(ObjectTypeRegistry typeRegistry) =>
      typeRegistry.fromJsonEncodable(jsonValue);

  /// The value as json text, what goes to the clipboard of the system.
  ///
  /// [jsonValue] is already encoded, so it goes straight to json: running it
  /// through a registry again would escape the very markers that carry the
  /// custom types.
  String get text =>
      '${const JsonEncoder.withIndent('  ').convert(jsonValue)}\n';

  /// The data json [text] holds, null when it is not json.
  static ObjectClipboardData? tryParse(String text, {String label = 'text'}) {
    if (text.trim().isEmpty) {
      return null;
    }
    try {
      return ObjectClipboardData(jsonValue: jsonDecode(text), label: label);
    } catch (_) {
      return null;
    }
  }

  /// A short description of what was copied, for a menu: `{3 fields}` from
  /// `config.json`.
  String get summary {
    var registry = ObjectTypeRegistry.basic();
    return '${registry.typeOf(jsonValue).format(jsonValue)} from $label';
  }

  @override
  String toString() => 'ObjectClipboardData($summary)';
}

/// What was last copied out of an object tree, a record or a document.
///
/// One clipboard is shared by every editor, [globalObjectClipboard] by
/// default, so a value copied in a sembast record pastes into a json file, a
/// firestore document or a list item of another tree.
///
/// The flutter editors mirror it to the clipboard of the system, so a value
/// also pastes into — and comes from — anything else.
class ObjectClipboard {
  ObjectClipboardData? _data;
  final _controller = StreamController<ObjectClipboardData?>.broadcast();

  /// Clipboard holding nothing.
  ObjectClipboard();

  /// What was last copied, null when nothing was.
  ObjectClipboardData? get data => _data;

  /// True when something was copied.
  bool get isNotEmpty => _data != null;

  /// True when nothing was copied.
  bool get isEmpty => _data == null;

  /// Fires each time something is copied or the clipboard is cleared, what a
  /// menu rebuilds on.
  Stream<ObjectClipboardData?> get onChanged => _controller.stream;

  /// Copies [data], answering it.
  ObjectClipboardData setData(ObjectClipboardData data) {
    _data = data;
    _controller.add(data);
    return data;
  }

  /// Copies [value], encoded through [typeRegistry].
  ObjectClipboardData copy(
    Object? value, {
    required ObjectTypeRegistry typeRegistry,
    required String label,
  }) => setData(
    ObjectClipboardData(
      jsonValue: typeRegistry.toJsonEncodable(value),
      label: label,
    ),
  );

  /// Forgets what was copied.
  void clear() {
    _data = null;
    _controller.add(null);
  }

  /// Releases [onChanged].
  Future<void> close() => _controller.close();

  @override
  String toString() => 'ObjectClipboard(${_data ?? 'empty'})';
}

/// The clipboard the editors use unless they are given another one.
final globalObjectClipboard = ObjectClipboard();

/// Copying and pasting a value of a tree.
extension ObjectEditorClipboardExt on ObjectEditor {
  /// Copies the value at [path] — the whole tree at the root, a field, a
  /// nested map, one item of a list.
  ///
  /// [label] says where it came from, the path itself by default.
  ObjectClipboardData copyAt(
    ObjectPath path, {
    ObjectClipboard? clipboard,
    String? label,
  }) => (clipboard ?? globalObjectClipboard).copy(
    valueAt(path),
    typeRegistry: typeRegistry,
    label: label ?? '$path',
  );

  /// Replaces the value at [path] with what was copied.
  ///
  /// Throws a [StateError] when nothing was copied.
  void pasteAt(ObjectPath path, {ObjectClipboard? clipboard}) =>
      setValueAt(path, _pasted(clipboard));

  /// Adds what was copied to the map at [mapPath], under [key].
  void pasteAsField(
    ObjectPath mapPath,
    String key, {
    ObjectClipboard? clipboard,
  }) => addField(mapPath, key, value: _pasted(clipboard));

  /// Adds what was copied to the list at [listPath], at [index] or at the end.
  void pasteAsItem(
    ObjectPath listPath, {
    int? index,
    ObjectClipboard? clipboard,
  }) => addItem(listPath, index: index, value: _pasted(clipboard));

  /// True when something can be pasted.
  bool canPaste({ObjectClipboard? clipboard}) =>
      (clipboard ?? globalObjectClipboard).isNotEmpty;

  Object? _pasted(ObjectClipboard? clipboard) {
    var data = (clipboard ?? globalObjectClipboard).data;
    if (data == null) {
      throw StateError('Nothing was copied');
    }
    return data.value(typeRegistry);
  }
}

/// Copying and pasting a whole object, without opening it in an editor.
extension ObjectSourceClipboardExt on ObjectSource {
  /// Copies what this source holds.
  Future<ObjectClipboardData> copy({
    ObjectClipboard? clipboard,
    String? label,
  }) async => (clipboard ?? globalObjectClipboard).copy(
    await read(),
    typeRegistry: typeRegistry,
    label: label ?? title,
  );

  /// Writes what was copied into this source, replacing what it held.
  ///
  /// Throws a [StateError] when nothing was copied, a [ReadOnlyException]
  /// when the source refuses writes.
  Future<void> paste({ObjectClipboard? clipboard}) async {
    var data = (clipboard ?? globalObjectClipboard).data;
    if (data == null) {
      throw StateError('Nothing was copied');
    }
    await write(data.value(typeRegistry));
  }
}

/// Pasting a whole object as a new one of a collection.
extension ObjectCollectionClipboardExt on ObjectCollection {
  /// Adds what was copied to this collection, answering the id it took.
  ///
  /// With [id], it is written there instead, replacing what was there.
  Future<String> paste({ObjectClipboard? clipboard, String? id}) async {
    var data = (clipboard ?? globalObjectClipboard).data;
    if (data == null) {
      throw StateError('Nothing was copied');
    }
    var value = data.value(typeRegistry);
    if (id == null) {
      return add(value);
    }
    checkWritable('write $id');
    await source(id).write(value);
    return id;
  }
}
