import 'package:material_ui/material_ui.dart';

/// Set to true for app debugging from admin data
var debugAdminGoToNormalAppOnStart = false;

/// To set for debug.
Future<void> Function(BuildContext context)? debugOnAdminRootScreenReady;
