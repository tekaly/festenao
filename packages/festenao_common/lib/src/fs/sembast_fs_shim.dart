/// A sembast database factory over an `fs_shim` file system.
///
/// sembast ports itself through its own small [sfs.FileSystem] seam — the one
/// `DatabaseFactoryIo` and the web factory are built on — but it has no
/// `fs_shim` implementation of it. This is that implementation, so a sembast
/// database file that sits in an `fs_shim` file system can be opened from it,
/// wherever that file system lives: the disk, memory, indexeddb in a browser.
///
/// It is what lets [FileSystemExplorer] open the databases it lists, on io and
/// in a web simulation alike.
library;

// sembast exposes its porting seam under src/, see the library comment.
// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fs_shim/fs.dart' as fs;
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:idb_shim/sdb.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/file_system.dart' as sfs;
import 'package:sembast/src/sembast_fs.dart' as sfs;

/// A sembast database factory reading and writing through [fileSystem].
///
/// ```dart
/// var factory = getDatabaseFactoryFsShim(newFileSystemMemory());
/// var db = await factory.openDatabase('my.db');
/// ```
DatabaseFactory getDatabaseFactoryFsShim(fs.FileSystem fileSystem) =>
    sfs.DatabaseFactoryFs(_FsShimFileSystem(fileSystem));

/// An sdb factory reading and writing through [fileSystem].
///
/// sdb is `idb_shim` over sembast, so an sdb database in an `fs_shim` file
/// system is one sembast file, opened through [getDatabaseFactoryFsShim].
SdbFactory getSdbFactoryFsShim(fs.FileSystem fileSystem) =>
    sdbFactoryFromIdb(IdbFactorySembast(getDatabaseFactoryFsShim(fileSystem)));

class _FsShimFileSystem implements sfs.FileSystem {
  final fs.FileSystem impl;

  _FsShimFileSystem(this.impl);

  @override
  sfs.Directory directory(String path) => _FsShimDirectory(this, path);

  @override
  sfs.File file(String path) => _FsShimFile(this, path);

  @override
  Future<bool> isDirectory(String path) => impl.isDirectory(path);

  @override
  Future<bool> isFile(String path) => impl.isFile(path);

  @override
  Future<sfs.FileSystemEntityType> type(
    String path, {
    bool followLinks = true,
  }) async {
    var type = await impl.type(path, followLinks: followLinks);
    if (type == fs.FileSystemEntityType.file) {
      return sfs.FileSystemEntityType.file;
    }
    if (type == fs.FileSystemEntityType.directory) {
      return sfs.FileSystemEntityType.directory;
    }
    if (type == fs.FileSystemEntityType.link) {
      return sfs.FileSystemEntityType.link;
    }
    return sfs.FileSystemEntityType.notFound;
  }

  @override
  sfs.Directory get currentDirectory =>
      _FsShimDirectory(this, impl.currentDirectory.path);

  /// No script when the file system is not the io one, and sembast does not
  /// read it: it only ever matters to a tool resolving a relative path.
  @override
  sfs.File? get scriptFile => null;

  @override
  String toString() => 'FsShim(${impl.name})';
}

abstract class _FsShimEntity implements sfs.FileSystemEntity {
  final _FsShimFileSystem _fs;

  @override
  final String path;

  _FsShimEntity(this._fs, this.path);

  fs.FileSystemEntity get _impl;

  @override
  sfs.FileSystem get fileSystem => _fs;

  @override
  Future<bool> exists() => _impl.exists();

  @override
  Future<sfs.FileSystemEntity> delete({bool recursive = false}) async {
    await _impl.delete(recursive: recursive);
    return this;
  }

  @override
  String toString() => '$runtimeType($path)';
}

class _FsShimDirectory extends _FsShimEntity implements sfs.Directory {
  _FsShimDirectory(super.fs, super.path);

  @override
  fs.Directory get _impl => _fs.impl.directory(path);

  @override
  Future<sfs.Directory> create({bool recursive = false}) async {
    await _impl.create(recursive: recursive);
    return this;
  }

  @override
  Future<sfs.FileSystemEntity> rename(String newPath) async {
    await _impl.rename(newPath);
    return _FsShimDirectory(_fs, newPath);
  }
}

class _FsShimFile extends _FsShimEntity implements sfs.File {
  _FsShimFile(super.fs, super.path);

  @override
  fs.File get _impl => _fs.impl.file(path);

  @override
  Future<sfs.File> create({bool recursive = false}) async {
    await _impl.create(recursive: recursive);
    return this;
  }

  @override
  Stream<Uint8List> openRead([int? start, int? end]) =>
      _impl.openRead(start, end);

  @override
  sfs.IOSink openWrite({
    sfs.FileMode mode = sfs.FileMode.write,
    Encoding encoding = utf8,
  }) => _FsShimIOSink(
    _impl.openWrite(mode: _fileMode(mode), encoding: encoding),
    encoding,
  );

  @override
  Future<sfs.File> rename(String newPath) async {
    await _impl.rename(newPath);
    return _FsShimFile(_fs, newPath);
  }

  static fs.FileMode _fileMode(sfs.FileMode mode) {
    if (mode == sfs.FileMode.append) {
      return fs.FileMode.append;
    }
    if (mode == sfs.FileMode.read) {
      return fs.FileMode.read;
    }
    return fs.FileMode.write;
  }
}

/// sembast writes a database one json line at a time, which is all of
/// [sfs.IOSink] it uses.
class _FsShimIOSink implements sfs.IOSink {
  final fs.FileStreamSink _sink;
  final Encoding _encoding;

  _FsShimIOSink(this._sink, this._encoding);

  @override
  void writeln([Object obj = '']) => _sink.add(_encoding.encode('$obj\n'));

  @override
  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}
