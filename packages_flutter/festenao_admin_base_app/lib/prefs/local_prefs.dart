import 'package:tekartik_app_prefs/app_prefs.dart';

late Prefs globalPrefs;

extension FestenaoPrefsExt on Prefs {
  String? get currentProjectId => getString('currentProjectId');
  set currentProjectId(String? value) => setString('currentProjectId', value);
}
