/// Puts the project and data ids of a location into riverpod, so the screens
/// below can read them from [currentProjectIdProvider] /
/// [currentDataIdProvider] instead of receiving them as constructor arguments.
///
/// The scope is a plain [ProviderScope] built by the route, **not** a
/// [ShellRoute]: a shell owns a nested [Navigator], so two routes sitting in
/// two different shells (the project home of the content module and the blog
/// demo of the demo module, say) end up in two different navigators — pushing
/// from one to the other then lands on an empty stack, with no back button and
/// nothing to pop. Wrapping each route's widget keeps every page on the same
/// navigator, so `push`/`pop` behave exactly as before.
///
/// Scoping per page rather than per branch costs nothing here: the scope only
/// carries two ids, there is no state to share between the pages of a branch.
library;

import 'package:festenao_dashboard_base_app/src/provider/route_scope_providers.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_router.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds [child] in a scope where [currentProjectIdProvider] is the
/// `project_id` of [state].
///
/// [currentDataIdProvider] is overridden too when the location carries a
/// `data_id`, or when [dataId] is given — for the branches whose data id is
/// fixed rather than part of the location (the blog demo works on the `blog`
/// database, whatever the url says). Otherwise it keeps its default.
Widget dashboardProjectScope(
  GoRouterState state, {
  required Widget child,
  String? dataId,
}) {
  var scopedDataId =
      dataId ?? state.pathParameterOrNull(DashboardRouter.dataIdParam);
  return ProviderScope(
    overrides: [
      currentProjectIdProvider.overrideWithValue(
        state.pathParameter(DashboardRouter.projectIdParam),
      ),
      if (scopedDataId != null)
        currentDataIdProvider.overrideWithValue(scopedDataId),
    ],
    child: child,
  );
}
