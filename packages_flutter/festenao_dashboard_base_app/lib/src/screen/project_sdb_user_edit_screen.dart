import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen.dart'
    show
        festenaoFillUserErrorNotFound,
        festenaoFillUserErrorPermissionDenied,
        festenaoFillUserFromAccount;
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen_bloc.dart';
import 'package:festenao_dashboard_base_app/src/provider/email_invite_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_api.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Dashboard counterpart of the admin user edit screen.
///
/// Creates, edits or deletes a single project user access entry. Reuses
/// [AdminProjectUserEditScreenBloc] for all the firestore plumbing.
class ProjectSdbUserEditScreen extends StatefulWidget {
  const ProjectSdbUserEditScreen({super.key});

  @override
  State<ProjectSdbUserEditScreen> createState() =>
      _ProjectSdbUserEditScreenState();
}

class _ProjectSdbUserEditScreenState
    extends AutoDisposeBaseState<ProjectSdbUserEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _roleController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _read = false;
  bool _write = false;
  bool _admin = false;

  bool _initialized = false;

  @override
  void dispose() {
    _idController.dispose();
    _roleController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _fillFrom(String? userId, TkCmsEditedFsUserAccess? user) {
    _idController.text = userId ?? '';
    _roleController.text = user?.role.v ?? '';
    _nameController.text = user?.name.v ?? '';
    _emailController.text = user?.email.v ?? '';
    _read = user?.read.v ?? false;
    _write = user?.write.v ?? false;
    _admin = user?.admin.v ?? false;
    _initialized = true;
  }

  /// Fill the name and the email from the account of the user id typed
  /// (through the secured api, see the get-user-info command).
  ///
  /// [onlyEmpty] keeps what is already typed and [quiet] reports nothing:
  /// the automatic fill of an existing access missing them.
  Future<void> _fillFromAccount(
    BuildContext context,
    AdminProjectUserEditScreenBloc bloc, {
    bool onlyEmpty = false,
    bool quiet = false,
  }) async {
    var reader = bloc.userInfoReader;
    if (reader == null) {
      return;
    }
    var userId = _idController.text.trim();
    var error = await festenaoFillUserFromAccount(
      reader: reader,
      userId: userId,
      nameController: _nameController,
      emailController: _emailController,
      onlyEmpty: onlyEmpty,
    );
    if (error != null && !quiet && context.mounted) {
      var message = switch (error.code) {
        festenaoFillUserErrorPermissionDenied =>
          'Vous ne pouvez pas lire ce compte',
        festenaoFillUserErrorNotFound => 'Compte inconnu : $userId',
        _ => 'Lecture du compte impossible : ${error.cause}',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<AdminProjectUserEditScreenBloc>(context);
    var userId = bloc.param.userId;
    var isCreate = userId == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilisateur'),
        actions: [
          if (!isCreate)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: intl.deleteButtonLabel,
              onPressed: () => _confirmDelete(context, bloc, userId),
            ),
        ],
      ),
      body: ValueStreamBuilder<AdminProjectUserEditScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!_initialized) {
            _fillFrom(userId, snapshot.data!.user);
            // An existing access missing its name or email: from the account.
            if (!isCreate &&
                (_nameController.text.isEmpty ||
                    _emailController.text.isEmpty)) {
              _fillFromAccount(context, bloc, onlyEmpty: true, quiet: true);
            }
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _idController,
                  readOnly: !isCreate,
                  enabled: isCreate,
                  decoration: const InputDecoration(labelText: 'User ID'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'L\'identifiant est requis';
                    }
                    return null;
                  },
                ),
                if (bloc.userInfoSupported)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: () => _fillFromAccount(context, bloc),
                      icon: const Icon(Icons.person_search),
                      label: const Text('Remplir depuis le compte'),
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _roleController,
                  decoration: InputDecoration(
                    labelText: intl.projectAccessRole,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: intl.nameLabel),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: intl.emailLabel),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(intl.projectAccessAdmin),
                  value: _admin,
                  onChanged: (value) {
                    setState(() {
                      _admin = value;
                      if (value) {
                        _write = true;
                        _read = true;
                      }
                    });
                  },
                ),
                SwitchListTile(
                  title: Text(intl.projectAccessWrite),
                  value: _write,
                  onChanged: (value) {
                    setState(() {
                      _write = value;
                      if (!value) {
                        _admin = false;
                      } else {
                        _read = true;
                      }
                    });
                  },
                ),
                SwitchListTile(
                  title: Text(intl.projectAccessRead),
                  value: _read,
                  onChanged: (value) {
                    setState(() {
                      _read = value;
                      if (!value) {
                        _write = false;
                        _admin = false;
                      }
                    });
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Enregistrer',
        onPressed: () => _save(context, bloc),
        child: const Icon(Icons.save),
      ),
    );
  }

  TkCmsEditedFsUserAccess _editedUser() {
    return TkCmsEditedFsUserAccess()
      ..write.v = _write
      ..admin.v = _admin
      ..read.v = _read
      ..name.v = _nameController.text.trimmedNonEmpty()
      ..email.v = _emailController.text.trimmedNonEmpty()
      ..role.v = _roleController.text.trimmedNonEmpty();
  }

  Future<void> _save(
    BuildContext context,
    AdminProjectUserEditScreenBloc bloc,
  ) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    var userId = _idController.text.trim();
    try {
      await bloc.save(
        AdminProjectUserEditData(userId: userId)..user = _editedUser(),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur $e')));
      }
      return;
    }
    if (context.mounted) {
      Navigator.pop(context, AdminProjectUserEditScreenResult(modified: true));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AdminProjectUserEditScreenBloc bloc,
    String userId,
  ) async {
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Voulez-vous vraiment retirer cet utilisateur ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await bloc.delete(userId);
      if (context.mounted) {
        Navigator.pop(context, AdminProjectUserEditScreenResult(deleted: true));
      }
    }
  }
}

/// Navigate to the user create/edit screen, returning the edit result.
///
/// The secured api (to fill a user from its account) is the one of the
/// dashboard providers ([emailInviteApiServiceProvider]) when the context
/// has a provider scope, the global one otherwise.
Future<AdminProjectUserEditScreenResult?> goToProjectSdbUserEditScreen(
  BuildContext context, {
  required AdminProjectUserEditScreenParam param,
  TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity>? entityAccess,
}) async {
  TkCmsApiServiceBaseV2? apiService;
  try {
    apiService = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(emailInviteApiServiceProvider);
  } catch (_) {
    // No provider scope: the bloc uses the global api service.
  }
  return await Navigator.of(context).push(
    MaterialPageRoute<AdminProjectUserEditScreenResult>(
      builder: (_) {
        return BlocProvider<AdminProjectUserEditScreenBloc>(
          blocBuilder: () => AdminProjectUserEditScreenBloc(
            param: param,
            entityAccess: entityAccess,
            apiService: apiService,
          ),
          child: const ProjectSdbUserEditScreen(),
        );
      },
    ),
  );
}
