/// Console editor of a json file.
///
/// ```sh
/// dart example/edit_json.dart my_file.json
/// ```
///
/// The file is created on the first save when it does not exist yet. Menu
/// commands can be given after the path, so
/// `dart example/edit_json.dart my_file.json 1 .` prints the document and
/// leaves.
library;

import 'package:festenao_common/data/object_editor_io.dart';

Future<void> main(List<String> args) => objectFileConsoleEditorMain(
  args,
  format: objectJsonFormat,
  usage: 'Usage: dart example/edit_json.dart <file.json> [menu commands]',
);
