import 'package:festenao_admin_base_app/sembast/booklets_db.dart';
import 'package:flutter/material.dart';

/// Booklet leading
class BookletLeading extends StatelessWidget {
  /// Booklet leading
  final DbBooklet booklet;

  /// Booklet leading
  const BookletLeading({super.key, required this.booklet});

  @override
  Widget build(BuildContext context) {
    return booklet.uid.isNull
        ? const Icon(Icons.book)
        : const Icon(Icons.cloud);
  }
}
