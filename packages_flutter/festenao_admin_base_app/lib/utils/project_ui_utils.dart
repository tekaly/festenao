import 'package:flutter/material.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_admin_app/l10n/app_localizations.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

String? accessString(AppLocalizations intl, TkCmsCvUserAccessCommon access) {
  return access.isAdmin
      ? intl.projectAccessAdmin
      : (access.isWrite
          ? intl.projectAccessWrite
          : (access.isRead ? intl.projectAccessRead : null));
}

Text? accessText(AppLocalizations intl, TkCmsCvUserAccessCommon access) {
  var text = accessString(intl, access);
  if (text == null) {
    return null;
  }
  return Text(text);
}

String truncateTitle(String title) {
  return title.truncate(80);
}

String truncateDescription(String description) {
  return description.truncate(256);
}
