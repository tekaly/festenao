import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'object_type.dart';

/// The types an object tree may hold, and the conversion of that tree to and
/// from a json encodable one.
///
/// A registry always answers [typeOf] — [objectTypeUnknown] when nothing else
/// matches — so a viewer never crashes on an unexpected value.
/// [toJsonEncodable] on the other hand throws on a value it cannot encode.
///
/// [defaultObjectTypeRegistry] holds the basic types plus [objectTypeDateTime]
/// and [objectTypeBytes]. A backend adds its own:
///
/// ```dart
/// var registry = defaultObjectTypeRegistry.withHandlers([
///   myDurationTypeHandler,
/// ]);
/// ```
class ObjectTypeRegistry {
  /// The handlers, the ones added last first.
  final List<ObjectValueTypeHandler> handlers;

  /// Registry holding exactly [handlers].
  ObjectTypeRegistry(Iterable<ObjectValueTypeHandler> handlers)
    : handlers = List.unmodifiable(handlers);

  /// Registry holding only the basic types and the containers.
  ObjectTypeRegistry.basic() : this(objectBasicTypeHandlers);

  /// A new registry with [handlers] added before the current ones, replacing
  /// any handler of the same [ObjectValueTypeHandler.id].
  ObjectTypeRegistry withHandlers(Iterable<ObjectValueTypeHandler> handlers) {
    var added = handlers.toList();
    var addedIds = added.map((handler) => handler.id).toSet();
    return ObjectTypeRegistry([
      ...added,
      ...this.handlers.where((handler) => !addedIds.contains(handler.id)),
    ]);
  }

  /// The handler of id [id], null when the registry has none.
  ObjectValueTypeHandler? handler(String id) =>
      handlers.firstWhereOrNull((handler) => handler.id == id);

  /// The handler decoding the type [id] of a json encodable value: the one of
  /// that id, or the one declaring it among its
  /// [ObjectValueTypeHandler.decodeAliases].
  ///
  /// The aliases are what makes a value copied from one backend paste into
  /// another that names the type differently.
  ObjectValueTypeHandler? decodeHandler(String id) =>
      handler(id) ??
      handlers.firstWhereOrNull(
        (handler) => handler.isCustom && handler.decodeAliases.contains(id),
      );

  /// The prefixes the custom types of this registry are marked with, the
  /// default `$` included so a map that looks encoded is always escaped.
  late final Set<String> prefixes = {
    objectCustomTypePrefix,
    ...customHandlers.map((handler) => handler.prefix),
  };

  /// The handler [key] names, [key] being the key of a one key map: a prefix
  /// this registry knows, then a type id or one of its aliases.
  ///
  /// Null when no prefix matches or nothing answers to what follows it.
  ObjectValueTypeHandler? decodeHandlerForKey(String key) {
    for (var prefix in prefixes) {
      if (prefix.isNotEmpty && key.startsWith(prefix)) {
        var handler = decodeHandler(key.substring(prefix.length));
        if (handler != null && handler.isCustom) {
          return handler;
        }
      }
    }
    return null;
  }

  /// The handler of id [id], throws an [ArgumentError] when there is none.
  ObjectValueTypeHandler handlerOrThrow(String id) =>
      handler(id) ?? (throw ArgumentError.value(id, 'id', 'Unknown type'));

  /// The type of [value], [objectTypeUnknown] when no handler matches.
  ///
  /// The custom types are tried first, whatever order [handlers] is in: a
  /// custom value often is a [List] or a [Map] as well — a [Uint8List] is a
  /// list of ints — and it is the custom type that names it.
  ObjectValueTypeHandler typeOf(Object? value) =>
      handlers.firstWhereOrNull(
        (handler) => handler.isCustom && handler.matches(value),
      ) ??
      handlers.firstWhereOrNull((handler) => handler.matches(value)) ??
      objectTypeUnknown;

  /// The custom types, the ones a value must be encoded through to reach json.
  List<ObjectValueTypeHandler> get customHandlers =>
      handlers.where((handler) => handler.isCustom).toList();

  /// The types a field can be switched to, in selector order: the basic ones
  /// and the containers first, then the custom ones.
  List<ObjectValueTypeHandler> get selectableHandlers => [
    ...handlers.where((handler) => !handler.isCustom),
    ...customHandlers,
  ];

  /// [value] converted to a json encodable tree, a custom value becoming a one
  /// key map (`{'$timestamp': '2024-01-01T00:00:00.000Z'}`), the key being the
  /// [ObjectValueTypeHandler.prefix] of its type then its id.
  ///
  /// A map that already looks like one of those is escaped, so the conversion
  /// round trips. Throws an [ArgumentError] on a value no handler matches.
  Object? toJsonEncodable(Object? value) {
    var handler = typeOf(value);
    if (handler.isCustom) {
      return <String, Object?>{
        '${handler.prefix}${handler.id}': handler.encode(value),
      };
    }
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      var map = <String, Object?>{};
      value.forEach((key, value) {
        map['$key'] = toJsonEncodable(value);
      });
      if (_looksEncoded(map)) {
        return <String, Object?>{objectCustomTypePrefix: map};
      }
      return map;
    }
    if (value is List) {
      return value.map(toJsonEncodable).toList();
    }
    throw ArgumentError.value(
      value,
      'value',
      'No type handler encodes a ${value.runtimeType}',
    );
  }

  /// The tree back from what [toJsonEncodable] produced.
  ///
  /// A one key map marked with a prefix this registry knows but whose type it
  /// does not is left as is, so reading a document never drops data the editor
  /// cannot represent.
  Object? fromJsonEncodable(Object? value) {
    if (value is Map) {
      if (value.length == 1) {
        var key = value.keys.first;
        if (key is String) {
          if (key == objectCustomTypePrefix) {
            // Escaped map, see [toJsonEncodable]: its own single key is one
            // this method must not read as a type again, only its values are
            // converted.
            var escaped = value.values.first;
            if (escaped is Map) {
              var map = <String, Object?>{};
              escaped.forEach((key, value) {
                map['$key'] = fromJsonEncodable(value);
              });
              return map;
            }
            return fromJsonEncodable(escaped);
          }
          var handler = decodeHandlerForKey(key);
          if (handler != null) {
            return handler.decode(value.values.first);
          }
        }
      }
      var map = <String, Object?>{};
      value.forEach((key, value) {
        map['$key'] = fromJsonEncodable(value);
      });
      return map;
    }
    if (value is List) {
      return value.map(fromJsonEncodable).toList();
    }
    return value;
  }

  /// Whether [map] would be read back as an encoded custom value, under any
  /// of the prefixes this registry knows.
  bool _looksEncoded(Map<String, Object?> map) =>
      map.length == 1 &&
      prefixes.any(
        (prefix) => prefix.isNotEmpty && map.keys.first.startsWith(prefix),
      );

  @override
  String toString() =>
      'ObjectTypeRegistry(${handlers.map((handler) => handler.id).join(', ')})';
}

/// The basic types plus [objectTypeDateTime] and [objectTypeBytes], what a
/// plain json or yaml document is edited with.
final defaultObjectTypeRegistry = ObjectTypeRegistry([
  ...objectBasicTypeHandlers,
  objectTypeDateTime,
  objectTypeBytes,
]);
