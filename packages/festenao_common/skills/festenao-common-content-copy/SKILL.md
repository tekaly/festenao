---
name: festenao-common-content-copy
description: >-
  Use when copying records from one festenao project content database into
  another (last edition into this one, a template into a new project) with
  the festenao_common copy engine (festenao_sdb.dart): SdfCopier,
  SdfCopyKind, sdfCopyStoreKind, sdfCopyStore, sdfCopyListStore,
  SdfCopyConflictMode (skip, overwrite), SdfCopyRecordInfo,
  SdfCopyKindResult, SdfCopyResult, kindIdsWithDependencies, listRecords,
  copy with recordIdsByKind.
---

# Copying project content (festenao_common)

The copy engine copies the records of an `SdfContentSdb` into another one
under the same ids, so the references between records keep working without
remapping. An app declares its kinds (one store each, usually), in
dependency order, in an `SdfCopier`.

## Guidelines

* One import: `package:festenao_common/festenao_sdb.dart` (it also exports
  `SdfContentSdb` and the cv sdb api).
* A kind per store: `sdfCopyStoreKind(store, id:, label:, recordLabel:,
  dependsOn:, sortById:)`. `id` is stable (remember a selection with it),
  `label` is shown, `recordLabel` names a record in a selection list,
  `dependsOn` lists the kind ids it references, `sortById` lists by id
  (ids starting with a day) rather than by label. A custom kind:
  `SdfCopyKind(id:, label:, list:, copy:)`.
* `SdfCopier(kinds)`: the kinds **in dependency order** (a kind after what
  it references). `kindIdsWithDependencies(selected)` adds what they need,
  `listRecords(source)` lists every kind for a selection screen,
  `copy(source:, destination:, selectedKindIds:, conflictMode:,
  recordIdsByKind:)` copies in order and returns an `SdfCopyResult`
  (`totalCopied`, `totalSkipped`, one `SdfCopyKindResult` per kind).
* Conflicts: `SdfCopyConflictMode.skip` (default) keeps the destination
  record and counts it as skipped; `overwrite` replaces it. Records outside
  `recordIdsByKind[kind]` are neither copied nor counted.
* Copy what carries over (people, places, types), not what belongs to one
  edition (attendances, stays): leave those kinds out of the copier.
* Both databases must be open with schemas holding the stores; for a
  synced content, write into the destination then let it sync.

## Example

```dart
import 'package:festenao_common/festenao_sdb.dart';

final copier = SdfCopier([
  sdfCopyStoreKind(
    typeStore,
    id: 'types',
    label: 'Types',
    recordLabel: (type) => type.name.v ?? type.id,
  ),
  sdfCopyStoreKind(
    itemStore,
    id: 'items',
    label: 'Items',
    dependsOn: ['types'],
    recordLabel: (item) => item.name.v ?? item.id,
  ),
]);

Future<int> carryOver(SdfContentSdb last, SdfContentSdb next) async {
  var result = await copier.copy(
    source: last,
    destination: next,
    selectedKindIds: ['items'], // types come along
  );
  return result.totalCopied;
}
```

See `test/data/sdf_copy_test.dart`.
