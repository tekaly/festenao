import 'package:festenao_admin_base_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

String accessString(AppLocalizations intl, TkCmsCvUserAccessCommon access) {
  var text = _accessString(intl, access);
  var role = access.role.v?.trimmedNonEmpty();
  if (role != null) {
    return '$text ($role)';
  }
  return text;
}

String _accessString(AppLocalizations intl, TkCmsCvUserAccessCommon access) {
  return access.isAdmin
      ? intl.projectAccessAdmin
      : (access.isWrite
          ? intl.projectAccessWrite
          : (access.isRead ? intl.projectAccessRead : 'No access'));
}

Text? accessText(AppLocalizations intl, TkCmsCvUserAccessCommon access) {
  var text = accessString(intl, access);
  return Text(text);
}

String truncateTitle(String title) {
  return title.truncate(80);
}

String truncateDescription(String description) {
  return description.truncate(256);
}
