/// Route path-parameter names shared by the dashboard content screens.
///
/// The full [GoRouter] tree itself stays app-specific; only these constants are
/// shared so the reusable content screens can build/read their routes.
class DashboardRouter {
  /// `project/:project_id`
  static const projectLocationPathPart = 'project/:$projectIdParam';

  /// `data/:data_id`
  static const dataPath = 'data/:$dataIdParam';

  /// `image/:image_id`
  static const imagePath = 'image/:${DashboardRouter.imageIdParam}';

  /// Project id path parameter name.
  static const projectIdParam = 'project_id';

  /// Data id path parameter name.
  static const dataIdParam = 'data_id';

  /// Image id path parameter name.
  static const imageIdParam = 'image_id';
}
