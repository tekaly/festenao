/// The flutter side of the generic object editor: a record editor like the
/// firestore console one, and an explorer browsing a database with it.
///
/// It edits anything an `ObjectSource` reaches — a json or yaml file (through
/// `fs_shim`, so a browser too), a sembast or sdb record, a firestore
/// document, a `cv` model — with a type selector per value, custom types
/// (timestamp, blob, geo point, document reference) included.
///
/// ```dart
/// await goToObjectExplorerScreen(
///   context,
///   repository: SdbObjectRepository(db),
/// );
/// ```
library;

export 'package:festenao_common/data/object_editor.dart';

export 'src/object_editor/object_clipboard_flutter.dart'
    show FlutterObjectClipboard, globalFlutterObjectClipboard;
export 'src/object_editor/object_editor_dialogs.dart'
    show
        ObjectEditorNewField,
        objectEditorPromptConfirm,
        objectEditorPromptNewField,
        objectEditorPromptText,
        objectEditorPromptType;
export 'src/object_editor/object_editor_screen.dart'
    show ObjectEditorScreen, goToObjectEditorScreen;
export 'src/object_editor/object_editor_view.dart' show ObjectEditorView;
export 'src/object_editor/object_explorer_screen.dart'
    show
        ObjectCollectionScreen,
        ObjectExplorerScreen,
        goToObjectCollectionScreen,
        goToObjectExplorerScreen;
export 'src/object_editor/object_value_editor.dart'
    show
        ObjectDateValueField,
        ObjectTextValueField,
        ObjectValueEditorBuilder,
        ObjectValueEditorRegistry,
        defaultObjectValueEditorBuilders,
        defaultObjectValueEditorRegistry,
        objectBoolValueEditorBuilder,
        objectDateValueEditorBuilder,
        objectNullValueEditorBuilder,
        objectTextValueEditorBuilder;
