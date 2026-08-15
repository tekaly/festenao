import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

/// [PlatformFile] wrapper on top of a file_selector [XFile].
final class _XFilePlatformFile extends PlatformFile {
  final XFile _xFile;

  _XFilePlatformFile(this._xFile);

  @override
  String get name => _xFile.name;

  @override
  Uri get uri => Uri.file(_xFile.path);

  @override
  XFile get xFile => _xFile;

  @override
  Future<int> length() => _xFile.length();

  @override
  Future<Uint8List> readAsBytes() => _xFile.readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() => _xFile.openRead();
}

Future<PlatformFile?> ioPickImageFileLinux(BuildContext context) async {
  var result = await openFile();

  if (result == null) {
    return null;
  } else {
    return _XFilePlatformFile(result);
  }
}
