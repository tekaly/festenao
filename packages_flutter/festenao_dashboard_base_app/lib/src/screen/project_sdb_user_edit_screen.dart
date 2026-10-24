import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen_bloc.dart';
import 'package:festenao_dashboard_base_app/src/provider/email_invite_providers.dart';
import 'package:festenao_theme/design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_api.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Dashboard counterpart of the admin user edit screen: the same form on
/// the festenao kit ([AdminUserEditScreenMixin], account, one role, advanced
/// fields).
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
    extends AutoDisposeBaseState<ProjectSdbUserEditScreen>
    with AdminUserEditScreenMixin {
  final _formKey = GlobalKey<FormState>();
  bool _initialized = false;

  @override
  FestenaoUserInfoReader? get userInfoReader =>
      BlocProvider.of<AdminProjectUserEditScreenBloc>(context).userInfoReader;

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<AdminProjectUserEditScreenBloc>(context);
    var userId = bloc.param.userId;
    var isCreate = userId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCreate ? intl.accessAddUser : intl.userTitle),
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
            _initialized = true;
            initControllers(userId: userId, user: snapshot.data!.user);
            // An existing access missing its name or email: from the account.
            if (!isCreate &&
                (nameController.text.isEmpty || emailController.text.isEmpty)) {
              fillFromAccount(context, onlyEmpty: true, quiet: true);
            }
          }
          return Form(
            key: _formKey,
            child: ListView(
              children: [const SizedBox(height: 16), buildDataWidget(context)],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: MaterialLocalizations.of(context).saveButtonLabel,
        onPressed: () => _save(context, bloc),
        child: const Icon(Icons.save),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    AdminProjectUserEditScreenBloc bloc,
  ) async {
    if (!_initialized || !_formKey.currentState!.validate()) {
      return;
    }
    var userId = idController.text.trim();
    try {
      await bloc.save(
        AdminProjectUserEditData(userId: userId)..user = getEditedUser(),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error $e')));
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
    var intl = festenaoAdminAppIntl(context);
    var t = context.festenao;
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(intl.accessRemoveUser),
        content: Text(intl.accessRemoveUserConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(intl.cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: t.bad),
            child: Text(intl.deleteButtonLabel),
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
