import 'package:festenao_admin_base_app/screen/fs_app_user_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';

import 'package:tekartik_app_flutter_widget/app_widget.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';

import '../view/app_path.dart';
import 'project_root_user_edit_screen.dart';

class AppUserEditResult {
  final bool modified;

  AppUserEditResult({required this.modified});
}

class AppUserEditScreen extends StatefulWidget {
  const AppUserEditScreen({super.key});

  @override
  State<AppUserEditScreen> createState() => _AppUserEditScreenState();
}

class _AppUserEditScreenState extends AutoDisposeBaseState<AppUserEditScreen>
    with AdminUserEditScreenMixin {
  var _initialized = false;

  var formKey = GlobalKey<FormState>();

  FsAppUserEditScreenBloc get bloc =>
      BlocProvider.of<FsAppUserEditScreenBloc>(context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;

    return FestenaoAdminAppScaffold(
      appBar: AppBar(title: const Text('User')),
      body: ValueStreamBuilder<FsAppUserEditScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return const CenteredProgress();
          }
          var userId = bloc.param.userId;
          var user = snapshot.data!.user;

          if (!_initialized) {
            _initialized = true;
            initControllers(userId: userId, user: user);
          }

          return Stack(
            children: [
              Form(
                key: formKey,
                child: ListView(
                  children: [
                    const SizedBox(height: 16),
                    AppPathTile(appPath: bloc.appPath),
                    buildDataWidget(context),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: ValueStreamBuilder(
        stream: bloc.state,
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return Container();
          }
          return FloatingActionButton(
            onPressed: () {
              _onSave(context);
            },
            child: const Icon(Icons.save),
          );
        },
      ),
    );
  }

  Future _onSave(BuildContext context) async {
    formKey.currentState!.save();
    if (formKey.currentState!.validate()) {
      var userId = idController.text.trim();
      var fsUserAccess = getEditedUser();

      var bloc = this.bloc;
      if (await waitingAction(() async {
        await bloc.save(
          AdminProjectUserEditData(userId: userId)..user = fsUserAccess,
        );
      })) {
        if (context.mounted) {
          Navigator.pop(context, AppUserEditResult(modified: true));
        }
      }
    }
  }

  Future<bool> waitingAction(Future Function() param0) async {
    try {
      await param0();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error $e')));
      }
      return false;
    }
    return true;
  }
}

Future<AppUserEditResult?> goToAppUserEditScreen(
  BuildContext context, {
  required FsAppUserEditScreenParam param,
}) async {
  return await _goToAppUserEditScreen(context, param: param);
}

Future<AppUserEditResult?> _goToAppUserEditScreen(
  BuildContext context, {
  required FsAppUserEditScreenParam param,
}) async {
  var result = await Navigator.of(context).push(
    MaterialPageRoute<Object>(
      builder: (_) {
        return BlocProvider<FsAppUserEditScreenBloc>(
          blocBuilder: () => FsAppUserEditScreenBloc(param: param),
          child: const AppUserEditScreen(),
        );
      },
    ),
  );
  if (result is AppUserEditResult) {
    return result;
  }
  return null;
}
