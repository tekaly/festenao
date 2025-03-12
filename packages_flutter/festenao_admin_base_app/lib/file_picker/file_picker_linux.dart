import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

Future<FilePickerResult?> ioPickImageFileLinux(BuildContext context) async {
  var result = await openFile();

  if (result == null) {
    return null;
  } else {
    var bytes = await result.readAsBytes();
    return FilePickerResult([
      PlatformFile(
        path: result.path,
        name: result.name,
        bytes: bytes,
        size: bytes.length,
      ),
    ]);
  }
}
