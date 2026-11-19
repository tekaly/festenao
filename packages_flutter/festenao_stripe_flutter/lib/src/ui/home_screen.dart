import 'package:material_ui/material_ui.dart';

import '../client.dart';
import '../client_store.dart';
import '../service.dart';
import 'account_screen.dart';
import 'clients_screen.dart';
import 'dashboard_screen.dart';
import 'payment_links_screen.dart';
import 'payments_screen.dart';
import 'payouts_screen.dart';
import 'products_screen.dart';
import 'sales_screen.dart';
import 'widgets.dart';

/// Creates the service of a client (a mock client in tests).
typedef StripeManagerServiceFactory = StripeManagerService Function(
  StripeManagerClient client,
);

StripeManagerService _defaultServiceFactory(StripeManagerClient client) =>
    StripeManagerService(client: client);

/// The home of the manager: the current client and the sections.
class StripeManagerScreen extends StatefulWidget {
  /// The clients.
  final StripeManagerClientStore store;

  /// The title.
  final String title;

  /// Creates the service of a client.
  final StripeManagerServiceFactory serviceFactory;

  /// The manager of the clients of [store].
  const StripeManagerScreen({
    super.key,
    required this.store,
    this.title = 'Stripe',
    this.serviceFactory = _defaultServiceFactory,
  });

  @override
  State<StripeManagerScreen> createState() => _StripeManagerScreenState();
}

class _StripeManagerScreenState extends State<StripeManagerScreen> {
  StripeManagerService? _service;
  late final Future<void> _ready = widget.store.ready();

  StripeManagerService _serviceOf(StripeManagerClient client) {
    var service = _service;
    if (service != null && service.client.id == client.id) {
      return service;
    }
    service?.close();
    return _service = widget.serviceFactory(client);
  }

  @override
  void dispose() {
    _service?.close();
    super.dispose();
  }

  Future<void> _goToClients() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => StripeManagerClientsScreen(
        store: widget.store,
        serviceFactory: widget.serviceFactory,
      ),
    ),
  );

  void _push(Widget Function(StripeManagerService service) builder) {
    var client = widget.store.current.value;
    if (client == null) {
      return;
    }
    var service = _serviceOf(client);
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => builder(service)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: Center(child: Text('${snapshot.error}')),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return ValueListenableBuilder<StripeManagerClient?>(
          valueListenable: widget.store.current,
          builder: (context, client, _) {
            if (client == null) {
              return Scaffold(
                appBar: AppBar(title: Text(widget.title)),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No Stripe client selected'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _goToClients,
                          child: const Text('Choose or add a client'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return _buildSections(context, client);
          },
        );
      },
    );
  }

  Widget _buildSections(BuildContext context, StripeManagerClient client) {
    Widget section(
      IconData icon,
      String title,
      String subtitle,
      Widget Function(StripeManagerService service) builder,
    ) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _push(builder),
    );
    return StripeManagerScaffold(
      client: client,
      title: widget.title,
      body: ListView(
        children: [
          ListTile(
            key: const ValueKey('stripe_manager_current_client'),
            leading: const Icon(Icons.vpn_key),
            title: Text(client.name),
            subtitle: Text(client.keyHint),
            trailing: TextButton(
              onPressed: _goToClients,
              child: const Text('Change'),
            ),
            onTap: _goToClients,
          ),
          const Divider(),
          section(
            Icons.dashboard,
            'Dashboard',
            'Balance, payments, fees, payouts',
            (service) => StripeManagerDashboardScreen(service: service),
          ),
          section(
            Icons.inventory_2,
            'Products',
            'Products and prices',
            (service) => StripeManagerProductsScreen(service: service),
          ),
          section(
            Icons.shopping_cart,
            'Sales',
            'Paid checkouts by product, csv',
            (service) => StripeManagerSalesScreen(service: service),
          ),
          section(
            Icons.payments,
            'Payments',
            'Charges, refunds',
            (service) => StripeManagerPaymentsScreen(service: service),
          ),
          section(
            Icons.link,
            'Payment links',
            'Links, their items and payments',
            (service) => StripeManagerPaymentLinksScreen(service: service),
          ),
          section(
            Icons.account_balance,
            'Payouts',
            'Bank transfers and what they hold',
            (service) => StripeManagerPayoutsScreen(service: service),
          ),
          section(
            Icons.business,
            'Account',
            'Account and payout schedule',
            (service) => StripeManagerAccountScreen(service: service),
          ),
        ],
      ),
    );
  }
}

/// Opens the manager of [store].
Future<void> goToStripeManager(
  BuildContext context, {
  required StripeManagerClientStore store,
  String title = 'Stripe',
  StripeManagerServiceFactory serviceFactory = _defaultServiceFactory,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => StripeManagerScreen(
      store: store,
      title: title,
      serviceFactory: serviceFactory,
    ),
  ),
);
