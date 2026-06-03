import 'package:festenao_admin_base_app/run.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_common/firebase/firebase_sim.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var appFlavorContext = AppFlavorContext.testLocal;
  var firebaseContext = await festenaoInitFirebaseSim();
  await festenaoRunAdminApp(
    firebaseContext: firebaseContext,
    appFlavorContext: appFlavorContext,
  );
}
