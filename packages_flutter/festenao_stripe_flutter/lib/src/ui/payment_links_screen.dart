import 'package:material_ui/material_ui.dart';
import 'package:tekartik_stripe_api/stripe_api.dart';

import '../format.dart';
import '../service.dart';
import 'sales_screen.dart';
import 'widgets.dart';

/// The Payment Links, active or not.
class StripeManagerPaymentLinksScreen extends StatefulWidget {
  /// The service.
  final StripeManagerService service;

  /// The links of [service].
  const StripeManagerPaymentLinksScreen({super.key, required this.service});

  @override
  State<StripeManagerPaymentLinksScreen> createState() =>
      _StripeManagerPaymentLinksScreenState();
}

class _StripeManagerPaymentLinksScreenState
    extends State<StripeManagerPaymentLinksScreen> {
  var _active = true;
  var _reloadCount = 0;

  StripeManagerService get service => widget.service;

  @override
  Widget build(BuildContext context) {
    return StripeManagerScaffold(
      client: service.client,
      title: 'Payment links',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Active')),
                ButtonSegment(value: false, label: Text('Inactive')),
              ],
              selected: {_active},
              onSelectionChanged: (selection) =>
                  setState(() => _active = selection.first),
            ),
          ),
          Expanded(
            child:
                StripeManagerFutureView<
                  StripeManagerList<StripeApiPaymentLink>
                >(
                  reloadKey: (_active, _reloadCount),
                  load: () => service.listPaymentLinks(active: _active),
                  builder: (context, list, reload) {
                    if (list.items.isEmpty) {
                      return const Center(child: Text('No payment link'));
                    }
                    return ListView(
                      children: [
                        for (var link in list.items)
                          ListTile(
                            title: Text(link.url.v ?? link.id.v ?? '?'),
                            subtitle: Text(
                              [
                                link.id.v,
                                if (link.metadata.v case var metadata?
                                    when metadata.isNotEmpty)
                                  metadata.entries
                                      .map((e) => '${e.key}: ${e.value}')
                                      .join(', '),
                              ].join('\n'),
                            ),
                            onTap: () async {
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      StripeManagerPaymentLinkScreen(
                                        service: service,
                                        paymentLink: link,
                                      ),
                                ),
                              );
                              setState(() => _reloadCount++);
                            },
                          ),
                        if (list.truncated)
                          const ListTile(title: Text('More links exist')),
                      ],
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class _LinkData {
  final List<StripeApiLineItem> items;
  final List<StripeApiCheckoutSession> sessions;

  _LinkData(this.items, this.sessions);
}

/// A Payment Link: its items, its completed payments, deactivate it.
class StripeManagerPaymentLinkScreen extends StatelessWidget {
  /// The service.
  final StripeManagerService service;

  /// The link.
  final StripeApiPaymentLink paymentLink;

  /// The [paymentLink] of [service].
  const StripeManagerPaymentLinkScreen({
    super.key,
    required this.service,
    required this.paymentLink,
  });

  Future<_LinkData> _load() async {
    var id = paymentLink.id.v!;
    var results = await Future.wait<Object>([
      service.listPaymentLinkLineItems(id),
      service.listPaymentLinkSessions(id),
    ]);
    return _LinkData(
      results[0] as List<StripeApiLineItem>,
      results[1] as List<StripeApiCheckoutSession>,
    );
  }

  @override
  Widget build(BuildContext context) {
    var active = paymentLink.active.v ?? true;
    var limit = paymentLink.restrictions.v?.completedSessions.v?.limit.v;
    return StripeManagerScaffold(
      client: service.client,
      title: 'Payment link',
      body: StripeManagerFutureView<_LinkData>(
        load: _load,
        builder: (context, data, reload) {
          return ListView(
            children: [
              StripeManagerInfoTile(
                label: 'Url',
                value: paymentLink.url.v,
                copy: true,
              ),
              StripeManagerInfoTile(
                label: 'Id',
                value: paymentLink.id.v,
                copy: true,
              ),
              StripeManagerInfoTile(
                label: 'Status',
                value: [
                  if (active) 'active' else 'inactive',
                  if (limit != null) 'at most $limit payment(s)',
                ].join(', '),
              ),
              if (paymentLink.metadata.v case var metadata?
                  when metadata.isNotEmpty)
                StripeManagerInfoTile(
                  label: 'Metadata',
                  value: metadata.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('\n'),
                ),
              const StripeManagerSectionTitle('Items'),
              for (var item in data.items)
                ListTile(
                  dense: true,
                  title: Text(
                    '${item.quantity.v ?? 1} × ${item.description.v ?? '?'}',
                  ),
                  trailing: Text(
                    stripeManagerFormatAmount(
                      item.amountTotal.v,
                      item.currency.v,
                    ),
                  ),
                ),
              StripeManagerSectionTitle(
                'Completed payments (${data.sessions.length})',
              ),
              for (var session in data.sessions)
                ListTile(
                  dense: true,
                  title: Text(
                    '${stripeManagerFormatDateTime(session.created.v)}  '
                    '${session.customerDetails.v?.email.v ?? ''}',
                  ),
                  subtitle: Text(session.paymentStatus.v ?? ''),
                  trailing: Text(
                    stripeManagerFormatAmount(
                      session.amountTotal.v,
                      session.currency.v,
                    ),
                  ),
                  onTap: () =>
                      showStripeManagerSession(context, session, const {}),
                ),
              if (active)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.link_off),
                    label: const Text('Deactivate'),
                    onPressed: () async {
                      if (!await stripeManagerConfirm(
                        context,
                        client: service.client,
                        title: 'Deactivate link',
                        message:
                            'Deactivate this link? Nobody can pay with it '
                            'anymore.',
                        action: 'Deactivate',
                      )) {
                        return;
                      }
                      if (!context.mounted) {
                        return;
                      }
                      var navigator = Navigator.of(context);
                      if (await stripeManagerRun(context, () async {
                        await service.setPaymentLinkActive(
                          paymentLink.id.v!,
                          false,
                        );
                      }, success: 'Link deactivated')) {
                        navigator.pop();
                      }
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
