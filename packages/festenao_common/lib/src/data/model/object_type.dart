import 'dart:convert';
import 'dart:typed_data';

/// Prefix marking an encoded custom type key in the json encodable form of an
/// object tree (`{'$timestamp': '2024-01-01T00:00:00.000Z'}`).
///
/// Same convention as the sembast V2 codec (`sembastCodecDefaultV2`), so a
/// json file written here reads back in sembast, and the other way round.
const objectCustomTypePrefix = r'$';

/// Handler of one value type of an editable object tree.
///
/// It tells whether a runtime value is of its type ([matches]), how to display
/// it ([format]), how to edit it as text ([toText]/[parseText]), and, for a
/// custom type (a timestamp, a blob, a document reference…), how to convert it
/// to and from a json encodable payload ([encode]/[decode]).
///
/// The basic types ([objectTypeString], [objectTypeInt], [objectTypeDouble],
/// [objectTypeBool], [objectTypeNull]) and the two containers
/// ([objectTypeMap], [objectTypeList]) are built in. Anything else is a custom
/// type, added to an [ObjectTypeRegistry]:
///
/// ```dart
/// var registry = defaultObjectTypeRegistry.withHandlers([
///   myDurationTypeHandler,
/// ]);
/// ```
abstract class ObjectValueTypeHandler {
  /// Handler, const so a custom one can be a compile time constant.
  const ObjectValueTypeHandler();

  /// Type id, unique in a registry (`string`, `timestamp`, `blob`…).
  ///
  /// For a custom type it is also the key of the json encodable form, prefixed
  /// with [objectCustomTypePrefix].
  String get id;

  /// Human readable type name, what a type selector displays.
  String get label;

  /// True for a type json holds natively (string, int, double, bool, null).
  bool get isBasic => false;

  /// True for [objectTypeMap] and [objectTypeList], the two types with
  /// children.
  bool get isContainer => false;

  /// True for a type that needs [encode]/[decode] to reach json.
  bool get isCustom => !isBasic && !isContainer;

  /// The other type ids [decode] also reads.
  ///
  /// What one backend calls a `timestamp` another calls a `dateTime`, and both
  /// encode it as the same iso8601 string. Declaring the other name here is
  /// what lets a value copied out of a sembast record paste into a plain json
  /// document as a date, rather than as an unknown one key map.
  Set<String> get decodeAliases => const {};

  /// Whether [value] is a value of this type.
  bool matches(Object? value);

  /// The value a field takes when its type is switched to this one.
  Object? get newValue;

  /// One line display of [value], truncated when long.
  String format(Object? value);

  /// [value] as the text a text editor starts with.
  ///
  /// A container throws an [UnsupportedError]: it is navigated into, or edited
  /// as a whole through an [ObjectTextFormat].
  String toText(Object? value);

  /// The value back from the text a text editor produced.
  ///
  /// Throws a [FormatException] when the text is not a valid value of this
  /// type, an [UnsupportedError] for a container.
  Object? parseText(String text);

  /// The json encodable payload of [value], the value itself unless this is a
  /// custom type.
  Object? encode(Object? value) => value;

  /// The value back from the payload [encode] produced.
  Object? decode(Object? encoded) => encoded;

  @override
  String toString() => id;
}

/// Truncates [text] to [max] characters, an ellipsis marking what was cut.
String objectTypeTruncate(String text, [int max = 80]) =>
    text.length <= max ? text : '${text.substring(0, max)}…';

/// Base class of the built in handlers.
abstract class _TypeHandlerBase implements ObjectValueTypeHandler {
  @override
  final String id;

  @override
  final String label;

  const _TypeHandlerBase(this.id, this.label);

  @override
  bool get isBasic => false;

  @override
  bool get isContainer => false;

  @override
  bool get isCustom => !isBasic && !isContainer;

  @override
  Set<String> get decodeAliases => const {};

  @override
  Object? encode(Object? value) => value;

  @override
  Object? decode(Object? encoded) => encoded;

  @override
  String toString() => id;
}

class _StringTypeHandler extends _TypeHandlerBase {
  const _StringTypeHandler() : super('string', 'String');

  @override
  bool get isBasic => true;

  @override
  bool matches(Object? value) => value is String;

  @override
  Object? get newValue => '';

  @override
  String format(Object? value) => objectTypeTruncate('"$value"');

  @override
  String toText(Object? value) => value as String? ?? '';

  @override
  Object? parseText(String text) => text;
}

class _IntTypeHandler extends _TypeHandlerBase {
  const _IntTypeHandler() : super('int', 'Integer');

  @override
  bool get isBasic => true;

  @override
  bool matches(Object? value) => value is int;

  @override
  Object? get newValue => 0;

  @override
  String format(Object? value) => '$value';

  @override
  String toText(Object? value) => '$value';

  @override
  Object? parseText(String text) {
    var value = int.tryParse(text.trim());
    if (value == null) {
      throw FormatException('Not an integer', text);
    }
    return value;
  }
}

class _DoubleTypeHandler extends _TypeHandlerBase {
  const _DoubleTypeHandler() : super('double', 'Double');

  @override
  bool get isBasic => true;

  @override
  bool matches(Object? value) => value is double;

  @override
  Object? get newValue => 0.0;

  @override
  String format(Object? value) => '$value';

  @override
  String toText(Object? value) => '$value';

  @override
  Object? parseText(String text) {
    var value = double.tryParse(text.trim());
    if (value == null) {
      throw FormatException('Not a double', text);
    }
    return value;
  }
}

class _BoolTypeHandler extends _TypeHandlerBase {
  const _BoolTypeHandler() : super('bool', 'Boolean');

  @override
  bool get isBasic => true;

  @override
  bool matches(Object? value) => value is bool;

  @override
  Object? get newValue => false;

  @override
  String format(Object? value) => '$value';

  @override
  String toText(Object? value) => '$value';

  @override
  Object? parseText(String text) {
    switch (text.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
    }
    throw FormatException('Not a boolean', text);
  }
}

class _NullTypeHandler extends _TypeHandlerBase {
  const _NullTypeHandler() : super('null', 'Null');

  @override
  bool get isBasic => true;

  @override
  bool matches(Object? value) => value == null;

  @override
  Object? get newValue => null;

  @override
  String format(Object? value) => 'null';

  @override
  String toText(Object? value) => 'null';

  @override
  Object? parseText(String text) => null;
}

class _MapTypeHandler extends _TypeHandlerBase {
  const _MapTypeHandler() : super('map', 'Map');

  @override
  bool get isContainer => true;

  @override
  bool matches(Object? value) => value is Map;

  @override
  Object? get newValue => <String, Object?>{};

  @override
  String format(Object? value) {
    var length = (value as Map).length;
    return '{$length ${length == 1 ? 'field' : 'fields'}}';
  }

  @override
  String toText(Object? value) =>
      throw UnsupportedError('A map is edited through its fields');

  @override
  Object? parseText(String text) =>
      throw UnsupportedError('A map is edited through its fields');
}

class _ListTypeHandler extends _TypeHandlerBase {
  const _ListTypeHandler() : super('list', 'List');

  @override
  bool get isContainer => true;

  @override
  bool matches(Object? value) => value is List;

  @override
  Object? get newValue => <Object?>[];

  @override
  String format(Object? value) {
    var length = (value as List).length;
    return '[$length ${length == 1 ? 'item' : 'items'}]';
  }

  @override
  String toText(Object? value) =>
      throw UnsupportedError('A list is edited through its items');

  @override
  Object? parseText(String text) =>
      throw UnsupportedError('A list is edited through its items');
}

class _DateTimeTypeHandler extends _TypeHandlerBase {
  const _DateTimeTypeHandler() : super('dateTime', 'DateTime');

  /// A `timestamp` of sembast, sdb or firestore is the same iso8601 string.
  @override
  Set<String> get decodeAliases => const {'timestamp'};

  @override
  bool matches(Object? value) => value is DateTime;

  @override
  Object? get newValue => DateTime.now().toUtc();

  @override
  String format(Object? value) => (value as DateTime).toIso8601String();

  @override
  String toText(Object? value) => (value as DateTime).toIso8601String();

  @override
  Object? parseText(String text) => DateTime.parse(text.trim());

  @override
  Object? encode(Object? value) => (value as DateTime).toIso8601String();

  @override
  Object? decode(Object? encoded) => DateTime.parse(encoded as String);
}

class _BytesTypeHandler extends _TypeHandlerBase {
  const _BytesTypeHandler() : super('blob', 'Blob');

  @override
  bool matches(Object? value) => value is Uint8List;

  @override
  Object? get newValue => Uint8List(0);

  @override
  String format(Object? value) {
    var length = (value as Uint8List).length;
    return '<$length ${length == 1 ? 'byte' : 'bytes'}>';
  }

  @override
  String toText(Object? value) => base64Encode(value as Uint8List);

  @override
  Object? parseText(String text) {
    try {
      return base64Decode(text.trim());
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Not base64 ($e)', text);
    }
  }

  @override
  Object? encode(Object? value) => base64Encode(value as Uint8List);

  @override
  Object? decode(Object? encoded) => base64Decode(encoded as String);
}

/// Handler of last resort, matching anything an [ObjectTypeRegistry] has no
/// handler for.
///
/// Such a value is displayed but neither edited nor encoded to json: it is
/// what a missing handler looks like in a viewer, rather than a crash.
class _UnknownTypeHandler extends _TypeHandlerBase {
  const _UnknownTypeHandler() : super('unknown', 'Unknown');

  @override
  bool matches(Object? value) => true;

  @override
  Object? get newValue => null;

  @override
  String format(Object? value) =>
      objectTypeTruncate('${value.runtimeType}: $value');

  @override
  String toText(Object? value) => '$value';

  @override
  Object? parseText(String text) =>
      throw UnsupportedError('No handler for this value type');
}

/// String values.
const objectTypeString = _StringTypeHandler();

/// Integer values.
const objectTypeInt = _IntTypeHandler();

/// Double values.
const objectTypeDouble = _DoubleTypeHandler();

/// Boolean values.
const objectTypeBool = _BoolTypeHandler();

/// Null values.
const objectTypeNull = _NullTypeHandler();

/// Map values, the container whose children are named fields.
const objectTypeMap = _MapTypeHandler();

/// List values, the container whose children are indexed items.
const objectTypeList = _ListTypeHandler();

/// [DateTime] values, encoded as an iso8601 string under `$dateTime`.
///
/// The type a plain json or yaml file uses for a date. A sembast, sdb or
/// firestore source has its own `timestamp` handler instead, see
/// `sembastObjectTypeRegistry`, `sdbObjectTypeRegistry` and
/// `firestoreObjectTypeRegistry`.
const objectTypeDateTime = _DateTimeTypeHandler();

/// [Uint8List] values, encoded as a base64 string under `$blob`.
const objectTypeBytes = _BytesTypeHandler();

/// Matches any value no handler was found for, read only.
const objectTypeUnknown = _UnknownTypeHandler();

/// The 5 json scalar types plus the 2 containers, in the order a type
/// selector lists them.
const objectBasicTypeHandlers = <ObjectValueTypeHandler>[
  objectTypeString,
  objectTypeInt,
  objectTypeDouble,
  objectTypeBool,
  objectTypeNull,
  objectTypeMap,
  objectTypeList,
];
