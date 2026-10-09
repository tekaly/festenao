import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/access_view.dart';
import 'package:festenao_base_app/import/ui.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/kit.dart';
import 'package:tekartik_app_flutter_widget/app_widget.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_common/tkcms_api.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';

class AdminProjectUserEditScreen extends StatefulWidget {
  const AdminProjectUserEditScreen({super.key});

  @override
  State<AdminProjectUserEditScreen> createState() =>
      _AdminProjectUserEditScreenState();
}

/// [festenaoFillUserFromAccount] refused: not an admin allowed to read the
/// user.
const festenaoFillUserErrorPermissionDenied = 'permission-denied';

/// [festenaoFillUserFromAccount] refused: no such user.
const festenaoFillUserErrorNotFound = 'not-found';

/// Why [festenaoFillUserFromAccount] filled nothing.
class FestenaoFillUserError {
  /// The api error code ([festenaoFillUserErrorPermissionDenied],
  /// [festenaoFillUserErrorNotFound]...), null for another failure.
  final String? code;

  /// The failure.
  final Object cause;

  /// Why nothing was filled.
  const FestenaoFillUserError(this.code, this.cause);
}

/// Fill [nameController] and [emailController] from the account of [userId]
/// read by [reader] (the user edit screens of the admin app and of the
/// dashboard); [onlyEmpty] keeps what is already typed.
///
/// Returns null when read (an empty [userId] reads nothing), the error
/// otherwise, for the screen to report it in its own words.
Future<FestenaoFillUserError?> festenaoFillUserFromAccount({
  required FestenaoUserInfoReader reader,
  required String userId,
  required TextEditingController nameController,
  required TextEditingController emailController,
  bool onlyEmpty = false,
}) async {
  if (userId.isEmpty) {
    return null;
  }
  try {
    var info = await reader(userId);
    if (info.name != null &&
        (!onlyEmpty || nameController.text.trim().isEmpty)) {
      nameController.text = info.name!;
    }
    if (info.email != null &&
        (!onlyEmpty || emailController.text.trim().isEmpty)) {
      emailController.text = info.email!;
    }
    return null;
  } catch (e) {
    return FestenaoFillUserError(e is ApiException ? e.error?.code.v : null, e);
  }
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
  late final TextEditingController emailController;
  late final BehaviorSubject<bool> read;
  late final BehaviorSubject<bool> write;
  late final BehaviorSubject<bool> admin;
  late final BehaviorSubject<String?> selectedRole;
  String? _initialUserId;

  /// Reads the account information of a user (name, email), null when the
  /// screen cannot (no secured api): then no fill button.
  FestenaoUserInfoReader? get userInfoReader => null;

  /// Fill the name and the email from the account of the user id typed.
  ///
  /// [onlyEmpty] keeps what is already typed (the automatic fill of an
  /// existing access); [quiet] reports nothing (the same).
  Future<void> fillFromAccount(
    BuildContext context, {
    bool onlyEmpty = false,
    bool quiet = false,
  }) async {
    var reader = userInfoReader;
    if (reader == null) {
      return;
    }
    var userId = idController.text.trim();
    var error = await festenaoFillUserFromAccount(
      reader: reader,
      userId: userId,
      nameController: nameController,
      emailController: emailController,
      onlyEmpty: onlyEmpty,
    );
    if (error != null && !quiet && context.mounted) {
      var intl = festenaoAdminAppIntl(context);
      var message = switch (error.code) {
        festenaoFillUserErrorPermissionDenied => intl.accessFillNotAllowed,
        festenaoFillUserErrorNotFound => intl.accessFillUnknown(userId),
        _ => '${intl.accessFillError}: ${error.cause}',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

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
    emailController = audiAddTextEditingController(
      TextEditingController(text: user?.email.v),
    );
    var role = user?.role.v;
    role = allRoles.contains(role) ? role : null;
    selectedRole = audiAddBehaviorSubject(BehaviorSubject.seeded(role));
  }

  /// Set the read, write and admin flags of [role].
  void setRole(AdminAccessRole role) {
    var flags = role.flags;
    admin.value = flags.admin;
    write.value = flags.write;
    read.value = flags.read;
  }

  /// The account, the role and the advanced fields of an access, on the
  /// festenao kit: one role per person instead of three switches.
  Column buildDataWidget(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    var isCreate = _initialUserId == null;
    var roleStream = Rx.combineLatest3<bool, bool, bool, AdminAccessRole>(
      admin,
      write,
      read,
      (admin, write, read) =>
          AdminAccessRole.ofFlags(admin: admin, write: write, read: read),
    );
    var initialRole = AdminAccessRole.ofFlags(
      admin: admin.value,
      write: write.value,
      read: read.value,
    );
    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: FestenaoSpace.formWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FkSectionTitle(intl.accessAccountSection),
                  FkCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: idController,
                          readOnly: !isCreate,
                          decoration: InputDecoration(
                            labelText: intl.accessUserId,
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                          style: text.bodyLarge?.copyWith(
                            fontFamily: t.monoFamily,
                            fontSize: 14,
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? intl.accessUserIdRequired
                              : null,
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          children: [
                            if (isCreate) _MeAsAdminButton(form: this),
                            if (userInfoReader != null)
                              TextButton.icon(
                                onPressed: () => fillFromAccount(context),
                                icon: const Icon(Icons.person_search),
                                label: Text(intl.accessFillFromAccount),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: intl.nameLabel,
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: intl.emailLabel,
                            prefixIcon: const Icon(Icons.alternate_email),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FestenaoSpace.xl),
                  FkSectionTitle(intl.projectAccessRole),
                  FkCard(
                    child: StreamBuilder<AdminAccessRole>(
                      stream: roleStream,
                      initialData: initialRole,
                      builder: (context, snapshot) {
                        var role = snapshot.data ?? initialRole;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<AdminAccessRole>(
                              showSelectedIcon: false,
                              emptySelectionAllowed: true,
                              segments: [
                                for (var choice in AdminAccessRole.assignable)
                                  ButtonSegment(
                                    value: choice,
                                    label: Text(choice.label(intl)),
                                  ),
                              ],
                              selected: {
                                if (role != AdminAccessRole.none) role,
                              },
                              onSelectionChanged: (selection) => setRole(
                                selection.isEmpty
                                    ? AdminAccessRole.none
                                    : selection.first,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: role == AdminAccessRole.none
                                      ? t.warn
                                      : t.ink3,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    role.detail(intl),
                                    style: text.bodySmall?.copyWith(
                                      color: role == AdminAccessRole.none
                                          ? t.warn
                                          : t.ink2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: FestenaoSpace.xl),
                  FkSectionTitle(intl.accessAdvancedSection),
                  FkCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String?>(
                          decoration: InputDecoration(
                            labelText: intl.accessAppRole,
                            helperText: intl.accessAppRoleHelper,
                          ),
                          initialValue: selectedRole.valueOrNull,
                          items: [
                            for (var option in allRoles)
                              DropdownMenuItem(
                                value: option,
                                child: Text(option ?? '—'),
                              ),
                          ],
                          onChanged: (value) {
                            selectedRole.add(value);
                            roleController.text = value ?? '';
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: roleController,
                          decoration: InputDecoration(
                            labelText: intl.accessCustomRole,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
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
      ..email.v = emailController.text.trimmedNonEmpty()
      ..role.v = roleController.text.trimmedNonEmpty();
  }
}

/// Fills the form with the signed in user as admin (creation only).
class _MeAsAdminButton extends StatelessWidget {
  final AdminUserEditScreenMixin form;

  const _MeAsAdminButton({required this.form});

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    Stream<TkCmsFbIdentityBlocState>? stream;
    try {
      stream = globalTkCmsFbIdentityBloc.state;
    } catch (_) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<TkCmsFbIdentityBlocState>(
      stream: stream,
      builder: (context, snapshot) {
        var identity = snapshot.data?.identity;
        if (identity == null) {
          return const SizedBox.shrink();
        }
        return TextButton.icon(
          onPressed: () {
            form.setRole(AdminAccessRole.admin);
            form.roleController.text = tkCmsUserAccessRoleAdmin;
            form.selectedRole.add(tkCmsUserAccessRoleAdmin);
            form.emailController.text =
                identity.user?.email ?? form.emailController.text;
            form.idController.text = identity.userOrAccountId;
          },
          icon: const Icon(Icons.admin_panel_settings_outlined),
          label: Text(intl.accessFillMeAsAdmin),
        );
      },
    );
  }
}

class _AdminProjectUserEditScreenState
    extends AutoDisposeBaseState<AdminProjectUserEditScreen>
    with AdminUserEditScreenMixin {
  var _initialized = false;

  @override
  FestenaoUserInfoReader? get userInfoReader =>
      BlocProvider.of<AdminProjectUserEditScreenBloc>(context).userInfoReader;

  var formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<AdminProjectUserEditScreenBloc>(context);
    final intl = festenaoAdminAppIntl(context);
    var userId = bloc.param.userId;
    return AdminScreenLayout(
      appBar: AppBar(
        title: Text(userId == null ? intl.accessAddUser : intl.userTitle),
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
            // An existing access missing its name or email: from the account.
            if (userId != null &&
                (nameController.text.isEmpty || emailController.text.isEmpty)) {
              fillFromAccount(context, onlyEmpty: true, quiet: true);
            }
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error $e')));
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
