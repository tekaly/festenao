import 'package:festenao_common/festenao_flavor.dart';
import 'package:flutter/foundation.dart';
export 'package:festenao_common/festenao_flavor.dart';

/// Default flavor context, either base or uri for the web or dev by default
final festenaoFlavorContextDefault = kIsWeb
    ? tkCmsFlavorContextFromUri(Uri.base)
    : (kDebugMode ? FlavorContext.dev : FlavorContext.prod);
