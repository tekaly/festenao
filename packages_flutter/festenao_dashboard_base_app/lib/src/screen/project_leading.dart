import 'package:festenao_admin_base_app/view/access_view.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_theme/kit.dart';
import 'package:material_ui/material_ui.dart';

/// The avatar of a project in a list: its initials, in a colour that stays
/// the same for the project ([adminAccessCategory] of its id).
class ProjectLeading extends StatelessWidget {
  /// The project.
  final SdbUserProject project;

  /// The diameter.
  final double size;

  /// The avatar of [project].
  const ProjectLeading({super.key, required this.project, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return FkAvatar(
      project.name.v ?? project.fsId,
      category: adminAccessCategory(project.fsId),
      size: size,
    );
  }
}
