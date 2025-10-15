import 'package:festenao_admin_base_app/auth/app_auth_bloc.dart';
import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/utils/project_ui_utils.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_common/tkcms_auth.dart';

import 'not_signed_in_tile.dart';

class AppIdentityWarningTile extends StatelessWidget {
  const AppIdentityWarningTile({super.key});

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);

    return ListTile(
      leading: const Icon(Icons.warning),
      title: Text(intl.notSignedInInfo),
    );
  }
}

class AppIdentityInfoTile extends StatelessWidget {
  final VoidCallback? onTap;
  const AppIdentityInfoTile({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);

    return ValueStreamBuilder(
      stream: globalFestenaoAppAuthBloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        if (state == null) {
          return Container();
        }
        if (state.identity != null) {
          var identity = state.identity as TkCmsFbIdentity;
          var accessText = accessString(
            intl,
            state.userAccess ?? TkCmsCvUserAccess(),
          ).trimmedNonEmpty();
          if (identity is TkCmsFbIdentityUser) {
            return ListTile(
              onTap: onTap,
              leading: const Icon(Icons.person),
              title: Text(
                identity.user.email ??
                    identity.user.displayName ??
                    identity.user.uid,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(identity.user.uid),
                  if (accessText != null) Text(accessText),
                ],
              ),
            );
          } else if (identity is TkCmsFbIdentityServiceAccount) {
            var projectId = identity.projectId;
            return ListTile(
              onTap: onTap,
              leading: const Icon(Icons.api),
              title: const Text('Service account'),
              subtitle: projectId == null ? null : Text(projectId),
            );
          } else {
            return ListTile(
              leading: const Icon(Icons.person),
              onTap: onTap,
              title: const Text('Unknown identity'),
              subtitle: Text(identity.toString()),
            );
          }
        } else {
          return IdentityNoneTile(onTap: onTap, intl: intl);
        }
      },
    );
  }
}
