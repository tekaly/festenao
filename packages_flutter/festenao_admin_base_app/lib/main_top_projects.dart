import 'package:festenao_admin_base_app/run.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_common/app/app_options.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_flavor.dart';

final _topProjectCollectionInfo = fsProjectCollectionInfo.copyWith(
  id: 'top_project',
  name: 'Top Project',
);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Top projects only
  var options = FestenaoAppOptions(
    multiProjects: FestenaoAppMultiProjectsOptions(
      projectCollectionRef: _topProjectCollectionInfo.ref(),
    ),
  );
  gDebugLogFirestore = true;
  await festenaoRunAdminApp(
    options: options,
    appFlavorContext: FlavorContext.dev.toAppFlavorContext(
      appId: 'festenao_top_projects',
    ),
  );
}
