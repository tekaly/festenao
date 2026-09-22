import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as yaml;
import 'package:yaml_edit/yaml_edit.dart';

import 'object_edit_operation.dart';
import 'object_type_registry.dart';

/// A text representation of an object tree: json, yaml.
///
/// [decode] and [encode] go through an [ObjectTypeRegistry], so a custom value
/// (a timestamp, a blob) round trips as the one key map the registry encodes
/// it to.
///
/// [encodeFrom] is what a file is saved with: a format that
/// [supportsInPlaceEdit] replays the edits on the text it read, keeping what a
/// full re-encode would drop — the comments and the layout of a yaml file.
abstract class ObjectTextFormat {
  /// Format name, `json` or `yaml`.
  String get name;

  /// The file extensions of this format, the first one being the one a new
  /// file takes.
  List<String> get extensions;

  /// True when [encodeFrom] keeps what it can of the text it is given.
  bool get supportsInPlaceEdit => false;

  /// The tree [text] holds, custom values decoded through [typeRegistry].
  Object? decode(String text, {ObjectTypeRegistry? typeRegistry});

  /// [value] as text, custom values encoded through [typeRegistry].
  String encode(Object? value, {ObjectTypeRegistry? typeRegistry});

  /// [value] as text, keeping as much of [source] as the format allows.
  ///
  /// [operations] are the edits that turned the tree [source] held into
  /// [value], in order. The default implementation re-encodes the whole tree,
  /// which is all a json file needs.
  String encodeFrom(
    String source,
    Object? value, {
    ObjectTypeRegistry? typeRegistry,
    List<ObjectEditOperation>? operations,
  }) => encode(value, typeRegistry: typeRegistry);

  /// Whether [path] has one of the [extensions] of this format.
  bool matchesPath(String path) =>
      extensions.contains(p.extension(path).toLowerCase());

  @override
  String toString() => name;
}

/// Json, indented with 2 spaces.
class ObjectJsonFormat extends ObjectTextFormat {
  /// The indent of the encoded text, 2 spaces by default, null for a compact
  /// one line document.
  final String? indent;

  /// Json format, indented with [indent].
  ObjectJsonFormat({this.indent = '  '});

  @override
  String get name => 'json';

  @override
  List<String> get extensions => const ['.json'];

  @override
  Object? decode(String text, {ObjectTypeRegistry? typeRegistry}) {
    var registry = typeRegistry ?? defaultObjectTypeRegistry;
    if (text.trim().isEmpty) {
      return null;
    }
    return registry.fromJsonEncodable(jsonDecode(text));
  }

  @override
  String encode(Object? value, {ObjectTypeRegistry? typeRegistry}) {
    var registry = typeRegistry ?? defaultObjectTypeRegistry;
    var jsonValue = registry.toJsonEncodable(value);
    var indent = this.indent;
    if (indent == null) {
      return jsonEncode(jsonValue);
    }
    return '${JsonEncoder.withIndent(indent).convert(jsonValue)}\n';
  }
}

/// Yaml, saved in place: the comments, the key order and the layout of the
/// file survive an edit.
///
/// [encodeFrom] replays the edits on the original text through `yaml_edit`,
/// and falls back to a full re-encode when the source is empty or when an edit
/// does not apply — a path `yaml_edit` refuses, an anchor it will not touch.
///
/// Where a new field lands is `yaml_edit`'s business: it appends it to a block
/// map that already has two entries or more, and puts it first in a map that
/// has only one.
class ObjectYamlFormat extends ObjectTextFormat {
  /// Yaml format.
  ObjectYamlFormat();

  @override
  String get name => 'yaml';

  @override
  List<String> get extensions => const ['.yaml', '.yml'];

  @override
  bool get supportsInPlaceEdit => true;

  @override
  Object? decode(String text, {ObjectTypeRegistry? typeRegistry}) {
    var registry = typeRegistry ?? defaultObjectTypeRegistry;
    if (text.trim().isEmpty) {
      return null;
    }
    return registry.fromJsonEncodable(_unwrapYaml(yaml.loadYaml(text)));
  }

  @override
  String encode(Object? value, {ObjectTypeRegistry? typeRegistry}) {
    var registry = typeRegistry ?? defaultObjectTypeRegistry;
    var editor = YamlEditor('');
    editor.update([], registry.toJsonEncodable(value));
    var text = editor.toString();
    return text.endsWith('\n') ? text : '$text\n';
  }

  @override
  String encodeFrom(
    String source,
    Object? value, {
    ObjectTypeRegistry? typeRegistry,
    List<ObjectEditOperation>? operations,
  }) {
    var registry = typeRegistry ?? defaultObjectTypeRegistry;
    if (operations == null || operations.isEmpty) {
      // Nothing was edited: the file is left as it is.
      return source.trim().isEmpty
          ? encode(value, typeRegistry: registry)
          : source;
    }
    if (source.trim().isEmpty) {
      return encode(value, typeRegistry: registry);
    }
    try {
      var editor = YamlEditor(source);
      for (var operation in operations) {
        switch (operation) {
          case ObjectSetOperation():
            editor.update(
              operation.path.parts,
              registry.toJsonEncodable(operation.value),
            );
          case ObjectRemoveOperation():
            editor.remove(operation.path.parts);
          case ObjectInsertOperation():
            editor.insertIntoList(
              operation.path.parent!.parts,
              operation.index,
              registry.toJsonEncodable(operation.value),
            );
        }
      }
      var text = editor.toString();
      return text.endsWith('\n') ? text : '$text\n';
    } catch (_) {
      // A path yaml_edit refuses: the whole document is re-encoded, the
      // comments and the layout are lost but the content is right.
      return encode(value, typeRegistry: registry);
    }
  }

  /// `package:yaml` answers [yaml.YamlMap] and [yaml.YamlList], read only
  /// views that still are a [Map] and a [List]: they become plain ones, so the
  /// editor can mutate them.
  Object? _unwrapYaml(Object? value) {
    if (value is Map) {
      var map = <String, Object?>{};
      value.forEach((key, value) {
        map['$key'] = _unwrapYaml(value);
      });
      return map;
    }
    if (value is List) {
      return value.map(_unwrapYaml).toList();
    }
    return value;
  }
}

/// Json, indented with 2 spaces.
final objectJsonFormat = ObjectJsonFormat();

/// Yaml, saved in place.
final objectYamlFormat = ObjectYamlFormat();

/// The formats a file extension is looked up in.
final objectTextFormats = <ObjectTextFormat>[
  objectJsonFormat,
  objectYamlFormat,
];

/// The format matching the extension of [path], null when no format does.
ObjectTextFormat? objectTextFormatOf(String path) {
  for (var format in objectTextFormats) {
    if (format.matchesPath(path)) {
      return format;
    }
  }
  return null;
}
