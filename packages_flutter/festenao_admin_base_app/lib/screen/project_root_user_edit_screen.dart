import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/utils/text_validator.dart';
import 'package:festenao_admin_base_app/view/text_field.dart';
import 'package:festenao_base_app/import/ui.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:tekartik_app_flutter_widget/app_widget.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';

class AdminProjectUserEditScreen extends StatefulWidget {
  const AdminProjectUserEditScreen({super.key});

  @override
  State<AdminProjectUserEditScreen> createState() =>
      _AdminProjectUserEditScreenState();
}

final allRoles = [
  tkCmsUserAccessRoleUser,
  tkCmsUserAccessRoleAdmin,
  tkCmsUserAccessRoleSuperAdmin,
  null,
];

mixin AdminUserEditScreenMixin implements AutoDispose {
  late final TextEditingController idController;
  late final TextEditingController roleController;
  late final TextEditingController nameController;
  late final BehaviorSubject<bool> read;
  late final BehaviorSubject<bool> write;
  late final BehaviorSubject<bool> admin;
  late final BehaviorSubject<String?> selectedRole;
  String? _initialUserId;

  void initControllers({String? userId, TkCmsEditedFsUserAccess? user}) {
    read = audiAddBehaviorSubject(
      BehaviorSubject.seeded(user?.read.v ?? false),
    );
    write = audiAddBehaviorSubject(
      BehaviorSubject.seeded(user?.write.v ?? false),
    );
    admin = audiAddBehaviorSubject(
      BehaviorSubject.seeded(user?.admin.v ?? false),
    );
    _initialUserId = userId;
    idController = audiAddTextEditingController(
      TextEditingController(text: userId),
    );
    roleController = audiAddTextEditingController(
      TextEditingController(text: user?.role.v),
    );
    nameController = audiAddTextEditingController(
      TextEditingController(text: user?.name.v),
    );
    var role = user?.role.v;
    role = allRoles.contains(role) ? role : null;
    selectedRole = audiAddBehaviorSubject(BehaviorSubject.seeded(role));
  }

  Column buildDataWidget(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    return Column(
      children: [
        BodyContainer(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppTextFieldTile(
                      readOnly: _initialUserId != null,
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
          child: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    decoration: const InputDecoration(
                      labelText: 'Select an option',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: selectedRole.valueOrNull,
                    items: [...allRoles]
                        .map(
                          (option) => DropdownMenuItem(
                            value: option,
                            child: Text(option ?? '<None>'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      selectedRole.add(value);
                      roleController.text = value ?? '';
                    },
                    validator: (value) {
                      return null;
                    },
                  ),
                ),
                Expanded(
                  child: AppTextFieldTile(
                    //readOnly: !globalTkCmsFbIdentityBloc.hasAdminCredentials,
                    labelText: intl.projectAccessRole,
                    controller: roleController,
                    emptyAllowed: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        BodyContainer(
          child: Row(
            children: [
              Expanded(
                child: AppTextFieldTile(
                  //readOnly: !globalTkCmsFbIdentityBloc.hasAdminCredentials,
                  labelText: intl.nameLabel,
                  controller: nameController,
                  emptyAllowed: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        BodyContainer(
          child: BehaviorSubjectBuilder(
            subject: admin,
            builder: (_, snapshot) {
              var isAdmin = snapshot.data;
              return SwitchListTile(
                value: snapshot.data ?? false,
                onChanged: isAdmin == null
                    ? null
                    : (bool value) {
                        admin.value = value;
                        if (value) {
                          write.value = true;
                          read.value = true;
                        }
                      },
                title: Text(intl.projectAccessAdmin),
              );
            },
          ),
        ),
        BodyContainer(
          child: BehaviorSubjectBuilder(
            subject: write,
            builder: (_, snapshot) {
              var write = snapshot.data;
              return SwitchListTile(
                value: snapshot.data ?? false,
                onChanged: write == null
                    ? null
                    : (bool value) {
                        this.write.value = value;
                        if (!value) {
                          admin.value = false;
                        } else {
                          read.value = true;
                        }
                      },
                title: Text(intl.projectAccessWrite),
              );
            },
          ),
        ),
        BodyContainer(
          child: BehaviorSubjectBuilder(
            subject: read,
            builder: (_, snapshot) {
              var read = snapshot.data;
              return SwitchListTile(
                value: snapshot.data ?? false,
                onChanged: read == null
                    ? null
                    : (bool value) {
                        this.read.value = value;
                        if (!value) {
                          write.value = false;
                          admin.value = false;
                        }
                      },
                title: Text(intl.projectAccessRead),
              );
            },
          ),
        ),

        StreamBuilder(
          stream: globalTkCmsFbIdentityBloc.state,
          builder: (_, snapshot) {
            var user = snapshot.data;
            if (user == null) {
              return Container();
            }

            return BodyContainer(
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      admin.value = true;
                      write.value = true;
                      read.value = true;
                      roleController.text = tkCmsUserAccessRoleAdmin;
                      nameController.text = 'Me as admin';
                      idController.text = user.identity?.userOrAccountId ?? '';
                    },
                    child: const Text('Fill with me as admin'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  TkCmsEditedFsUserAccess getEditedUser() {
    return TkCmsEditedFsUserAccess()
      ..write.v = write.value
      ..admin.v = admin.value
      ..read.v = read.value
      ..name.v = nameController.text.trimmedNonEmpty()
      ..role.v = roleController.text.trimmedNonEmpty();
  }
}

class _AdminProjectUserEditScreenState
    extends AutoDisposeBaseState<AdminProjectUserEditScreen>
    with AdminUserEditScreenMixin {
  var _initialized = false;

  var formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<AdminProjectUserEditScreenBloc>(context);
    final intl = festenaoAdminAppIntl(context);
    var userId = bloc.param.userId;
    return AdminScreenLayout(
      appBar: AppBar(
        title: const Text('User'),
        actions: [
          if (userId != null)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: intl.deleteButtonLabel,
              onPressed: () async {
                if (await muiConfirm(context)) {
                  await bloc.delete(userId);
                  if (context.mounted) {
                    Navigator.pop(
                      context,
                      AdminProjectUserEditScreenResult(deleted: true),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: ValueStreamBuilder<AdminProjectUserEditScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return const CenteredProgress();
          }

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
                    buildDataWidget(context),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton:
          ValueStreamBuilder<AdminProjectUserEditScreenBlocState>(
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

      var bloc = BlocProvider.of<AdminProjectUserEditScreenBloc>(context);
      if (await waitingAction(() async {
        await bloc.save(
          AdminProjectUserEditData(userId: userId)..user = fsUserAccess,
        );
      })) {
        if (context.mounted) {
          Navigator.pop(
            context,
            AdminProjectUserEditScreenResult(modified: true),
          );
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

Future<AdminProjectUserEditScreenResult?> goToAdminProjectUserEditScreen(
  BuildContext context, {
  required AdminProjectUserEditScreenParam param,
}) async {
  return await _goToAdminUserEditScreen(context, param: param);
}

Future<AdminProjectUserEditScreenResult?> _goToAdminUserEditScreen(
  BuildContext context, {
  required AdminProjectUserEditScreenParam param,
}) async {
  var result = await Navigator.of(context).push(
    MaterialPageRoute<Object>(
      builder: (_) {
        return BlocProvider<AdminProjectUserEditScreenBloc>(
          blocBuilder: () => AdminProjectUserEditScreenBloc(param: param),
          child: const AdminProjectUserEditScreen(),
        );
      },
    ),
  );
  return result?.anyAs<AdminProjectUserEditScreenResult>();
}
