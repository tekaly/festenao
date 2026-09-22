import 'dart:async';

import 'object_edit_operation.dart';
import 'object_editor.dart';
import 'object_type_registry.dart';

/// A write refused because what it was asked of is read only: a source, a
/// collection, a repository, a file system explorer.
///
/// Every backend refuses the same way, so a caller handles one exception
/// whatever it is editing.
class ReadOnlyException implements Exception {
  /// What was refused.
  final String message;

  /// Exception on [message].
  ReadOnlyException(this.message);

  @override
  String toString() => 'Read only: $message';
}

/// Where an editable object is read from and written back to: a json file, a
/// sembast record, an sdb record, a firestore document, memory.
///
/// It is the only thing the console editor and the flutter editor need to know
/// about a backend, so the same editor edits any of them.
abstract class ObjectSource {
  /// What the editor displays as the title: a file path, a record key.
  String get title;

  /// True when [write] and [delete] are refused, the editor then being a
  /// viewer.
  bool get isReadOnly => false;

  /// Throws a [ReadOnlyException] when this source is read only.
  ///
  /// Every write of an implementation starts with it, so a read only source
  /// refuses rather than writes, whoever calls it.
  void checkWritable([String? what]) {
    if (isReadOnly) {
      throw ReadOnlyException(what ?? 'write $title');
    }
  }

  /// The types the object may hold, the backend adding its own to the basic
  /// ones (a sembast `Timestamp`, a firestore `DocumentReference`…).
  ObjectTypeRegistry get typeRegistry => defaultObjectTypeRegistry;

  /// The object, null when there is none yet (an unsaved file, a missing
  /// record).
  Future<Object?> read();

  /// Writes [value] back.
  ///
  /// [operations] are the edits that produced [value], in order, for the
  /// backends that can apply them rather than write the whole object — a yaml
  /// file, whose comments and layout survive that way. A backend that ignores
  /// them writes [value] as a whole, which is always correct.
  Future<void> write(Object? value, {List<ObjectEditOperation>? operations});

  /// The object each time it changes, null when the backend does not watch.
  Stream<Object?>? watch() => null;

  /// Removes the object, when the backend allows it.
  Future<void> delete() =>
      throw UnsupportedError('$runtimeType cannot delete $title');

  @override
  String toString() => '$runtimeType($title)';
}

/// A set of objects of the same shape, addressed by id: a sembast or sdb
/// store, a firestore collection, a directory of json files.
abstract class ObjectCollection {
  /// What an explorer displays: the store or collection name.
  String get name;

  /// True when [add] and the sources of this collection are refused writes.
  bool get isReadOnly => false;

  /// Throws a [ReadOnlyException] when this collection is read only.
  void checkWritable([String? what]) {
    if (isReadOnly) {
      throw ReadOnlyException(what ?? 'write to $name');
    }
  }

  /// The types the objects may hold, [ObjectSource.typeRegistry] of every
  /// source of this collection.
  ObjectTypeRegistry get typeRegistry => defaultObjectTypeRegistry;

  /// The ids in the collection, at most [limit] of them.
  Future<List<String>> listIds({int? limit});

  /// The source of the object of id [id], whether it exists or not.
  ObjectSource source(String id);

  /// The ids each time they change, null when the backend does not watch.
  Stream<List<String>>? watchIds({int? limit}) => null;

  /// Adds an object, answering the id it took.
  Future<String> add(Object? value) =>
      throw UnsupportedError('$runtimeType cannot add to $name');

  @override
  String toString() => '$runtimeType($name)';
}

/// A set of collections: a sembast or sdb database, a firestore instance, a
/// directory tree.
abstract class ObjectRepository {
  /// What an explorer displays: the database name.
  String get title;

  /// True when every collection of this repository is read only.
  bool get isReadOnly => false;

  /// The collections, the stores of a database.
  Future<List<ObjectCollection>> listCollections();

  @override
  String toString() => '$runtimeType($title)';
}

/// An [ObjectSource] loaded in an [ObjectEditor]: what the editors drive.
///
/// It owns the load/save cycle — reading the object, handing the editor the
/// edits, writing them back with the operations the source may apply in place.
///
/// ```dart
/// var sourceEditor = ObjectSourceEditor(source);
/// var editor = await sourceEditor.load();
/// editor.setValueAt(ObjectPath.root.field('name'), 'new name');
/// await sourceEditor.save();
/// ```
class ObjectSourceEditor {
  /// Where the object comes from and goes back to.
  final ObjectSource source;

  ObjectEditor? _editor;

  /// Editor of [source], nothing loaded yet.
  ObjectSourceEditor(this.source);

  /// The editor, null until [load] answered.
  ObjectEditor? get editorOrNull => _editor;

  /// The editor, throws a [StateError] before [load].
  ObjectEditor get editor =>
      _editor ?? (throw StateError('$source is not loaded yet'));

  /// True when the loaded object has unsaved edits.
  bool get isDirty => _editor?.isDirty ?? false;

  /// Reads the object and puts it in a new editor.
  ///
  /// A source holding nothing yet starts on an empty map, so a new file is
  /// edited like any other.
  Future<ObjectEditor> load() async {
    var value = await source.read();
    await _editor?.close();
    var editor = _editor = ObjectEditor(
      value ?? <String, Object?>{},
      typeRegistry: source.typeRegistry,
    );
    return editor;
  }

  /// Writes the edits back and marks the editor clean.
  ///
  /// Does nothing when nothing was edited. Throws a [StateError] on a read
  /// only source.
  Future<void> save() async {
    var editor = this.editor;
    source.checkWritable('save ${source.title}');
    if (!editor.isDirty) {
      return;
    }
    await source.write(editor.value, operations: editor.operations);
    editor.markClean();
  }

  /// Drops the edits and reads the object again.
  Future<ObjectEditor> reload() => load();

  /// Releases the editor.
  Future<void> close() async {
    await _editor?.close();
    _editor = null;
  }
}

/// A source holding its object in memory, for a test or a demo.
class MemoryObjectSource extends ObjectSource {
  @override
  final String title;

  @override
  final ObjectTypeRegistry typeRegistry;

  @override
  final bool isReadOnly;

  Object? _value;
  final _controller = StreamController<Object?>.broadcast();

  /// Source holding [value].
  MemoryObjectSource({
    this.title = 'memory',
    ObjectTypeRegistry? typeRegistry,
    this.isReadOnly = false,
    Object? value,
  }) : typeRegistry = typeRegistry ?? defaultObjectTypeRegistry {
    _value = value;
  }

  @override
  Future<Object?> read() async => _value;

  @override
  Future<void> write(
    Object? value, {
    List<ObjectEditOperation>? operations,
  }) async {
    checkWritable();
    _value = value;
    _controller.add(value);
  }

  @override
  Stream<Object?> watch() async* {
    yield _value;
    yield* _controller.stream;
  }

  @override
  Future<void> delete() async {
    checkWritable('delete $title');
    _value = null;
    _controller.add(null);
  }

  /// Releases [watch].
  Future<void> close() => _controller.close();
}
