import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tekartik_firebase_ui_auth/ui_auth.dart';
import 'package:tkcms_admin_app/l10n/app_localizations.dart' as tkcms;

import 'app_localizations.dart';

export 'app_localizations.dart';

AppLocalizations festenaoAdminAppIntl(BuildContext context) =>
    AppLocalizations.of(context)!;

const festenaoAdminAppAllLocalizationsDelegates = [
  FirebaseUiAuthServiceBasicLocalizations.delegate,
  AppLocalizations.delegate,
  tkcms.AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
const festenaoAdminAppSupportedLocales = AppLocalizations.supportedLocales;
