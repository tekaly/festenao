import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';

/// The debug items every dashboard app gets, the ones that need nothing of the
/// app itself.
///
/// Declare them in the debug screen of an app, beside its own:
///
/// ```dart
/// muiBodyWidget(() {
///   dashboardDebugMenuContent(packageName: 'com.example.my_app');
///   muiItem('My own debug thing', () { ... });
/// });
/// ```
///
/// Currently: the file system explorer, which browses a directory picked among
/// the ones `path_provider` names and opens the json, yaml and database files
/// it finds.
void dashboardDebugMenuContent({String? packageName}) {
  festenaoFileSystemExplorerMenuItem(packageName: packageName);
}

/// A debug screen holding [dashboardDebugMenuContent], for an app that has
/// nothing of its own to add.
class DashboardDebugScreen extends StatelessWidget {
  /// Names the directory of the app on linux and windows.
  final String? packageName;

  /// The title of the screen.
  final String title;

  /// Debug screen of the app.
  const DashboardDebugScreen({
    super.key,
    this.packageName,
    this.title = 'Debug',
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: muiBodyWidget(() {
      dashboardDebugMenuContent(packageName: packageName);
    }),
  );
}

/// Pushes a [DashboardDebugScreen].
Future<void> goToDashboardDebugScreen(
  BuildContext context, {
  String? packageName,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => DashboardDebugScreen(packageName: packageName),
  ),
);
