import 'package:festenao_base_app/form/src/view/app_scaffold.dart';
import 'package:flutter/material.dart';

import 'package:tekartik_app_navigator_flutter/page_route.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tkcms_user_app/view/body_container.dart';

class TextFieldParam {
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  FormFieldValidator<String>? validator;
  ValueChanged<String>? onFieldSubmitted;
  TextFieldParam({
    this.controller,
    this.decoration,
    this.keyboardType,
    this.validator,
    this.onFieldSubmitted,
  });
}

class TextFieldScreen extends StatefulWidget {
  final TextFieldParam param;
  const TextFieldScreen({super.key, required this.param});

  @override
  State<TextFieldScreen> createState() => _TextFieldScreenState();
}

class _TextFieldScreenState extends State<TextFieldScreen> {
  TextFieldParam get param => widget.param;
  final _focusNode = FocusNode();
  final formKey = GlobalKey<FormState>();

  void _validateAndClose(BuildContext context) {
    if (formKey.currentState!.validate()) {
      Navigator.of(context).pop();
      param.onFieldSubmitted?.call(param.controller!.text);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    sleep(1000).then((_) {
      _focusNode.requestFocus();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Form(
        key: formKey,
        child: ListView(
          children: [
            BodyContainer(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      focusNode: _focusNode,
                      controller: param.controller,
                      keyboardType: param.keyboardType,
                      validator: param.validator,
                      decoration: param.decoration,
                      onFieldSubmitted: (value) {
                        _validateAndClose(context);
                      },
                    ),
                    Row(
                      children: [
                        Expanded(child: Container()),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () {
                            _validateAndClose(context);
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showTextFieldScreen(
  BuildContext context,
  TextFieldParam param,
) async {
  FocusScope.of(context).unfocus();
  await Navigator.of(context).push(
    NoAnimationMaterialPageRoute<void>(
      builder: (_) => TextFieldScreen(param: param),
    ),
  );
}
