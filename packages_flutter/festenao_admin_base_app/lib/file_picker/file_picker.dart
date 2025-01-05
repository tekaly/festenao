import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:tekartik_app_platform/app_platform.dart';

import 'file_picker_io.dart'
    if (dart.library.js_interop) 'file_picker_web.dart';

String? lastDir;

Future<FilePickerResult?> pickImageFile(BuildContext context) async {
  // Tested on linux only
  if (platformContext.io?.isLinux ?? false) {
    return await ioPickImageFile(context);
  } else {
    var ffpResult = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,

      //allowedExtensions: ['.jpg', '.JPG', '.png', '.PNG']
    );

    if (ffpResult != null) {
      var lastName = ffpResult.files.firstOrNull?.name;
      if (lastName != null) {
        lastDir = dirname(lastName);
      }
      return ffpResult;
    }
  }
  return null;
}
