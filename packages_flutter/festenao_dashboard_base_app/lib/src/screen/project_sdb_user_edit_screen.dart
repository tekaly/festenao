import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen_bloc.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
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

  bool _read = false;
  bool _write = false;
  bool _admin = false;

  bool _initialized = false;

  @override
  void dispose() {
    _idController.dispose();
    _roleController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _fillFrom(String? userId, TkCmsEditedFsUserAccess? user) {
    _idController.text = userId ?? '';
    _roleController.text = user?.role.v ?? '';
    _nameController.text = user?.name.v ?? '';
    _read = user?.read.v ?? false;
    _write = user?.write.v ?? false;
    _admin = user?.admin.v ?? false;
    _initialized = true;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur $e')));
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
Future<AdminProjectUserEditScreenResult?> goToProjectSdbUserEditScreen(
  BuildContext context, {
  required AdminProjectUserEditScreenParam param,
}) async {
  return await Navigator.of(context).push(
    MaterialPageRoute<AdminProjectUserEditScreenResult>(
      builder: (_) {
        return BlocProvider<AdminProjectUserEditScreenBloc>(
          blocBuilder: () => AdminProjectUserEditScreenBloc(param: param),
          child: const ProjectSdbUserEditScreen(),
        );
      },
    ),
  );
}
