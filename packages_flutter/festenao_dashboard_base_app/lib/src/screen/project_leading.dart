import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:material_ui/material_ui.dart';

/// Project leading
class ProjectLeading extends StatelessWidget {
  /// Project leading
  final SdbUserProject project;

  /// Project leading
  const ProjectLeading({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.cloud);
  }
}
