// compat
library;

import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
// export 'identity_info_tile.dart';

class IdentityNoneTile extends StatelessWidget {
  const IdentityNoneTile({super.key, this.onTap, required this.intl});

  final VoidCallback? onTap;
  final AppLocalizations intl;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: const Icon(Icons.warning),
      title: Text(intl.notSignedInInfo),
    );
  }
}
