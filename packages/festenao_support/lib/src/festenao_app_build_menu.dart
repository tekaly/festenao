import 'package:festenao_support/festenao_build_menu_flutter.dart';

/// Adds a `web dev` menu entry exposing [builder]'s dev web app build/deploy
/// actions.
void menuFestenaoFirebaseAppBuilder({
  required FestenaoFirebaseAppBuilder builder,
}) {
  menu('web dev', () {
    menuFirebaseAppContent(
      builders: [builder.devWebAppBuilder, builder.prodWebAppBuilder],
    );
  });
}
