import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'file_picker_linux.dart';

Future<FilePickerResult?> ioPickImageFile(BuildContext context) async {
  if (Platform.isLinux) {
    return ioPickImageFileLinux(context);
  }
  return null;
}
