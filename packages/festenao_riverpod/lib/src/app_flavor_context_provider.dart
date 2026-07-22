import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

part 'app_flavor_context_provider.g.dart';

/// Context containing both the app package name and the app flavor context.
class FestenaoAppFlavorContext {
  /// The app package name.
  final String packageName;

  /// The app flavor context.
  final AppFlavorContext appFlavorContext;

  /// Constructor.
  FestenaoAppFlavorContext({
    required this.packageName,
    required this.appFlavorContext,
  });
}

/// A global provider of [FestenaoAppFlavorContext].
///
/// Must be overridden by the app.
@riverpod
FestenaoAppFlavorContext festenaoAppFlavorContext(Ref ref) {
  throw UnimplementedError('festenaoAppFlavorContext must be overridden');
}
