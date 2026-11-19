import 'package:material_ui/material_ui.dart';
import 'package:tekartik_stripe_api/stripe_api.dart';

import '../client.dart';
import '../client_store.dart';
import 'home_screen.dart';
import 'widgets.dart';

/// The clients: choose the current one, add one, delete one.
class StripeManagerClientsScreen extends StatelessWidget {
  /// The clients.
  final StripeManagerClientStore store;

  /// Creates the service checking a new key.
  final StripeManagerServiceFactory serviceFactory;

  /// The clients of [store].
  const StripeManagerClientsScreen({
    super.key,
    required this.store,
    required this.serviceFactory,
  });

  Future<void> _add(BuildContext context) async {
    var client = await showDialog<StripeManagerClient>(
      context: context,
      builder: (_) =>
          _AddClientDialog(store: store, serviceFactory: serviceFactory),
    );
    if (client != null && context.mounted) {
      await store.selectClient(client.id);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _delete(BuildContext context, StripeManagerClient client) async {
    var ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete client'),
        content: Text(
          'Forget ${client.name} (${client.keyHint}) on this device? The '
          'Stripe account is not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await store.deleteClient(client.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stripe clients')),
      body: ValueListenableBuilder<StripeManagerClient?>(
        valueListenable: store.current,
        builder: (context, current, _) {
          return ValueListenableBuilder<List<StripeManagerClient>>(
            valueListenable: store.clients,
            builder: (context, clients, _) {
              if (clients.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No client yet: add one with a secret key or, better, '
                      'a restricted key (rk_...) of the Stripe account.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView(
                children: [
                  for (var client in clients)
                    ListTile(
                      key: ValueKey('stripe_manager_client_${client.id}'),
                      leading: Icon(
                        client.id == current?.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Row(
                        children: [
                          Flexible(child: Text(client.name)),
                          const SizedBox(width: 8),
                          StripeManagerModeChip(client: client),
                        ],
                      ),
                      subtitle: Text(
                        client.builtIn
                            ? '${client.keyHint} (built-in)'
                            : client.keyHint,
                      ),
                      trailing: client.builtIn
                          ? null
                          : IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete),
                              onPressed: () => _delete(context, client),
                            ),
                      onTap: () async {
                        await store.selectClient(client.id);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add a client',
        onPressed: () => _add(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddClientDialog extends StatefulWidget {
  final StripeManagerClientStore store;
  final StripeManagerServiceFactory serviceFactory;

  const _AddClientDialog({required this.store, required this.serviceFactory});

  @override
  State<_AddClientDialog> createState() => _AddClientDialogState();
}

class _AddClientDialogState extends State<_AddClientDialog> {
  final _name = TextEditingController();
  final _key = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    var secretKey = _key.text.trim();
    var keyError = stripeManagerKeyError(secretKey);
    if (keyError != null) {
      setState(() => _error = keyError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    // Check the key before keeping it.
    var service = widget.serviceFactory(
      StripeManagerClient(id: 'check', name: 'check', secretKey: secretKey),
    );
    try {
      await service.getBalance();
      var client = await widget.store.addClient(
        name: _name.text.trim(),
        secretKey: secretKey,
      );
      if (mounted) {
        Navigator.of(context).pop(client);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = stripeApiErrorMessage(e);
        });
      }
    } finally {
      await service.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a Stripe client'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('stripe_manager_client_name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              key: const ValueKey('stripe_manager_client_key'),
              controller: _key,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Secret or restricted key (sk_... / rk_...)',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The key is checked, then kept on this device only. A '
              'restricted key with read access is safer.',
              style: TextStyle(fontSize: 12),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: stripeManagerLiveColor),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('stripe_manager_client_add'),
          onPressed: _busy ? null : _check,
          child: Text(_busy ? 'Checking...' : 'Add'),
        ),
      ],
    );
  }
}
