import 'package:festenao_admin_base_app/sembast/projects_db.dart';
import 'package:flutter/material.dart';

/// Project leading
class ProjectLeading extends StatelessWidget {
  /// Project leading
  final DbProject project;

  /// Project leading
  const ProjectLeading({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return project.uid.isNull
        ? const Icon(Icons.book)
        : const Icon(Icons.cloud);
  }
}
