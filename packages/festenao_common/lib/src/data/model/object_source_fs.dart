import 'package:fs_shim/fs.dart';

import 'object_edit_operation.dart';
import 'object_source.dart';
import 'object_text_format.dart';
import 'object_type_registry.dart';

/// A json or yaml file, read and written through `fs_shim`.
///
/// `fs_shim` is what makes this work everywhere: the same source edits a real
/// file on io, an in memory or indexeddb one on the web
/// (`newFileSystemMemory()`, `fileSystemWeb`), which is how a file editor is
/// tried out in a browser.
///
/// The format comes from the extension of the file unless [format] says
/// otherwise. A yaml file is saved in place: the comments, the key order and
/// the layout survive an edit, see [ObjectYamlFormat].
class FsObjectSource extends ObjectSource {
  /// The file, existing or not.
  final File file;

  /// How the file is read and written.
  final ObjectTextFormat format;

  @override
  final ObjectTypeRegistry typeRegistry;

  @override
  final bool isReadOnly;

  /// Source of [file], in [format] or in the format its extension names (json
  /// by default).
  FsObjectSource(
    this.file, {
    ObjectTextFormat? format,
    ObjectTypeRegistry? typeRegistry,
    this.isReadOnly = false,
  }) : format = format ?? objectTextFormatOf(file.path) ?? objectJsonFormat,
       typeRegistry = typeRegistry ?? defaultObjectTypeRegistry;

  /// Source of the file at [path] in [fileSystem].
  factory FsObjectSource.path(
    FileSystem fileSystem,
    String path, {
    ObjectTextFormat? format,
    ObjectTypeRegistry? typeRegistry,
    bool isReadOnly = false,
  }) => FsObjectSource(
    fileSystem.file(path),
    format: format,
    typeRegistry: typeRegistry,
    isReadOnly: isReadOnly,
  );

  @override
  String get title => file.path;

  @override
  Future<Object?> read() async {
    var text = await _readText();
    if (text == null) {
      return null;
    }
    return format.decode(text, typeRegistry: typeRegistry);
  }

  @override
  Future<void> write(
    Object? value, {
    List<ObjectEditOperation>? operations,
  }) async {
    checkWritable();
    var source = await _readText() ?? '';
    var text = format.encodeFrom(
      source,
      value,
      typeRegistry: typeRegistry,
      operations: operations,
    );
    var parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsString(text);
  }

  @override
  Future<void> delete() async {
    checkWritable('delete $title');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String?> _readText() async {
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }
}

/// The json or yaml files of a directory, each one an editable object.
///
/// The id of an object is its file name without the extension, so `config` in
/// a json collection is the file `config.json`.
class FsObjectCollection extends ObjectCollection {
  /// The directory, existing or not.
  final Directory directory;

  /// The format the files are read and written in, and whose first extension a
  /// new file takes.
  final ObjectTextFormat format;

  @override
  final ObjectTypeRegistry typeRegistry;

  @override
  final bool isReadOnly;

  /// Collection of the [format] files of [directory].
  FsObjectCollection(
    this.directory, {
    ObjectTextFormat? format,
    ObjectTypeRegistry? typeRegistry,
    this.isReadOnly = false,
  }) : format = format ?? objectJsonFormat,
       typeRegistry = typeRegistry ?? defaultObjectTypeRegistry;

  @override
  String get name => directory.path;

  @override
  Future<List<String>> listIds({int? limit}) async {
    if (!await directory.exists()) {
      return [];
    }
    var ids = <String>[];
    await for (var entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      if (!format.matchesPath(entity.path)) {
        continue;
      }
      ids.add(directory.fs.path.basenameWithoutExtension(entity.path));
      if (limit != null && ids.length >= limit) {
        break;
      }
    }
    ids.sort();
    return ids;
  }

  @override
  ObjectSource source(String id) => FsObjectSource(
    directory.fs.file(
      directory.fs.path.join(directory.path, '$id${format.extensions.first}'),
    ),
    format: format,
    typeRegistry: typeRegistry,
    isReadOnly: isReadOnly,
  );

  @override
  Future<String> add(Object? value) async {
    checkWritable('add to $name');
    var id = 'object_${DateTime.now().millisecondsSinceEpoch}';
    await source(id).write(value);
    return id;
  }
}
