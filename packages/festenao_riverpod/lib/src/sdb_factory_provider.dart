import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tekartik_common_utils/env_utils.dart';

import 'app_flavor_context_provider.dart';

part 'sdb_factory_provider.g.dart';

/// The app [SdbFactory].
///
/// Defaults to [sdbFactoryWeb] on the web and [sdbFactorySqflite] otherwise,
/// sandboxed under the current [FestenaoAppFlavorContext]'s unique app name
/// sub path. Override to provide an in-memory factory in tests.
@riverpod
SdbFactory festenaoSdbFactory(Ref ref) {
  var appFlavorContext = ref.watch(festenaoAppFlavorContextProvider);
  var factory = kDartIsWeb ? sdbFactoryWeb : sdbFactorySqflite;
  return factory.sandbox(path: appFlavorContext.appFlavorContext.uniqueAppName);
}
