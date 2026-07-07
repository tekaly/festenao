import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Festenao server app for the Dart (admin sdk) cloud functions.
class FfApp extends FestenaoServerAppTest {
  /// Creates a new [FfApp] with the given [app] and [context].
  FfApp({required super.context, super.app}) {
    initFestenaoFsEntityApiBuilders<FsProject>();
    initFestenaoFsEntityApiBuilders<TkCmsFsApp>();
  }

  /// App (top entity) handler.
  late final appHandler = FestenaoEntityHandler(
    app: this,
    entityAccess: fsDatabase.appDb,
  );

  @override
  Future<ApiResult> onCommand(ApiRequest apiRequest) async {
    var result = await appHandler.onCommandOrNull(apiRequest);
    if (result != null) {
      return result;
    }

    return super.onCommand(apiRequest);
  }
}
