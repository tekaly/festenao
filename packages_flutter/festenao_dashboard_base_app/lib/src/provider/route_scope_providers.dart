/// The ids of the active project route, as scoped providers.
///
/// A screen below `/project/:project_id` (and below `.../data/:data_id`) reads
/// them from riverpod instead of taking them as constructor arguments: the
/// route tree wraps those branches in a `providerScopeShellRoute` that
/// overrides them from the path parameters — see `dashboard_route_scope.dart`.
///
/// Only these two providers are scoped. Everything derived from them stays a
/// plain family keyed by the ids (`blogEntriesProvider(projectId, dataId)`, …),
/// so no other provider has to declare a `dependencies` list: a screen reads
/// the ids from the scope, then watches the families with them.
library;

import 'package:festenao_dashboard_base_app/src/provider/sdb_db_providers.dart'
    show SdbProjectContent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The project id of the active route.
///
/// Reading it outside of a project branch throws on purpose: it means the
/// screen was mounted somewhere it does not belong, which is a wiring mistake
/// worth failing loudly on rather than rendering an empty project.
final currentProjectIdProvider = Provider<String>(
  (ref) => throw StateError(
    'currentProjectIdProvider is only readable below a project route. '
    'Wrap the branch in dashboardProjectScopeRoute (or override the provider '
    'in a ProviderScope) to make the project id available.',
  ),
  name: 'currentProjectId',
);

/// The data id of the active route.
///
/// Unlike the project id this one has a sensible default
/// ([SdbProjectContent.defaultDataId]), since most project screens work on the
/// main content database and only some branches (`data/:data_id`, the blog
/// demo) name another one.
final currentDataIdProvider = Provider<String>(
  (ref) => SdbProjectContent.defaultDataId,
  name: 'currentDataId',
);
