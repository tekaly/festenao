import 'dart:math';

import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  const AppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        //print('constraints: $constraints');
        Widget scaffold() {
          return Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: appBar,
            body: body,
            floatingActionButton: floatingActionButton,
          );
        }

        if (constraints.maxWidth > 640 || constraints.maxHeight > 840) {
          return Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              width: min(600, constraints.maxWidth),
              height: min(800, constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: scaffold(),
              ),
            ),
          );
        }
        return scaffold();
      },
    );
  }
}
