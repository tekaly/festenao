import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'auth_rpd.g.dart';

@riverpod
/// A boolean that indicates whether RPD authentication is enabled.
/// Defaults to false.
bool rpdHasAuth(Ref ref) {
  return false;
}

/// Identity state
@Riverpod(keepAlive: true)
Stream<TkCmsFbIdentityBlocState> rpdTkCmsFbIdentityBlocState(Ref ref) {
  return globalTkCmsFbIdentityBloc.state;
}
