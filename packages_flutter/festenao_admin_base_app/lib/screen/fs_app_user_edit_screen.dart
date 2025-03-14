import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/fs_app_user_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/utils/text_validator.dart';
import 'package:festenao_admin_base_app/view/text_field.dart';

import 'package:tekartik_app_flutter_widget/app_widget.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';

import '../view/app_path.dart';

class AppUserEditResult {
  final bool modified;

  AppUserEditResult({required this.modified});
}

class AppUserEditScreen extends StatefulWidget {
  const AppUserEditScreen({super.key});

  @override
  State<AppUserEditScreen> createState() => _AppUserEditScreenState();
}

class _AppUserEditScreenState extends AutoDisposeBaseState<AppUserEditScreen> {
  late final TextEditingController idController;
  late final TextEditingController roleController;

  var _initialized = false;
  late final BehaviorSubject<bool> _read;
  late final BehaviorSubject<bool> _write;
  late final BehaviorSubject<bool> _admin;
  var formKey = GlobalKey<FormState>();

  FsAppUserEditScreenBloc get bloc =>
      BlocProvider.of<FsAppUserEditScreenBloc>(context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    var intl = festenaoAdminAppIntl(context);
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
            _read = audiAddBehaviorSubject(
              BehaviorSubject.seeded(user?.read.v ?? false),
            );
            _write = audiAddBehaviorSubject(
              BehaviorSubject.seeded(user?.write.v ?? false),
            );
            _admin = audiAddBehaviorSubject(
              BehaviorSubject.seeded(user?.admin.v ?? false),
            );
            idController = audiAddTextEditingController(
              TextEditingController(text: userId),
            );
            roleController = audiAddTextEditingController(
              TextEditingController(text: user?.role.v),
            );
          }

          return Stack(
            children: [
              Form(
                key: formKey,
                child: ListView(
                  children: [
                    const SizedBox(height: 16),

                    BodyContainer(
                      child: Column(
                        children: [
                          AppPathTile(appPath: bloc.appPath),
                          Row(
                            children: [
                              Expanded(
                                child: AppTextFieldTile(
                                  readOnly: bloc.param.userId != null,
                                  labelText: 'User ID',
                                  controller: idController,
                                  validator: fieldNonEmptyValidator,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    BodyContainer(
                      child: Row(
                        children: [
                          Expanded(
                            child: AppTextFieldTile(
                              //readOnly: !globalTkCmsFbIdentityBloc.hasAdminCredentials,
                              labelText: intl.projectAccessRole,
                              controller: roleController,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    BodyContainer(
                      child: BehaviorSubjectBuilder(
                        subject: _admin,
                        builder: (_, snapshot) {
                          var isAdmin = snapshot.data;
                          return SwitchListTile(
                            value: snapshot.data ?? false,
                            onChanged:
                                isAdmin == null
                                    ? null
                                    : (bool value) {
                                      _admin.value = value;
                                      if (value) {
                                        _write.value = true;
                                        _read.value = true;
                                      }
                                    },
                            title: Text(intl.projectAccessAdmin),
                          );
                        },
                      ),
                    ),
                    BodyContainer(
                      child: BehaviorSubjectBuilder(
                        subject: _write,
                        builder: (_, snapshot) {
                          var write = snapshot.data;
                          return SwitchListTile(
                            value: snapshot.data ?? false,
                            onChanged:
                                write == null
                                    ? null
                                    : (bool value) {
                                      _write.value = value;
                                      if (!value) {
                                        _admin.value = false;
                                      } else {
                                        _read.value = true;
                                      }
                                    },
                            title: Text(intl.projectAccessWrite),
                          );
                        },
                      ),
                    ),
                    BodyContainer(
                      child: BehaviorSubjectBuilder(
                        subject: _read,
                        builder: (_, snapshot) {
                          var read = snapshot.data;
                          return SwitchListTile(
                            value: snapshot.data ?? false,
                            onChanged:
                                read == null
                                    ? null
                                    : (bool value) {
                                      _read.value = value;
                                      if (!value) {
                                        _write.value = false;
                                        _admin.value = false;
                                      }
                                    },
                            title: Text(intl.projectAccessRead),
                          );
                        },
                      ),
                    ),
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
      var role = roleController.text.trimmedNonEmpty();
      var fsUserAccess =
          TkCmsFsUserAccess()
            ..write.v = _write.value
            ..admin.v = _admin.value
            ..read.v = _read.value
            ..role.v = role;

      var bloc = this.bloc;
      if (await waitingAction(() async {
        await bloc.save(AdminUserEditData(userId: userId)..user = fsUserAccess);
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
