/// Copying records from one project content database into another (the
/// edition of last year into this one, for instance).
///
/// Every store is keyed by a string id, so a record is copied under the very
/// same id in the destination: the references between records keep pointing
/// at the right rows without any remapping. That is also why the kinds of a
/// [SdfCopier] are ordered by dependency, and why copying a kind pulls in
/// what it depends on.
library;

import 'package:festenao_common/src/data/projects_sdb/sdf_content_sdb.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';

/// What happens to a record that already exists in the destination.
enum SdfCopyConflictMode {
  /// Keep the destination record untouched.
  skip,

  /// Replace the destination record with the source one.
  overwrite,
}

/// One record of the source database, as offered for selection.
class SdfCopyRecordInfo {
  /// Record id, the key it is copied under.
  final String id;

  /// Human readable name, what a selection list shows.
  final String label;

  /// A record of the source.
  SdfCopyRecordInfo({required this.id, required this.label});

  @override
  String toString() => '$label ($id)';
}

/// How many records of one kind were copied and how many were left alone.
class SdfCopyKindResult {
  /// Display name of the kind.
  final String label;

  /// Records written into the destination.
  final int copied;

  /// Records skipped because they already existed.
  final int skipped;

  /// The result of one kind.
  SdfCopyKindResult({
    required this.label,
    required this.copied,
    required this.skipped,
  });
}

/// The result of a whole copy run.
class SdfCopyResult {
  /// One entry per copied kind, in copy order.
  final List<SdfCopyKindResult> kinds;

  /// The result of a run.
  SdfCopyResult({required this.kinds});

  /// Total records written into the destination.
  int get totalCopied => kinds.fold(0, (total, kind) => total + kind.copied);

  /// Total records left untouched because they already existed.
  int get totalSkipped => kinds.fold(0, (total, kind) => total + kind.skipped);
}

/// One kind of record that can be copied from another database.
class SdfCopyKind {
  /// Stable id of the kind, used to remember the user selection.
  final String id;

  /// Display name.
  final String label;

  /// Ids of the kinds this one references; copying it without them leaves
  /// dangling references.
  final List<String> dependsOn;

  /// Lists the records of this kind in source, in display order: what a
  /// screen offers for a per record selection.
  final Future<List<SdfCopyRecordInfo>> Function(SdfContentSdb source) list;

  /// Copies the records of this kind, honouring the conflict mode; the
  /// record ids limit the copy to those ids, null copies every record.
  final Future<SdfCopyKindResult> Function(
    SdfContentSdb source,
    SdfContentSdb destination,
    SdfCopyConflictMode conflictMode,
    Set<String>? recordIds,
  )
  copy;

  /// A kind with its own [list] and [copy] (see [sdfCopyStoreKind] for the
  /// usual one store kind).
  SdfCopyKind({
    required this.id,
    required this.label,
    required this.list,
    required this.copy,
    this.dependsOn = const [],
  });
}

/// Lists the records of [store] in [source] as [SdfCopyRecordInfo].
///
/// Sorted by [SdfCopyRecordInfo.label] (case insensitive), or by id when
/// [sortById] is set (ids starting with a day or a time, whose id order is
/// the chronological one).
Future<List<SdfCopyRecordInfo>> sdfCopyListStore<T extends ScvRecord<String>>(
  ScvStringStoreRef<T> store, {
  required SdfContentSdb source,
  required String Function(T record) recordLabel,
  bool sortById = false,
}) async {
  var records = await store.findRecords(source.db);
  var result = <SdfCopyRecordInfo>[];
  for (var record in records) {
    var id = record.idOrNull;
    if (id == null || id.isEmpty) {
      continue;
    }
    result.add(SdfCopyRecordInfo(id: id, label: recordLabel(record)));
  }
  result.sort((a, b) {
    if (sortById) {
      return a.id.compareTo(b.id);
    }
    var byLabel = a.label.toLowerCase().compareTo(b.label.toLowerCase());
    return byLabel != 0 ? byLabel : a.id.compareTo(b.id);
  });
  return result;
}

/// Copies the records of [store] from [source] to [destination], keeping
/// the record ids; [recordIds] limits the copy to those ids, null copies
/// every record.
Future<SdfCopyKindResult> sdfCopyStore<T extends ScvRecord<String>>(
  ScvStringStoreRef<T> store, {
  required String label,
  required SdfContentSdb source,
  required SdfContentSdb destination,
  required SdfCopyConflictMode conflictMode,
  Set<String>? recordIds,
}) async {
  var records = await store.findRecords(source.db);
  var existingIds = (await store.findRecordKeys(destination.db)).toSet();
  var copied = 0;
  var skipped = 0;
  for (var record in records) {
    var id = record.idOrNull;
    if (id == null || id.isEmpty) {
      continue;
    }
    // Not part of the selection: not copied, and not reported as skipped
    // either, only a conflict is.
    if (recordIds != null && !recordIds.contains(id)) {
      continue;
    }
    if (existingIds.contains(id) && conflictMode == SdfCopyConflictMode.skip) {
      skipped++;
      continue;
    }
    var copy = store.record(id).cv()..copyFrom(record);
    await store.record(id).put(destination.db, copy);
    copied++;
  }
  return SdfCopyKindResult(label: label, copied: copied, skipped: skipped);
}

/// A [SdfCopyKind] backed by a single store, listed and copied by id.
SdfCopyKind sdfCopyStoreKind<T extends ScvRecord<String>>(
  ScvStringStoreRef<T> store, {
  required String id,
  required String label,
  required String Function(T record) recordLabel,
  List<String> dependsOn = const [],
  bool sortById = false,
}) => SdfCopyKind(
  id: id,
  label: label,
  dependsOn: dependsOn,
  list: (source) => sdfCopyListStore(
    store,
    source: source,
    recordLabel: recordLabel,
    sortById: sortById,
  ),
  copy: (source, destination, mode, recordIds) => sdfCopyStore(
    store,
    label: label,
    source: source,
    destination: destination,
    conflictMode: mode,
    recordIds: recordIds,
  ),
);

/// The kinds an app copies between its content databases, in dependency
/// order (a kind after what it references).
class SdfCopier {
  /// The kinds, in copy order.
  final List<SdfCopyKind> kinds;

  /// A copier of [kinds].
  SdfCopier(this.kinds);

  /// The kind with this [id], or null.
  SdfCopyKind? kindById(String id) =>
      kinds.where((kind) => kind.id == id).firstOrNull;

  /// [selectedKindIds] plus, transitively, everything they depend on: a
  /// kind is never copied without what it references.
  Set<String> kindIdsWithDependencies(Iterable<String> selectedKindIds) {
    var result = <String>{};
    void add(String id) {
      if (!result.add(id)) {
        return;
      }
      for (var dependencyId in kindById(id)?.dependsOn ?? const <String>[]) {
        add(dependencyId);
      }
    }

    for (var id in selectedKindIds) {
      add(id);
    }
    return result;
  }

  /// Lists the records of every kind in [source], keyed by kind id.
  Future<Map<String, List<SdfCopyRecordInfo>>> listRecords(
    SdfContentSdb source,
  ) async {
    var result = <String, List<SdfCopyRecordInfo>>{};
    for (var kind in kinds) {
      result[kind.id] = await kind.list(source);
    }
    return result;
  }

  /// Copies [selectedKindIds] (and their dependencies) from [source] into
  /// [destination], in [kinds] order, so a record is always written after
  /// what it references.
  ///
  /// [recordIdsByKind] narrows a kind to the listed record ids; a kind
  /// absent from it (the default for every kind) copies all its records.
  Future<SdfCopyResult> copy({
    required SdfContentSdb source,
    required SdfContentSdb destination,
    required Iterable<String> selectedKindIds,
    SdfCopyConflictMode conflictMode = SdfCopyConflictMode.skip,
    Map<String, Set<String>>? recordIdsByKind,
  }) async {
    var kindIds = kindIdsWithDependencies(selectedKindIds);
    var results = <SdfCopyKindResult>[];
    for (var kind in kinds) {
      if (!kindIds.contains(kind.id)) {
        continue;
      }
      results.add(
        await kind.copy(
          source,
          destination,
          conflictMode,
          recordIdsByKind?[kind.id],
        ),
      );
    }
    return SdfCopyResult(kinds: results);
  }
}
