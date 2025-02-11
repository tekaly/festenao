import 'package:festenao_admin_base_app/screen/screen_import.dart';

mixin AdminScreenMixin {
  void snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

abstract class AdminAppProjectScreenState {
  FestenaoAdminAppProjectContext get projectContext;
  AdminAppProjectContextDbBloc get dbBloc;
}

mixin AdminAppProjectScreenStateMixin implements AdminAppProjectScreenState {
  @override
  FestenaoAdminAppProjectContext get projectContext => dbBloc.projectContext;
}
