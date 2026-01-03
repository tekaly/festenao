import 'package:flutter/material.dart';

// reused but never disposed
var _textFieldController = TextEditingController();

/// Show a dialog to get a string
///
/// returns null on cancel
Future<String?> festenaoGetString(
  BuildContext context, {

  /// initial value
  String? value,
  String? title,
  FormFieldValidator<String>? validator,
  String? hint,
}) async {
  _textFieldController.dispose();
  _textFieldController = TextEditingController(text: value);
  return await showDialog<String>(
    context: context,
    builder: (context) {
      final formKey = GlobalKey<FormState>();
      var intl = MaterialLocalizations.of(context);
      return AlertDialog(
        title: (title != null) ? Text(title) : null,
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: _textFieldController,
            decoration: InputDecoration(hintText: hint),
            validator: validator,
          ),
        ),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () {
              () async {
                formKey.currentState!.save();
                if (formKey.currentState!.validate()) {
                  var text = _textFieldController.text;
                  Navigator.of(context).pop(text);
                }
              }();
            },
            child: Text(intl.okButtonLabel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(intl.cancelButtonLabel),
          ),
        ],
      );
    },
  );
}
