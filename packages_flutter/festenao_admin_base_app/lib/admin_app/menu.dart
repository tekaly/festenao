import 'package:festenao_admin_base_app/auth/auth.dart';
import 'package:festenao_admin_base_app/screen/booklets_screen.dart';
import 'package:festenao_admin_base_app/screen/fs_entity_list_screen.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tkcms_admin_app/screen/debug_screen.dart';

/// Festenao admin menu
final festenaoAdminDebugScreen = muiScreenWidget('Festenao debug', () {
  muiItem('Auth', () {
    goToAuthScreen(muiBuildContext);
  });
  muiItem('Entity', () {
    goToFsEntityListScreen(muiBuildContext);
  });
  muiItem('TKCms Debug', () {
    goToAdminDebugScreen(muiBuildContext);
  });
  muiItem('Booklets', () {
    goToBookletsScreen(muiBuildContext);
  });
});
