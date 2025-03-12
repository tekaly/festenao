import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/screen/app_user_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/utils/text_validator.dart';
import 'package:festenao_admin_base_app/view/text_field.dart';

import 'package:tekartik_app_flutter_widget/app_widget.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';

class AppUserEditScreen extends StatefulWidget {
  const AppUserEditScreen({super.key});

  @override
  State<AppUserEditScreen> createState() => _AppUserEditScreenState();
}

class _AppUserEditScreenState extends AutoDisposeBaseState<AppUserEditScreen> {
  late final TextEditingController idController;

  var _initialized = false;
  late final BehaviorSubject<bool> _read;
  late final BehaviorSubject<bool> _write;
  late final BehaviorSubject<bool> _admin;
  var formKey = GlobalKey<FormState>();

  AppUserEditScreenBloc get bloc =>
      BlocProvider.of<AppUserEditScreenBloc>(context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    return AdminScreenLayout(
      appBar: AppBar(title: const Text('User')),
      body: ValueStreamBuilder<AppUserEditScreenBlocState>(
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
          }

          return Stack(
            children: [
              Form(
                key: formKey,
                child: ListView(
                  children: [
                    const SizedBox(height: 16),
                    BodyContainer(
                      child: Row(
                        children: [
                          Expanded(
                            child: AppTextFieldTile(
                              readOnly: bloc.param.userId != null,
                              labelText: 'User ID',
                              controller: idController,
                              validator: fieldNonEmptyValidator,
                            ),
                          ),
                          /*
                            AppTextButton(
                                text: 'Info',
                                onPressed: () async {

                                  await waitingAction(() async {
                                    var info = await fbGaelFunctionsClient
                                        .adminGetUserInfo(
                                            ApiGaelAdminUserInfoRequest()
                                              ..userId.v = idController!.text);
                                    nameController!.text = info.name.v ?? '';
                                    emailController!.text = info.email.v ?? '';
                                  });


                                })*/
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    /*
                    BodyContainer(
                      child: AppTextFieldTile(
                        labelText: 'User name',
                        controller: nameController ??= TextEditingController(
                          text: user?.name.v,
                        ),
                        validator: fieldNonEmptyValidator,
                      ),
                    ),
                    const SizedBox(height: 16),
                    BodyContainer(
                      child: AppTextFieldTile(
                        labelText: textUserEmailLabel,
                        controller: emailController ??= TextEditingController(
                          text: user?.email.v,
                        ),
                        validator: fieldNonEmptyValidator,
                      ),
                    ),*/
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
                            title: const Text('Admin'),
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
                            title: const Text('Write'),
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
                            title: const Text('Read'),
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
      var userId = idController.text;
      var fsUserAccess =
          TkCmsFsUserAccess()
            ..write.v = _write.value
            ..admin.v = _admin.value
            ..read.v = _read.value;

      var bloc = this.bloc;
      if (await waitingAction(() async {
        await bloc.save(AdminUserEditData(userId: userId)..user = fsUserAccess);
      })) {
        if (context.mounted) {
          Navigator.pop(context);
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

Future<void> goToAppUserEditScreen(
  BuildContext context, {
  required AppUserEditScreenParam param,
}) async {
  await _goToAppUserEditScreen(context, param: param);
}

Future<void> _goToAppUserEditScreen(
  BuildContext context, {
  required AppUserEditScreenParam param,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) {
        return BlocProvider<AppUserEditScreenBloc>(
          blocBuilder: () => AppUserEditScreenBloc(param: param),
          child: const AppUserEditScreen(),
        );
      },
    ),
  );
}
