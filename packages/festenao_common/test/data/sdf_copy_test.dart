import 'package:festenao_common/festenao_sdb.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:test/test.dart';

class _Type extends ScvStringRecordBase {
  final name = CvField<String>('name');

  @override
  CvFields get fields => [name];
}

class _Item extends ScvStringRecordBase {
  final name = CvField<String>('name');
  final typeId = CvField<String>('typeId');

  @override
  CvFields get fields => [name, typeId];
}

final _typeStore = scvStringStoreFactory.store<_Type>('type');
final _itemStore = scvStringStoreFactory.store<_Item>('item');

final _copier = SdfCopier([
  sdfCopyStoreKind(
    _typeStore,
    id: 'types',
    label: 'Types',
    recordLabel: (type) => type.name.v ?? type.id,
  ),
  sdfCopyStoreKind(
    _itemStore,
    id: 'items',
    label: 'Items',
    dependsOn: ['types'],
    recordLabel: (item) => item.name.v ?? item.id,
  ),
]);

Future<SdfContentSdb> _open(String name) async {
  await sdbFactoryMemory.deleteDatabase(name);
  var db = await sdbFactoryMemory.openDatabase(
    name,
    options: SdbOpenDatabaseOptions(
      version: 1,
      schema: SdbDatabaseSchema(
        stores: [_typeStore.schema(), _itemStore.schema()],
      ),
    ),
  );
  return SdfContentSdb(fs: newFileSystemMemory(), db: db);
}

void main() {
  late SdfContentSdb source;
  late SdfContentSdb destination;

  setUpAll(() {
    cvAddConstructors([_Type.new, _Item.new]);
  });

  setUp(() async {
    source = await _open('source.db');
    destination = await _open('destination.db');
    for (var (id, name) in [('band', 'Band'), ('crew', 'crew')]) {
      await _typeStore.record(id).put(source.db, _Type()..name.v = name);
    }
    for (var (id, name, typeId) in [
      ('b', 'Zébulon', 'band'),
      ('a', 'alice', 'crew'),
    ]) {
      await _itemStore
          .record(id)
          .put(
            source.db,
            _Item()
              ..name.v = name
              ..typeId.v = typeId,
          );
    }
    await _itemStore.record('a').put(destination.db, _Item()..name.v = 'Old');
  });

  tearDown(() async {
    await source.db.close();
    await destination.db.close();
  });

  test('dependencies', () {
    expect(_copier.kindIdsWithDependencies(['items']), {'items', 'types'});
    expect(_copier.kindIdsWithDependencies(['types']), {'types'});
    expect(_copier.kindById('items')!.label, 'Items');
    expect(_copier.kindById('nope'), isNull);
  });

  test('list by label', () async {
    var records = await _copier.listRecords(source);
    expect(records['items']!.map((info) => info.label), ['alice', 'Zébulon']);
    expect(records['types']!.map((info) => info.id), ['band', 'crew']);
  });

  test('copy, skipping what exists, with its dependencies', () async {
    var result = await _copier.copy(
      source: source,
      destination: destination,
      selectedKindIds: ['items'],
    );
    expect(result.kinds.map((kind) => kind.label), ['Types', 'Items']);
    expect(result.totalCopied, 3);
    expect(result.totalSkipped, 1);
    expect((await _itemStore.record('a').get(destination.db))!.name.v, 'Old');
    expect(
      (await _itemStore.record('b').get(destination.db))!.typeId.v,
      'band',
    );
  });

  test('overwrite, a selection', () async {
    var result = await _copier.copy(
      source: source,
      destination: destination,
      selectedKindIds: ['items'],
      conflictMode: SdfCopyConflictMode.overwrite,
      recordIdsByKind: {
        'items': {'a'},
        'types': {'crew'},
      },
    );
    expect(result.totalCopied, 2);
    expect(result.totalSkipped, 0);
    expect((await _itemStore.record('a').get(destination.db))!.name.v, 'alice');
    expect(await _itemStore.record('b').get(destination.db), isNull);
    expect(await _typeStore.record('band').get(destination.db), isNull);
  });
}
