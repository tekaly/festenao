/// Console editor of a yaml file.
///
/// ```sh
/// dart example/edit_yaml.dart my_file.yaml
/// ```
///
/// The file is edited in place: the comments, the key order and the layout of
/// what is not touched survive a save, the edits being replayed on the
/// original text through `yaml_edit`. Menu commands can be given after the
/// path, so `dart example/edit_yaml.dart my_file.yaml 1 .` prints the document
/// and leaves.
library;

import 'package:festenao_common/data/object_editor_io.dart';

Future<void> main(List<String> args) => objectFileConsoleEditorMain(
  args,
  format: objectYamlFormat,
  usage: 'Usage: dart example/edit_yaml.dart <file.yaml> [menu commands]',
);
