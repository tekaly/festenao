/// The io side of the generic object editor: a console editor and the local
/// file helpers.
///
/// Kept apart from `object_editor.dart` so that one imports on the web:
/// the console menu (`dev_build`) and `fileSystemIo` are io only.
///
/// ```dart
/// import 'package:festenao_common/data/object_editor_io.dart';
///
/// Future<void> main(List<String> args) => objectFileConsoleEditorMain(args);
/// ```
library;

export '../src/data/model/io/object_console_editor.dart'
    show
        objectFileConsoleEditorMain,
        objectSourceConsoleEdit,
        objectSourceConsoleMenuContent,
        objectSourceTextFormat;
export '../src/data/model/io/object_source_io.dart'
    show objectDirectoryCollection, objectFileSource;
export 'object_editor.dart';
