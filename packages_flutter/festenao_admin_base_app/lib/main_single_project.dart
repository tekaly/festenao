import 'package:festenao_admin_base_app/screen/screen_import.dart';

import 'main_local.dart';

/// Single project id
const _singleProjectId = 'singleQH8VoZRZf4A56hknguH4';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await localFestenaoRunAdminApp(singleProjectId: _singleProjectId);
}
