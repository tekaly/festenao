import 'package:flutter/material.dart';

class AppTextFieldTile extends StatelessWidget {
  final String labelText;
  final String? hintText;
  final TextEditingController? controller;
  final bool emptyAllowed;
  final int maxLines;
  final FormFieldValidator<String>? validator;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  const AppTextFieldTile(
      {super.key,
      required this.labelText,
      this.hintText,
      this.controller,
      this.maxLines = 1,
      this.emptyAllowed = false,
      this.validator,
      this.readOnly = false,
      this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        readOnly: readOnly,
        maxLines: maxLines,
        controller: controller,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          //icon: Icon(Icons.person),
          hintText: hintText,
          labelText: labelText,
        ),
        onSaved: (String? value) {
          // This optional block of code can be used to run
          // code when the user saves the form.
        },
        onChanged: onChanged,
        validator: validator ??
            (String? value) {
              if (emptyAllowed) {
                return null;
              }
              if (value?.isEmpty ?? true) {
                return 'Cannot be empty';
              }
              return null;
            },
      ),
    );
  }
}
