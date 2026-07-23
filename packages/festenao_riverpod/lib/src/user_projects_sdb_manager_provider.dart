import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_projects_sdb_manager_provider.g.dart';

/// The app [UserProjectsSdbManager].
///
/// Must be overridden by the app.
@riverpod
UserProjectsSdbManager festenaoUserProjectsSdbManager(Ref ref) {
  throw UnimplementedError('festenaoUserProjectsSdbManager must be overridden');
}
