import 'package:tekartik_firebase_firestore/firestore.dart';

/// Computes `request.resource.data`, the document as it would be after a
/// write.
///
/// [existing] is the current document data (null when it does not exist),
/// [data] the written data. [merge] is true for `set(merge: true)`, [update]
/// for `update()` (dotted keys are field paths). Field values are resolved:
/// server timestamps become [now], deletes remove the field, array
/// union/remove are applied.
Map<String, Object?> computeRequestResourceData({
  required Map<String, Object?>? existing,
  required Map<String, Object?> data,
  bool merge = false,
  bool update = false,
  Timestamp? now,
}) {
  now ??= Timestamp.fromDateTime(DateTime.now());
  var result = <String, Object?>{};
  if (merge || update) {
    result = _deepCopy(existing ?? {});
  }
  if (update) {
    for (var entry in data.entries) {
      var parts = entry.key.split('.');
      _setPath(result, parts, entry.value, now);
    }
  } else {
    _mergeInto(result, data, now, deep: merge);
  }
  return result;
}

Map<String, Object?> _deepCopy(Map<String, Object?> map) {
  return map.map((key, value) => MapEntry(key, _copyValue(value)));
}

Object? _copyValue(Object? value) {
  if (value is Map) {
    return _deepCopy(value.cast<String, Object?>());
  }
  if (value is List) {
    return value.map(_copyValue).toList();
  }
  return value;
}

void _mergeInto(
  Map<String, Object?> target,
  Map<String, Object?> data,
  Timestamp now, {
  required bool deep,
}) {
  for (var entry in data.entries) {
    var value = entry.value;
    if (value is FieldValue) {
      _applyFieldValue(target, entry.key, value, now);
    } else if (deep && value is Map && target[entry.key] is Map) {
      _mergeInto(
        (target[entry.key] as Map).cast<String, Object?>(),
        value.cast<String, Object?>(),
        now,
        deep: true,
      );
    } else if (value is Map) {
      var child = <String, Object?>{};
      _mergeInto(child, value.cast<String, Object?>(), now, deep: false);
      target[entry.key] = child;
    } else {
      target[entry.key] = _copyValue(value);
    }
  }
}

void _setPath(
  Map<String, Object?> target,
  List<String> parts,
  Object? value,
  Timestamp now,
) {
  if (parts.length == 1) {
    if (value is FieldValue) {
      _applyFieldValue(target, parts.first, value, now);
    } else if (value is Map) {
      var child = <String, Object?>{};
      _mergeInto(child, value.cast<String, Object?>(), now, deep: false);
      target[parts.first] = child;
    } else {
      target[parts.first] = _copyValue(value);
    }
    return;
  }
  var child = target[parts.first];
  if (child is! Map) {
    child = <String, Object?>{};
    target[parts.first] = child;
  }
  _setPath(child.cast<String, Object?>(), parts.sublist(1), value, now);
}

final _serverTimestampType = FieldValue.serverTimestamp.type;
final _deleteType = FieldValue.delete.type;
final _arrayUnionType = FieldValue.arrayUnion([]).type;
final _arrayRemoveType = FieldValue.arrayRemove([]).type;

void _applyFieldValue(
  Map<String, Object?> target,
  String key,
  FieldValue value,
  Timestamp now,
) {
  var type = value.type;
  if (type == _serverTimestampType) {
    target[key] = now;
  } else if (type == _deleteType) {
    target.remove(key);
  } else if (type == _arrayUnionType) {
    var existing = target[key];
    var list = existing is List ? List<Object?>.from(existing) : <Object?>[];
    for (var item in value.data as List) {
      if (!list.contains(item)) {
        list.add(item);
      }
    }
    target[key] = list;
  } else if (type == _arrayRemoveType) {
    var existing = target[key];
    var list = existing is List ? List<Object?>.from(existing) : <Object?>[];
    var removed = value.data as List;
    list.removeWhere(removed.contains);
    target[key] = list;
  } else {
    throw UnsupportedError('Unsupported field value $value');
  }
}
