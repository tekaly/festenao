import 'package:flutter/material.dart';

/// A [StatelessWidget] that wraps a [Scaffold] and provides an optional
/// floating action button for a parent action.
class ScaffoldWithParentAction extends StatelessWidget {
  /// Callback to be invoked when the parent action button is pressed.
  final VoidCallback? parentAction;

  /// The main content of the scaffold.
  final Widget? body;

  /// The app bar to display at the top of the scaffold.
  final AppBar? appBar;

  /// Creates a [ScaffoldWithParentAction].
  ///
  /// [parentAction] is the callback for the floating action button.
  /// [body] is the main content widget.
  /// [appBar] is the optional app bar.
  const ScaffoldWithParentAction({
    super.key,
    this.body,
    this.parentAction,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: parentAction == null
          ? null
          : FloatingActionButton(
              heroTag: UniqueKey(), // 'festenao_back_to_admin',
              onPressed: () {
                parentAction!();
              },
              child: const Icon(Icons.arrow_back),
            ),
    );
  }
}
