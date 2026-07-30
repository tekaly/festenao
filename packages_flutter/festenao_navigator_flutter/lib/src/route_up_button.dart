import 'package:flutter/material.dart';

import 'navigator_ext.dart';
import 'route_path.dart';

/// A leading app bar button that pops when there is something to pop, and goes
/// up one level otherwise.
///
/// A [Scaffold] only shows its automatic back button when the navigator can
/// pop, so a screen reached by a deep link offers no way out at all: opening
/// `/project/x/blog_demo` in a fresh tab matches that one route, and go_router
/// builds no parent page (it never synthesises a stack from the url
/// hierarchy). Give such a screen this button as its app bar `leading` and it
/// always has an exit: the usual pop when it was pushed, [upPath] when it was
/// not.
///
/// ```dart
/// AppBar(
///   leading: RouteUpBackButton(upPath: dashboardProjectPath),
///   title: Text('Blog'),
/// )
/// ```
class RouteUpBackButton extends StatelessWidget {
  /// Where "up" goes when there is nothing to pop.
  ///
  /// Its missing path parameters are inherited from the active location, so
  /// the parent of `/project/x/blog_demo` is simply `/project/:project_id`.
  /// Null means "drop [upCount] segments of the current location" instead.
  final RoutePathDef? upPath;

  /// Segments dropped when [upPath] is null.
  final int upCount;

  /// Creates an up/back button going to [upPath] (or [upCount] segments up)
  /// when the stack is empty.
  const RouteUpBackButton({super.key, this.upPath, this.upCount = 1});

  @override
  Widget build(BuildContext context) {
    return BackButton(
      onPressed: () {
        var upPath = this.upPath;
        if (upPath != null) {
          context.popOrGoPath(upPath);
        } else {
          context.popOrGoUp(upCount);
        }
      },
    );
  }
}
