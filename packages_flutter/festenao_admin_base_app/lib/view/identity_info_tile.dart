import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/not_signed_in_tile.dart';
import 'package:tkcms_common/tkcms_auth.dart';

class IdentityWarningTile extends StatelessWidget {
  const IdentityWarningTile({super.key});

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    return IdentityNoneTile(intl: intl);
  }
}

class IdentityInfoTile extends StatelessWidget {
  final VoidCallback? onTap;
  const IdentityInfoTile({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);

    return ValueStreamBuilder(
      stream: globalTkCmsFbIdentityBloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        if (state == null) {
          return Container();
        }
        if (state.identity != null) {
          var identity = state.identity as TkCmsFbIdentity;
          if (identity is TkCmsFbIdentityUser) {
            return ListTile(
              onTap: onTap,
              leading: const Icon(Icons.person),
              title: Text(
                identity.user.email ??
                    identity.user.displayName ??
                    identity.user.uid,
              ),
              subtitle: Text(identity.user.uid),
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
