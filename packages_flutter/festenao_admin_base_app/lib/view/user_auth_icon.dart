import 'package:festenao_admin_base_app/auth/auth.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';

class AppUserAuthIcon extends StatefulWidget {
  const AppUserAuthIcon({super.key});

  @override
  State<AppUserAuthIcon> createState() => _AppUserAuthIconState();
}

class _AppUserAuthIconState extends State<AppUserAuthIcon> {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        goToAuthScreen(context);
      },
      icon: const Icon(Icons.person),
    );
  }
}
