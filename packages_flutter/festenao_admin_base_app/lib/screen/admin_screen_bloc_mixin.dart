import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:tkcms_common/tkcms_audi.dart';

abstract class AdminAppProjectScreenBlocBase<T>
    extends AutoDisposeStateBaseBloc<T>
    with AdminScreenBlocMixin {
  @override
  final FestenaoAdminAppProjectContext projectContext;

  AdminAppProjectScreenBlocBase({required this.projectContext});
}

mixin AdminScreenBlocMixin implements AutoDispose {
  FestenaoAdminAppProjectContext get projectContext;
  late final dbBloc = audiAddDisposable(
    AdminAppProjectContextDbBloc(projectContext: projectContext),
  );

  Future<Database> get projectDb => dbBloc.grabDatabase();
}
