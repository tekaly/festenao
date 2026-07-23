import 'package:festenao_common/festenao_flavor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_flavor_context_provider.g.dart';

/// A global provider of [FestenaoAppFlavorContext].
///
/// Must be overridden by the app.
@riverpod
FestenaoAppFlavorContext festenaoAppFlavorContext(Ref ref) {
  throw UnimplementedError('festenaoAppFlavorContext must be overridden');
}
