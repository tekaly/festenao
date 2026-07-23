import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'user_projects_sdb_manager_provider.dart';

part 'user_projects_sdb_provider.g.dart';

/// The current per user [UserProjectsSdb], null until
/// [festenaoUserProjectsSdbManagerProvider] has one (i.e. until
/// [UserProjectsSdbManager.setCurrentUser] has been called).
///
/// Follows [UserProjectsSdbManager.onCurrentDb].
@riverpod
Stream<UserProjectsSdb?> festenaoUserProjectsSdb(Ref ref) {
  var manager = ref.watch(festenaoUserProjectsSdbManagerProvider);
  return manager.onCurrentDb;
}
