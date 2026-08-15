import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:tekartik_app_platform/app_platform.dart';

import 'file_picker_io.dart'
    if (dart.library.js_interop) 'file_picker_web.dart';

String? lastDir;

Future<PlatformFile?> pickImageFile(BuildContext context) =>
    _pickFile(context, type: FileType.image);

Future<PlatformFile?> pickAnyFile(BuildContext context) =>
    _pickFile(context, type: FileType.any);

Future<PlatformFile?> _pickFile(
  BuildContext context, {
  required FileType type,
}) async {
  // Tested on linux only
  if (platformContext.io?.isLinux ?? false) {
    return await ioPickImageFile(context);
  } else {
    var file = await FilePicker.pickFile(
      type: type,
      //allowedExtensions: ['.jpg', '.JPG', '.png', '.PNG']
    );

    if (file != null) {
      lastDir = dirname(file.path ?? file.name);
    }
    return file;
  }
}
