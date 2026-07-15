import 'package:flutter/material.dart';

import 'kiosk_settings_screen.dart';

/// Route path for [FestenaoKioskSettingsScreen]. Reuse this constant when
/// registering the screen with your own router (`MaterialApp.routes`,
/// go_router's `GoRoute.path`, ...).
const festenaoKioskSettingsRoute = '/kiosk-settings';

/// Ready-to-use route table for `MaterialApp(routes: ...)` /
/// `MaterialApp.router` with a `RouteInformationParser` that consults a
/// plain route map. Merge it into your own routes map, or use
/// [festenaoKioskSettingsRoute] directly with any other router (including
/// go_router) — festenao_kiosk has no router dependency itself.
final Map<String, WidgetBuilder> festenaoKioskRoutes = {
  festenaoKioskSettingsRoute: (context) => const FestenaoKioskSettingsScreen(),
};
