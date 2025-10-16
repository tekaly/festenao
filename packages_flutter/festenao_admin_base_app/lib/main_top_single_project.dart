import 'package:festenao_admin_base_app/run.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_common/app/app_options.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_flavor.dart';

final _topProjectCollectionInfo = fsProjectCollectionInfo.copyWith(
  id: 'top_project',
  name: 'Top Project',
);
var _topProjectCollectionRef = _topProjectCollectionInfo.ref();
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Top projects only
  var options = FestenaoAppOptions(
    singleProject: FestenaoAppSingleProjectOptions(
      projectCollectionRef: _topProjectCollectionRef,
      projectId: 'singleQH8VoZRZf4A56hknguH4',
    ),
  );
  await festenaoRunAdminApp(
    packageName: 'festenao_admin_base_app.lib.main_top_single_project',
    options: options,
    appFlavorContext: FlavorContext.dev.toAppFlavorContext(
      appId: 'festenao_top_single_project',
    ),
  );
}
