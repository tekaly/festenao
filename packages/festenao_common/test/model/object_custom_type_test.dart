import 'package:festenao_common/data/object_editor.dart';
import 'package:sembast/timestamp.dart' as sembast;
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:test/test.dart';

/// A custom type declared in one place: a key, a string representation, and
/// the default prefix.
final durationType = ObjectCustomTypeHandler(
  id: 'duration',
  label: 'Duration',
  matchesValue: (value) => value is Duration,
  newValueBuilder: () => Duration.zero,
  formatValue: (value) => '${(value as Duration).inMilliseconds}',
  parseValue: (text) {
    var milliseconds = int.tryParse(text.trim());
    if (milliseconds == null) {
      throw FormatException('Not a number of milliseconds', text);
    }
    return Duration(milliseconds: milliseconds);
  },
);

/// The same type under another prefix, the legacy sembast one.
final legacyTimestampType = ObjectCustomTypeHandler(
  id: 'Timestamp',
  label: 'Timestamp (legacy)',
  prefix: '@',
  matchesValue: (value) => value is sembast.Timestamp,
  newValueBuilder: sembast.Timestamp.now,
  formatValue: (value) => (value as sembast.Timestamp).toIso8601String(),
  parseValue: (text) => sembast.Timestamp.parse(text.trim()),
);

void main() {
  group('a declared custom type', () {
    late ObjectTypeRegistry registry;

    setUp(() {
      registry = defaultObjectTypeRegistry.withHandlers([durationType]);
    });

    test('types, formats and parses its values', () {
      expect(registry.typeOf(const Duration(seconds: 1)), durationType);
      expect(durationType.format(const Duration(seconds: 1)), '1000');
      expect(durationType.toText(const Duration(seconds: 1)), '1000');
      expect(
        durationType.parseText('1500'),
        const Duration(milliseconds: 1500),
      );
      expect(durationType.newValue, Duration.zero);
      expect(durationType.isCustom, isTrue);
      expect(
        () => durationType.parseText('soon'),
        throwsA(isA<FormatException>()),
      );
    });

    test('round trips through json under its key', () {
      var value = {'every': const Duration(seconds: 1)};
      var jsonValue = registry.toJsonEncodable(value);
      expect(jsonValue, {
        'every': {r'$duration': '1000'},
      });
      expect(registry.fromJsonEncodable(jsonValue), value);
    });

    test('is offered by the editor like any other type', () {
      var editor = ObjectEditor(<String, Object?>{}, typeRegistry: registry);
      expect(
        registry.selectableHandlers.map((handler) => handler.id),
        contains('duration'),
      );
      editor.addField(ObjectPath.root, 'every', typeId: 'duration');
      expect(editor.value, {'every': Duration.zero});
      editor.setTextAt(ObjectPath.root.field('every'), '2000');
      expect(editor.value, {'every': const Duration(seconds: 2)});
    });

    test('a registry that does not know it keeps the value as is', () {
      var jsonValue = registry.toJsonEncodable({
        'every': const Duration(seconds: 1),
      });
      expect(defaultObjectTypeRegistry.fromJsonEncodable(jsonValue), {
        'every': {r'$duration': '1000'},
      });
    });
  });

  group('another prefix', () {
    late ObjectTypeRegistry registry;

    setUp(() {
      registry = defaultObjectTypeRegistry.withHandlers([legacyTimestampType]);
    });

    test('encodes under the prefix its type declares', () {
      var jsonValue = registry.toJsonEncodable({
        'when': sembast.Timestamp.parse('2024-01-02T03:04:05.000Z'),
      });
      expect(jsonValue, {
        'when': {'@Timestamp': '2024-01-02T03:04:05.000Z'},
      });
      expect(registry.fromJsonEncodable(jsonValue), {
        'when': sembast.Timestamp.parse('2024-01-02T03:04:05.000Z'),
      });
      expect(registry.prefixes, {r'$', '@'});
    });

    test('escapes a map that looks encoded under either prefix', () {
      for (var value in [
        {'@Timestamp': 'not a date'},
        {r'$dateTime': 'not a date'},
      ]) {
        expect(
          registry.fromJsonEncodable(registry.toJsonEncodable(value)),
          value,
        );
      }
    });
  });

  group('the backend registries', () {
    test('sembast and sdb read the same types', () {
      // sdb is idb_shim over sembast: one Timestamp, one Blob, one registry.
      expect(sdbObjectTypeRegistry, same(sembastObjectTypeRegistry));
      expect(
        sembastObjectTypeRegistry.customHandlers.map((handler) => handler.id),
        ['timestamp', 'blob', 'dateTime'],
      );
    });

    test('firestore reads its own four', () {
      // ignore: deprecated_member_use
      var registry = firestoreObjectTypeRegistry(newFirestoreMemory());
      expect(registry.customHandlers.map((handler) => handler.id), [
        'timestamp',
        'blob',
        'geoPoint',
        'documentReference',
        'dateTime',
      ]);
    });
  });
}
