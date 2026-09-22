import 'package:dev_build/menu/menu_io.dart';
import 'package:dev_build/shell.dart'
    show Shell, platformEnvironment, shellArgument;
import 'package:fs_shim/fs.dart';

import '../object_editor.dart';
import '../object_node.dart';
import '../object_path.dart';
import '../object_source.dart';
import '../object_source_fs.dart';
import '../object_text_format.dart';
import '../object_type.dart';
import 'object_source_io.dart';

/// Where the console editor currently sits in the tree, and what it edits.
class _ConsoleEditorState {
  final ObjectSourceEditor sourceEditor;
  final ObjectTextFormat format;
  ObjectPath path = ObjectPath.root;

  _ConsoleEditorState(this.sourceEditor, this.format);

  ObjectEditor get editor => sourceEditor.editor;

  /// The node the cursor sits on, the root when the path went stale — a
  /// removed field, a list that shrank.
  ObjectNode get node => editor.nodeAt(path) ?? _backToRoot();

  ObjectNode _backToRoot() {
    path = ObjectPath.root;
    return editor.rootNode;
  }

  String get documentText =>
      format.encode(editor.value, typeRegistry: editor.typeRegistry);
}

/// The format a source is printed and text edited in: the one a file is
/// written in, json for anything else.
ObjectTextFormat objectSourceTextFormat(ObjectSource source) =>
    source is FsObjectSource ? source.format : objectJsonFormat;

/// Reads [source] and runs the console editor on it.
///
/// [arguments] are the menu ones — an item number, `.` to leave — not the ones
/// naming what to edit: a tool parses its own path argument out first, see
/// [objectFileConsoleEditorMain].
///
/// [externalEditorFilePath] adds an item opening that path in `$EDITOR`, for a
/// source that is a real file on disk.
///
/// ```dart
/// Future<void> main(List<String> args) async {
///   await objectSourceConsoleEdit(
///     FsObjectSource(fileSystemIo.file('config.json')),
///     arguments: args,
///   );
/// }
/// ```
Future<void> objectSourceConsoleEdit(
  ObjectSource source, {
  List<String> arguments = const [],
  String? externalEditorFilePath,
}) async {
  var sourceEditor = ObjectSourceEditor(source);
  await sourceEditor.load();
  mainMenuConsole(arguments, () {
    objectSourceConsoleMenuContent(
      sourceEditor,
      externalEditorFilePath: externalEditorFilePath,
    );
  });
}

/// The console editor items of [sourceEditor], already loaded.
///
/// Declare them in a `mainMenuConsole` block to add the editor to an existing
/// dev menu:
///
/// ```dart
/// mainMenuConsole(args, () {
///   menu('config', () {
///     objectSourceConsoleMenuContent(sourceEditor);
///   });
/// });
/// ```
void objectSourceConsoleMenuContent(
  ObjectSourceEditor sourceEditor, {
  String? externalEditorFilePath,
}) {
  var source = sourceEditor.source;
  var state = _ConsoleEditorState(sourceEditor, objectSourceTextFormat(source));

  enter(() => _writeNode(state));

  item('ls', () => _writeNode(state));
  item('print', () => write(state.documentText));
  item('cd', () async {
    var target = await _promptNavigation(state);
    if (target != null) {
      state.path = target;
      _writeNode(state);
    }
  });
  item('cd /', () {
    state.path = ObjectPath.root;
    _writeNode(state);
  });
  item('edit value', () async {
    var child = await _promptChild(state, 'Edit');
    if (child == null) {
      return;
    }
    await _editValue(state, child);
  });
  item('set type', () async {
    var child = await _promptChild(state, 'Set type');
    if (child == null) {
      return;
    }
    var handler = await _promptType(state, 'Type of ${child.name}');
    if (handler == null) {
      return;
    }
    state.editor.setTypeAt(child.path, handler.id);
    _writeNode(state);
  });
  item('add field', () async {
    var node = state.node;
    if (node.type != objectTypeMap) {
      write('${node.path} is not a map, cd into one first');
      return;
    }
    var name = (await prompt('Field name')).trim();
    if (name.isEmpty) {
      return;
    }
    var handler = await _promptType(state, 'Type of $name');
    if (handler == null) {
      return;
    }
    try {
      state.editor.addField(node.path, name, typeId: handler.id);
      _writeNode(state);
    } catch (e) {
      write('$e');
    }
  });
  item('add item', () async {
    var node = state.node;
    if (node.type != objectTypeList) {
      write('${node.path} is not a list, cd into one first');
      return;
    }
    var handler = await _promptType(state, 'Type of the new item');
    if (handler == null) {
      return;
    }
    state.editor.addItem(node.path, typeId: handler.id);
    _writeNode(state);
  });
  item('rename field', () async {
    var child = await _promptChild(state, 'Rename');
    if (child == null) {
      return;
    }
    if (child.key is! String) {
      write('A list item has no name');
      return;
    }
    var name = (await prompt('New name of ${child.name}')).trim();
    if (name.isEmpty) {
      return;
    }
    try {
      state.editor.renameField(child.path, name);
      _writeNode(state);
    } catch (e) {
      write('$e');
    }
  });
  item('remove', () async {
    var child = await _promptChild(state, 'Remove');
    if (child == null) {
      return;
    }
    state.editor.removeAt(child.path);
    _writeNode(state);
  });
  item('edit as text', () async {
    var node = state.node;
    var current = objectJsonFormat.encode(
      node.value,
      typeRegistry: state.editor.typeRegistry,
    );
    write('Current value:');
    write(current);
    var text = (await prompt('New value as json (empty to cancel)')).trim();
    if (text.isEmpty) {
      return;
    }
    try {
      var value = objectJsonFormat.decode(
        text,
        typeRegistry: state.editor.typeRegistry,
      );
      state.editor.setValueAt(node.path, value);
      _writeNode(state);
    } catch (e) {
      write('$e');
    }
  });
  if (externalEditorFilePath != null) {
    item('open in \$EDITOR', () async {
      await _runExternalEditor(externalEditorFilePath);
      await sourceEditor.load();
      state.path = ObjectPath.root;
      _writeNode(state);
    });
  }
  item('status', () {
    var editor = state.editor;
    write('${source.title} (${state.format.name})');
    write(
      editor.isDirty
          ? '${editor.operations.length} unsaved '
                '${editor.operations.length == 1 ? 'edit' : 'edits'}'
          : 'saved',
    );
    for (var operation in editor.operations) {
      write('- $operation');
    }
  });
  item('save', () async {
    if (source.isReadOnly) {
      write('${source.title} is read only');
      return;
    }
    if (!state.editor.isDirty) {
      write('nothing to save');
      return;
    }
    await sourceEditor.save();
    write('saved ${source.title}');
  });
  item('reload', () async {
    if (state.editor.isDirty) {
      var answer = await prompt('Drop the unsaved edits? (y/N)');
      if (answer.trim().toLowerCase() != 'y') {
        return;
      }
    }
    await sourceEditor.load();
    state.path = ObjectPath.root;
    _writeNode(state);
  });
}

/// Reads the json or yaml file named by the first argument of [arguments] and
/// runs the console editor on it.
///
/// The remaining arguments go to the menu, so `dart edit_json.dart my.json 0 .`
/// runs the first item and leaves. [defaultPath] is what an invocation with no
/// path argument edits; without one the tool writes its usage and stops.
///
/// [format] forces a format, otherwise the file extension names it (json by
/// default). [fileSystem] is `fileSystemIo` unless another one is given — a
/// memory one in a test.
Future<void> objectFileConsoleEditorMain(
  List<String> arguments, {
  ObjectTextFormat? format,
  String? defaultPath,
  FileSystem? fileSystem,
  String? usage,
}) async {
  var path = arguments.isNotEmpty && !arguments.first.startsWith('-')
      ? arguments.first
      : defaultPath;
  var menuArguments = arguments.isNotEmpty && !arguments.first.startsWith('-')
      ? arguments.sublist(1)
      : arguments;
  if (path == null) {
    write(usage ?? 'Usage: <tool> <file> [menu arguments]');
    return;
  }
  var source = objectFileSource(path, format: format, fileSystem: fileSystem);
  await objectSourceConsoleEdit(
    source,
    arguments: menuArguments,
    externalEditorFilePath: fileSystem == null ? path : null,
  );
}

void _writeNode(_ConsoleEditorState state) {
  var node = state.node;
  write('${node.path} ${node.type.id} ${node.display}');
  for (var child in node.children) {
    write('  ${child.name}: ${child.display} (${child.type.id})');
  }
  var editor = state.editor;
  if (editor.isDirty) {
    write('[${editor.operations.length} unsaved]');
  }
}

/// The children of the current node, plus the parent, as a one shot menu: the
/// list is declared when the menu is entered, so it is never a stale one.
Future<ObjectPath?> _promptNavigation(_ConsoleEditorState state) async {
  ObjectPath? selected;
  var node = state.node;
  var parent = node.path.parent;
  await showMenu(() {
    if (parent != null) {
      item('..', () async {
        selected = parent;
        await popMenu();
      });
    }
    for (var child in node.children.where((child) => child.isContainer)) {
      item('${child.name} ${child.display}', () async {
        selected = child.path;
        await popMenu();
      });
    }
  });
  return selected;
}

Future<ObjectNode?> _promptChild(
  _ConsoleEditorState state,
  String title,
) async {
  var node = state.node;
  if (node.children.isEmpty) {
    write(
      '${node.path} has no ${node.type == objectTypeList ? 'item' : 'field'}',
    );
    return null;
  }
  ObjectNode? selected;
  await showMenu(() {
    write(title);
    for (var child in node.children) {
      item('${child.name}: ${child.display} (${child.type.id})', () async {
        selected = child;
        await popMenu();
      });
    }
  });
  return selected;
}

Future<ObjectValueTypeHandler?> _promptType(
  _ConsoleEditorState state,
  String title,
) async {
  ObjectValueTypeHandler? selected;
  await showMenu(() {
    write(title);
    for (var handler in state.editor.typeRegistry.selectableHandlers) {
      item(handler.label, () async {
        selected = handler;
        await popMenu();
      });
    }
  });
  return selected;
}

Future<void> _editValue(_ConsoleEditorState state, ObjectNode child) async {
  if (child.isContainer) {
    state.path = child.path;
    _writeNode(state);
    return;
  }
  var type = child.type;
  if (type == objectTypeNull) {
    write('A null has no value, set its type first');
    return;
  }
  if (type == objectTypeBool) {
    state.editor.setValueAt(child.path, !(child.value as bool));
    _writeNode(state);
    return;
  }
  String current;
  try {
    current = type.toText(child.value);
  } catch (_) {
    current = child.display;
  }
  var text = await prompt('${child.name} (${type.id}) [$current]');
  if (text.isEmpty) {
    return;
  }
  try {
    state.editor.setValueAt(child.path, type.parseText(text));
    _writeNode(state);
  } catch (e) {
    write('$e');
  }
}

Future<void> _runExternalEditor(String path) async {
  var editor =
      platformEnvironment['EDITOR'] ?? platformEnvironment['VISUAL'] ?? 'nano';
  await Shell(verbose: false).run('$editor ${shellArgument(path)}');
}
