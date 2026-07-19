import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

part 'app_provider.g.dart';

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
}

/// A global provider of [FestenaoAppFlavorContext].
///
/// Must be overridden in the app.
@riverpod
FestenaoAppFlavorContext festenaoAppFlavorContext(Ref ref) {
  throw UnimplementedError('festenaoAppFlavorContext must be overridden');
}
