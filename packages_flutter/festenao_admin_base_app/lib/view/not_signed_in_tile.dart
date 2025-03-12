import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:tkcms_common/tkcms_auth.dart';

class IdentityWarningTile extends StatelessWidget {
  const IdentityWarningTile({super.key});

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);

    return ListTile(
      leading: const Icon(Icons.warning),
      title: Text(intl.notSignedInInfo),
    );
  }
}

class IdentityInfoTile extends StatelessWidget {
  const IdentityInfoTile({super.key});

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
              leading: const Icon(Icons.api),
              title: const Text('Service account'),
              subtitle: projectId == null ? null : Text(projectId),
            );
          } else {
            return ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Unknown identity'),
              subtitle: Text(identity.toString()),
            );
          }
        } else {
          return ListTile(
            leading: const Icon(Icons.warning),
            title: Text(intl.notSignedInInfo),
          );
        }
      },
    );
  }
}
