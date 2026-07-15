import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_support/festenao_build_menu_flutter.dart';

/// Firebase project/hosting naming options shared by a Festenao app's
/// flavors.
class FestenaoFirebaseAppBuildOptions {
  /// Firebase project id.
  final String projectId;

  /// Hosting id for the `prod` flavor; other flavors append `-<flavor>`.
  final String baseHostingId; // -<flavor> appended if non prod

  /// Constructor.
  const FestenaoFirebaseAppBuildOptions({
    required this.projectId,
    required this.baseHostingId,
  });
}

/// Builds and deploys a Festenao Firebase-hosted Flutter web app.
class FestenaoFirebaseAppBuilder {
  /// Path to the Flutter app.
  final String path;

  /// Web build options, shared by every flavor.
  final webAppBuildOptions = FlutterWebAppBuildOptions(wasm: true);

  /// Project/hosting naming options.
  final FestenaoFirebaseAppBuildOptions options;

  /// Hosting id for [flavor].
  String _flavorHostingId(FlavorContext flavor) =>
      '${options.baseHostingId}${flavor.ifNotProdHostingIdSuffix}';

  /// Constructor.
  FestenaoFirebaseAppBuilder({required this.options, required this.path});

  FirebaseDeployOptions _flavorDeployOptions(FlavorContext flavor) =>
      FirebaseDeployOptions(
        projectId: options.projectId,
        hostingId: _flavorHostingId(flavor),
        target: flavor.flavor,
      );

  FlutterFirebaseWebAppOptions _flavorWebAppOptions(FlavorContext flavor) =>
      FlutterFirebaseWebAppOptions(
        buildOptions: webAppBuildOptions,
        path: path,
        deployOptions: _flavorDeployOptions(flavor),
      );
  FlutterFirebaseWebAppBuilder _flavorWebAppBuilder(FlavorContext flavor) {
    return FlutterFirebaseWebAppBuilder(options: _flavorWebAppOptions(flavor));
  }

  /// Prod flavor deploy options.
  late final prodWebAppBuilder = _flavorWebAppBuilder(FlavorContext.prod);

  /// Dev flavor deploy options.
  late final devWebAppBuilder = _flavorWebAppBuilder(FlavorContext.dev);
}

/// Per-flavor build options for a [FestenaoFirebaseAppBuildOptions] app.
class FestenaoFirebaseAppFlavorBuildOptions {
  /// The parent app options.
  final FestenaoFirebaseAppBuildOptions appOptions;

  /// The flavor (e.g. `dev`, `prod`).
  final String? flavor;

  /// Constructor.
  FestenaoFirebaseAppFlavorBuildOptions({
    required this.appOptions,
    required this.flavor,
  });
}
