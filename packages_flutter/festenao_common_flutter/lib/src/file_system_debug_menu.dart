import 'package:tekartik_app_flutter_widget/mini_ui.dart';

import 'file_system_root_picker.dart';
import 'object_editor/object_value_editor.dart';

/// A debug menu item opening the file system explorer.
///
/// It goes through [FileSystemRootPickerScreen]: the directory is picked
/// among the ones `path_provider` names — documents, support, temporary,
/// downloads, external storage — plus the current one and a scratch memory
/// file system, and the explorer opens sandboxed in it.
///
/// Declare it inside a `muiBodyWidget` or a `muiMenu`:
///
/// ```dart
/// muiBodyWidget(() {
///   festenaoFileSystemExplorerMenuItem(packageName: 'com.example.my_app');
/// });
/// ```
void festenaoFileSystemExplorerMenuItem({
  String title = 'File system explorer',
  bool isReadOnly = false,
  String? packageName,
  ObjectValueEditorRegistry? valueEditors,
}) {
  muiItem(title, () {
    goToFileSystemRootPickerScreen(
      muiBuildContext,
      isReadOnly: isReadOnly,
      packageName: packageName,
      valueEditors: valueEditors,
    );
  });
}
