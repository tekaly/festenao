import 'package:festenao_common/data/object_storage.dart';
import 'package:flutter/material.dart';
import 'object_storage_picker.dart';

/// A full screen Scaffold wrapping [ObjectStoragePicker].
class ObjectStoragePickerScreen extends StatelessWidget {
  /// Title of the screen.
  final String title;

  /// The object storage implementation.
  final ObjectStorage storage;

  /// The root/parent folder path to browse.
  final String parentPath;

  /// Optional list of allowed MIME types.
  final List<String>? allowedMimeTypes;

  /// Whether multi-selection is enabled.
  final bool allowMultiSelect;

  /// Whether developer mode is enabled.
  final bool developerMode;

  /// Create a new [ObjectStoragePickerScreen] widget.
  const ObjectStoragePickerScreen({
    super.key,
    this.title = 'Select Files',
    required this.storage,
    required this.parentPath,
    this.allowedMimeTypes,
    this.allowMultiSelect = false,
    this.developerMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ObjectStoragePicker(
        storage: storage,
        parentPath: parentPath,
        allowedMimeTypes: allowedMimeTypes,
        allowMultiSelect: allowMultiSelect,
        developerMode: developerMode,
        onSelect: (selected) {
          Navigator.of(context).pop(selected);
        },
      ),
    );
  }
}
