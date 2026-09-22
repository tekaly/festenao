import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';

import '../object_editor/object_editor_dialogs.dart';
import 'admin_credentials.dart';

/// A screen managing the credentials the admin app holds: add one, edit it,
/// delete it, pick the one the firestore explorer uses.
///
/// The service account is pasted as its json, and what is wrong with it is
/// said when it is saved rather than on the first request, see
/// [adminServiceAccountError].
class AdminCredentialsScreen extends StatefulWidget {
  /// Where the credentials live.
  final AdminCredentialsDb credentialsDb;

  /// Credentials screen of [credentialsDb].
  const AdminCredentialsScreen({super.key, required this.credentialsDb});

  @override
  State<AdminCredentialsScreen> createState() => _AdminCredentialsScreenState();
}

class _AdminCredentialsScreenState extends State<AdminCredentialsScreen> {
  AdminCredentialsDb get credentialsDb => widget.credentialsDb;

  late Future<(List<AdminCredentials>, String?)> _loading = _load();

  Future<(List<AdminCredentials>, String?)> _load() async =>
      (await credentialsDb.list(), await credentialsDb.currentId());

  void _reload() => setState(() {
    _loading = _load();
  });

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _edit({AdminCredentials? credentials, String? id}) async {
    var saved = await goToAdminCredentialsEditScreen(
      context,
      credentialsDb: credentialsDb,
      credentials: credentials,
      id: id,
    );
    if (saved) {
      _reload();
    }
  }

  Future<void> _delete(String id, String name) async {
    var confirmed = await objectEditorPromptConfirm(
      context,
      title: 'Delete $name',
      message: 'The service account is removed from this device.',
      confirmText: 'Delete',
    );
    if (!confirmed) {
      return;
    }
    await credentialsDb.delete(id);
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Credentials'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Reload',
          onPressed: _reload,
        ),
      ],
    ),
    body: FutureBuilder<(List<AdminCredentials>, String?)>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        var data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        var (list, currentId) = data;
        if (list.isEmpty) {
          return const Center(
            child: Text('No credentials yet, add a service account'),
          );
        }
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            var credentials = list[index];
            var id = credentials.ref.key;
            var isCurrent = id == currentId;
            return ListTile(
              leading: Icon(
                isCurrent
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(credentials.displayName),
              subtitle: Text(credentials.projectId.v ?? ''),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                onSelected: (action) => switch (action) {
                  'edit' => _edit(credentials: credentials, id: id),
                  'delete' => _delete(id, credentials.displayName),
                  _ => null,
                },
              ),
              onTap: () async {
                await credentialsDb.setCurrentId(isCurrent ? null : id);
                _snack(
                  isCurrent
                      ? 'No credentials selected'
                      : 'Using ${credentials.displayName}',
                );
                _reload();
              },
            );
          },
        );
      },
    ),
    floatingActionButton: FloatingActionButton(
      tooltip: 'Add a service account',
      onPressed: _edit,
      child: const Icon(Icons.add),
    ),
  );
}

/// A screen entering one set of credentials: a label and the service account
/// json.
class AdminCredentialsEditScreen extends StatefulWidget {
  /// Where the credentials live.
  final AdminCredentialsDb credentialsDb;

  /// What is being edited, a new set when null.
  final AdminCredentials? credentials;

  /// The id it is written under, a new one when null.
  final String? id;

  /// Edit screen of [credentials].
  const AdminCredentialsEditScreen({
    super.key,
    required this.credentialsDb,
    this.credentials,
    this.id,
  });

  @override
  State<AdminCredentialsEditScreen> createState() =>
      _AdminCredentialsEditScreenState();
}

class _AdminCredentialsEditScreenState
    extends State<AdminCredentialsEditScreen> {
  late final _labelController = TextEditingController(
    text: widget.credentials?.label.v ?? '',
  );
  late final _serviceAccountController = TextEditingController(
    text: widget.credentials?.serviceAccount.v ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _labelController.dispose();
    _serviceAccountController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _paste() async {
    try {
      var text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (text == null || text.isEmpty) {
        _snack('Nothing on the clipboard');
        return;
      }
      setState(() {
        _serviceAccountController.text = text;
        _error = null;
      });
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _save() async {
    var serviceAccount = _serviceAccountController.text;
    var error = adminServiceAccountError(serviceAccount);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    var id = widget.id;
    if (id == null) {
      await widget.credentialsDb.add(
        label: _labelController.text,
        serviceAccount: serviceAccount,
      );
    } else {
      await widget.credentialsDb.put(
        id,
        label: _labelController.text,
        serviceAccount: serviceAccount,
      );
    }
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    var projectId = adminServiceAccountProjectId(
      _serviceAccountController.text,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? 'New credentials' : 'Credentials'),
        actions: [
          IconButton(
            icon: const Icon(Icons.paste),
            tooltip: 'Paste the service account',
            onPressed: _paste,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Label',
              helperText: 'What the list shows, the project id when empty',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _serviceAccountController,
            maxLines: 12,
            minLines: 6,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              labelText: 'Service account json',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Project'),
            subtitle: Text(projectId ?? 'read from the service account'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Save',
        onPressed: _save,
        child: const Icon(Icons.save),
      ),
    );
  }
}

/// Pushes an [AdminCredentialsScreen].
Future<void> goToAdminCredentialsScreen(
  BuildContext context, {
  required AdminCredentialsDb credentialsDb,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => AdminCredentialsScreen(credentialsDb: credentialsDb),
  ),
);

/// Pushes an [AdminCredentialsEditScreen], answering true when it saved.
Future<bool> goToAdminCredentialsEditScreen(
  BuildContext context, {
  required AdminCredentialsDb credentialsDb,
  AdminCredentials? credentials,
  String? id,
}) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminCredentialsEditScreen(
          credentialsDb: credentialsDb,
          credentials: credentials,
          id: id,
        ),
      ),
    ) ??
    false;
