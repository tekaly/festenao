import 'package:festenao_common/data/object_editor.dart';
import 'package:flutter/material.dart';

/// A new field: its name and the type it starts with.
class ObjectEditorNewField {
  /// The name of the field.
  final String name;

  /// The id of the type it takes.
  final String typeId;

  /// Field [name] of type [typeId].
  ObjectEditorNewField({required this.name, required this.typeId});
}

/// Asks for a line of text, answering null when the dialog is dismissed.
Future<String?> objectEditorPromptText(
  BuildContext context, {
  required String title,
  String? initialValue,
  String? labelText,
}) {
  var controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Ok'),
        ),
      ],
    ),
  );
}

/// Asks which type a value takes, answering null when the dialog is dismissed.
Future<ObjectValueTypeHandler?> objectEditorPromptType(
  BuildContext context,
  ObjectTypeRegistry typeRegistry, {
  String title = 'Type',
  ObjectValueTypeHandler? current,
}) => showDialog<ObjectValueTypeHandler>(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text(title),
    children: [
      for (var handler in typeRegistry.selectableHandlers)
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(handler),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: handler.id == current?.id
                    ? const Icon(Icons.check, size: 18)
                    : null,
              ),
              Text(handler.label),
            ],
          ),
        ),
    ],
  ),
);

/// Asks for the name and the type of a new map field.
///
/// [names] are offered first, as the fields a model declares that the map does
/// not hold yet; picking one takes the type [schema] gives it when it has one.
Future<ObjectEditorNewField?> objectEditorPromptNewField(
  BuildContext context,
  ObjectTypeRegistry typeRegistry, {
  List<String>? names,
  CvObjectSchema? schema,
}) async {
  String? name;
  if (names != null && names.isNotEmpty) {
    name = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add field'),
        children: [
          for (var known in names)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(known),
              child: Text(known),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Other…'),
          ),
        ],
      ),
    );
    if (name == null) {
      return null;
    }
  }
  if (!context.mounted) {
    return null;
  }
  if (name == null || name.isEmpty) {
    name = await objectEditorPromptText(
      context,
      title: 'Add field',
      labelText: 'Field name',
    );
    if (name == null || name.isEmpty) {
      return null;
    }
  }
  var knownTypeId = schema?.field(name)?.typeId;
  if (knownTypeId != null && typeRegistry.handler(knownTypeId) != null) {
    return ObjectEditorNewField(name: name, typeId: knownTypeId);
  }
  if (!context.mounted) {
    return null;
  }
  var type = await objectEditorPromptType(
    context,
    typeRegistry,
    title: 'Type of $name',
  );
  if (type == null) {
    return null;
  }
  return ObjectEditorNewField(name: name, typeId: type.id);
}

/// Asks to confirm, answering false when the dialog is dismissed.
Future<bool> objectEditorPromptConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmText = 'Ok',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    ) ??
    false;
