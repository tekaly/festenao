import 'package:festenao_common/festenao_flavor.dart';

/// Context containing both package name and app flavor context
class FestenaoAppFlavorContext {
  /// The app package name
  final String packageName;

  /// The app flavor context
  final AppFlavorContext appFlavorContext;

  /// Constructor
  FestenaoAppFlavorContext({
    required this.packageName,
    required this.appFlavorContext,
  });

  /// No separator package name xx.yy => xx.yy or xx.yydev
  FestenaoAppFlavorContext.base({
    required String basePackageName,
    required this.appFlavorContext,
  }) : packageName =
           '$basePackageName${appFlavorContext.flavorContext.ifNotProdFlavor}';

  /// App id (`app/<appId>`) in firestore
  String get appId => appFlavorContext.appId;
}
