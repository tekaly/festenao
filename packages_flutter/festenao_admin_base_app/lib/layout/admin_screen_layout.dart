import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';
import 'package:flutter/material.dart';

import 'adaptive.dart';
import 'drawer.dart';

class AdminScreenLayout extends StatefulWidget {
  final AppBar? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final ValueNotifier<bool>? waiting;
  final bool useDrawer;
  const AdminScreenLayout(
      {super.key,
      this.appBar,
      this.useDrawer = false,
      this.body,
      this.floatingActionButton,
      this.waiting});

  @override
  State<AdminScreenLayout> createState() => _AdminScreenLayoutState();
}

class _AdminScreenLayoutState extends State<AdminScreenLayout> {
  @override
  Widget build(BuildContext context) {
    final isDesktop = isDisplayDesktop(context);
    if (isDesktop) {
      return Row(
        children: [
          const ListDrawer(),
          Expanded(
            child: FestenaoAdminAppScaffold(
              appBar: widget.appBar,
              body: widget.body,
              floatingActionButton: widget.floatingActionButton,
            ),
          )
        ],
      );
    }
    return FestenaoAdminAppScaffold(
      drawer: (widget.useDrawer && !isDesktop) ? const ListDrawer() : null,
      appBar: widget.appBar,
      body: widget.body,
      floatingActionButton: widget.floatingActionButton,
    );
  }
}
