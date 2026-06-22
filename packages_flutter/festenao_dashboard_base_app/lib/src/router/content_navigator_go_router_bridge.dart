import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:tekartik_app_flutter_bloc/bloc_provider.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';

/// Bridges the [ContentNavigatorBloc] world (festenao_admin_base_app screens)
/// onto a go_router [GoRouter] instance.
///
/// The [router] is supplied by the host app so this widget stays decoupled
/// from any particular router provider.
class ContentNavigatorGoRouterBridge extends StatelessWidget {
  final Widget child;
  final GoRouter router;

  const ContentNavigatorGoRouterBridge({
    super.key,
    required this.child,
    required this.router,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ContentNavigatorBloc>(
      blocBuilder: () =>
          ContentNavigatorGoRouterBridgeBloc(context, router: router),
      child: child,
    );
  }
}

/// Special instance of content navigator to use go router instead
class ContentNavigatorGoRouterBridgeBloc extends ContentNavigatorBloc {
  final GoRouter router;
  final BuildContext context;

  ContentNavigatorGoRouterBridgeBloc(this.context, {required this.router});

  @override
  Future<T?> push<T>(
    ContentPathRouteSettings rs, {
    TransitionDelegate? transitionDelegate,
  }) async {
    var path = rs.path.toPathString();
    return router.push<T>(path, extra: rs.arguments);
  }

  @override
  void transientPop(BuildContext context, [Object? result]) {
    router.pop(result);
  }

  @override
  void popUntilPathOrPush(
    BuildContext context,
    ContentPath path, {
    TransitionDelegate? transitionDelegate,
  }) {
    router.go(path.toPathString());
  }

  @override
  void popToRoot(BuildContext context) {
    router.go('/');
  }

  @override
  void transientPopUntilPath(BuildContext context, ContentPath path) {
    router.go(path.toPathString());
  }
}
