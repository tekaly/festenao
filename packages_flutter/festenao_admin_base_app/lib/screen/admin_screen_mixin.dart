import 'package:flutter/material.dart';

mixin AdminScreenMixin {
  void snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
