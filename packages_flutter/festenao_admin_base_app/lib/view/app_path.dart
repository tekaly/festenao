import 'package:festenao_admin_base_app/screen/screen_import.dart';

class AppPathWidget extends StatelessWidget {
  final String appPath;
  const AppPathWidget({super.key, required this.appPath});

  @override
  Widget build(BuildContext context) {
    return Text(appPath, style: TextTheme.of(context).labelMedium);
  }
}

class AppPathTile extends StatelessWidget {
  final String appPath;
  const AppPathTile({super.key, required this.appPath});

  @override
  Widget build(BuildContext context) {
    return ListTile(title: AppPathWidget(appPath: appPath));
  }
}
