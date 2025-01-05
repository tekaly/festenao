import 'package:festenao_admin_base_app/screen/admin_image_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_common/app/app_options.dart';
import 'package:tekartik_app_prefs/app_prefs.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

/// Admin app options
class FestenaoAdminAppOptions {}

/// Our main options
var globalFestenaoAppOptions = festenaoAppOptionsDefault;
late String globalPackageName;

class AdminApp {
  // Set by caller
  late FirebaseContext fbContext;
  late Prefs prefs;

  // AppOptions? _options;

  // Can be set by caller
  //FestenaoAppOptions options = appOptionsDefault;
  //FestenaoImageAppOptions? imageOptions = appOptionsDefault.image.v;
  Future<void> Function(BuildContext context)? goToLoginScreen;

  Future<Prefs> openPrefs() async {
    var prefsFactory =
        getPrefsFactory(packageName: 'com.tekartik.festenao.admin');
    prefs = await prefsFactory.openPreferences('admin_prefs.db');
    return prefs;
  }

  ImageFormat get prefsImageFormat {
    var format = prefs.getString('imageFormat');
    return _reverseImageFormatMap[format] ?? ImageFormat.jpg;
  }

  set prefsImageFormat(ImageFormat format) =>
      prefs.setString('imageFormat', _imageFormatMap[format]);
}

var _imageFormatMap = <ImageFormat, String>{
  ImageFormat.jpg: 'jpg',
  ImageFormat.png: 'png',
};
var _reverseImageFormatMap =
    _imageFormatMap.map((key, value) => MapEntry(value, key));

final app = AdminApp();
AdminApp get gAdminApp => app;
