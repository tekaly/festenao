import 'package:festenao_dashboard_base_app/src/screen/project_sdb_view_screen.dart';
import 'package:flutter/widgets.dart';

/// The access screen of one festenao project, `/project_access/:project_id`.
///
/// The dashboard manages the festenao project entity, which is what
/// [ProjectViewScreen] defaults to, so nothing has to be scoped here.
class DashboardProjectAccessScreen extends StatelessWidget {
  /// The route name.
  static const routeName = 'project_access';

  /// The route location.
  static const routeLocation = '/project_access/:project_id';

  /// The firestore project id.
  final String projectId;

  /// The access screen of the project [projectId].
  const DashboardProjectAccessScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) => ProjectViewScreen(entityId: projectId);
}
